Upgrade
========

This is a guide to upgrade Burrito Aster to Burrito Begonia.

I assume Burrito Aster 1.4.2 is already installed and running.
This guide will show you how to upgrade it to Burrito Begonia 2.0.5.

This is a version table.

===============  ============ ==============
Components       Aster 1.4.2  Begonia 2.0.5
===============  ============ ==============
containerd          v1.7.7      v1.7.13
kubernetes          v1.28.3     v1.29.2
kubeadm             v1.28.3     v1.29.2
etcd                v3.5.9      v3.5.10
calico              v3.26.3     v3.26.4
coredns             v1.10.1     v1.11.1
helm                v3.13.1     v3.14.2
nerdctl             1.6.0       1.7.1
crictl              v1.28.0     v1.29.0
nodelocaldns        1.22.20     1.22.28
cert-manager        v1.11.1     v1.13.2
metallb             v0.13.9     v0.13.9
registry            2.8.2       2.8.3
===============  ============ ==============


Prepare Begonia iso
--------------------

We will use Burrito Begonia 2.0.5 iso to upgrade the existing Burrito
Aster cluster.

Mount burrito-2.0.5_8.9.iso in /mnt.::

    $ sudo mount -o loop,ro burrito-2.0.5_8.9.iso /mnt

Unarchive burrito-2.0.5 tarball from the iso.::

    $ tar xzf /mnt/burrito-2.0.5.tar.gz

Back up localrepo.cfg and registry.cfg in /etc/haproxy/conf.d/.::

    $ sudo mv /etc/haproxy/conf.d/localrepo.cfg \
                /etc/haproxy/conf.d/localrepo.cfg.bak
    $ sudo mv /etc/haproxy/conf.d/registry.cfg \
                /etc/haproxy/conf.d/registry.cfg.bak

Reload haproxy.service on the first control node.::

    $ sudo systemctl reload haproxy.service

Run prepare.sh script.::

    $ cd burrito-2.0.5
    $ ./prepare.sh offline

Copy files from the existing burrito dir (e.g. $HOME/burrito-1.4.2).::

    $ cp $HOME/burrito-1.4.2/.vaultpass .
    $ cp $HOME/burrito-1.4.2/group_vars/all/vault.yml group_vars/all/
    $ cp $HOME/burrito-1.4.2/.offline_flag .

Edit hosts and vars.yml for your environment.::

    $ vi hosts
    $ vi vars.yml

Edit group_vars/all/\*.yml if you modified them
for your environment.::

    $ vi group_vars/all/netapp_vars.yml
    $ vi group_vars/all/ceph_vars.yml

Check the node connectivity.::

    $ ./run.sh ping

Check if keepalived_vip(192.168.21.110) is on the first control node.::

    $ ip -br a s dev eth1
    eth1             UP             192.168.21.111/24 192.168.21.110/32 fe80::5054:ff:feeb:2b8b/64

If it is not, move keepalived_vip to the first control node by restarting 
keepalived service.
For example, if keepalived_vip is on the second control node, 
restart keepalived service on the second control node.::

    $ sudo systemctl restart keepalived.service

Then the keepalived_vip will be moved to the first control node.

Modify --anonymous-auth to true in
/etc/kubernetes/manifests/kube-apiserver.yaml on every control node.::

    $ sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
    ...
        - --anonymous-auth=true

Wait until kube-apiserver is restarted on each control node.

Check if we can connect to each kube-apiserver.::

    $ curl -sk https://192.168.21.111:6443/healthz
    ok
    $ curl -sk https://192.168.21.112:6443/healthz
    ok
    $ curl -sk https://192.168.21.113:6443/healthz
    ok

Remove registry, localrepo, and asklepios pods.::

    $ sudo kubectl delete deploy registry localrepo asklepios -n kube-system
    deployment.apps "registry" deleted
    deployment.apps "localrepo" deleted
    deployment.apps "asklepios" deleted

These pods will be recreated while upgrading.

You are ready to upgrade kubernetes cluster now.

Upgrade kubernetes
-------------------

Run k8s playbook with upgrade_cluster_setup=true.::

    $ ./run.sh k8s -e upgrade_cluster_setup=true

It will take a long time. 
It took about 52 minutes in my VM environment.

Check if the kubernetes version is v1.29.2.::

    $ kubectl version
    Client Version: v1.29.2
    Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
    Server Version: v1.29.2

Run patch playbook.::

    $ ./run.sh patch

Run registry playbook.::

    $ ./run.sh registry

Check the new images(e.g. kube-apiserver:v1.29.2) are added to 
the local registry.::

    $ curl -s 192.168.21.110:32680/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.28.3","v1.29.2"]}

Run landing playbook.::

    $ ./run.sh landing

Check the new images(e.g. kube-apiserver:v1.29.2) are added to 
the genesis registry.::

    $ curl -s 192.168.21.110:6000/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.28.3","v1.29.2"]}


Kubernetes upgrade is done!


Upgrade OpenStack
--------------------

We will upgrade each openstack component one by one.

Here is a version table.

===============  ============ ==============
Components       Aster 1.4.2  Begonia 2.0.5
===============  ============ ==============
ingress          v1.1.3       v1.8.2
mariadb          10.6.16      10.11.7
rabbitmq         3.11.28      3.12.11
memcached        1.6.17       1.6.22
libvirt          6.0.0        8.0.0
keystone         21.0.2.dev3  23.0.2.dev10
glance           24.2.2.dev1  26.0.1.dev2
placement        7.0.1        9.0.1
neutron          20.5.1.dev28 22.1.1.dev110
nova             25.3.1.dev1  27.2.1.dev19
cinder           20.3.3.dev2  22.1.2.dev10
horizon          22.1.0       23.1.1.dev14
btx              1.2.3        2.0.1
===============  ============ ==============

Before upgrading openstack
++++++++++++++++++++++++++++

Before upgrade, we need to do the following tasks.

Stop all VM instances.::

    root@btx-0:/# o server stop <VM_NAME> [<VM_NAME> ...]

Get all compute node id.::

    root@btx-0:/# o hypervisor list
    +--------------------------------------+---------------------+-----------------+----------------+-------+
    | ID                                   | Hypervisor Hostname | Hypervisor Type | Host IP        | State |
    +--------------------------------------+---------------------+-----------------+----------------+-------+
    | 5febbf97-71dc-4ae0-a902-2217ee97cd3b | aster-compute       | QEMU            | 192.168.21.114 | up    |
    +--------------------------------------+---------------------+-----------------+----------------+-------+

Create /var/lib/nova/compute_id on each compute node.::

    $ echo 5febbf97-71dc-4ae0-a902-2217ee97cd3b | sudo -u nova tee /var/lib/nova/compute_id

(For netapp nfs)
Preserve nova-instances PVC if NetApp NFS is the default storage backend.

Patch nova-instances PVC.::

    $ NOVA_INSTANCES_PVC=$(kubectl get pvc nova-instances -n openstack \
        -o jsonpath='{.spec.volumeName}')
    $ echo $NOVA_INSTANCES_PVC
    pvc-cc0d533d-eaaf-4a8f-81a0-3e11d9720944
    $ sudo kubectl patch pv $NOVA_INSTANCES_PVC -p \
        '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
    persistentvolume/pvc-cc0d533d-eaaf-4a8f-81a0-3e11d9720944 patched

Uninstall the following components.
These components cannot be upgraded while they are running.::

    $ ./scripts/burrito.sh uninstall nova
    $ ./scripts/burrito.sh uninstall ingress
    $ ./scripts/burrito.sh uninstall mariadb
    $ ./scripts/burrito.sh uninstall rabbitmq

(For netapp nfs)
Patch nova-instances PVC to nullify claim.::

    $ sudo kubectl patch pv $NOVA_INSTANCES_PVC -p \
        '{"spec":{"claimRef": {"resourceVersion": null, "uid": null}}}'
    persistentvolume/pvc-cc0d533d-eaaf-4a8f-81a0-3e11d9720944 patched

(For netapp nfs)
Add volumeName in openstack-helm/nova/templates/pvc-instances.yaml.::

    spec:
      accessModes: [ "ReadWriteMany" ]
      resources:
        requests:
          storage: {{ .Values.volume.size }}
      storageClassName: {{ .Values.volume.class_name }}
      volumeName: pvc-cc0d533d-eaaf-4a8f-81a0-3e11d9720944
    {{- end }}

(For netapp nfs)
Detach all volumes that ingress, mariadb, and rabbitmq are using.

:download:`remove_volumeattachment script <../_static/remove_volumeattachment.sh>`.::

    $ chmod +x remove_volumeattachment.sh
    $ ./remove_volumeattachment.sh
    ingress-0 pvc: pvc-28fb7360-cef8-4d64-9edb-08636f6c2e6b
    ingress-0 volumeattachment id: csi-63fe882673981ce326e6eb7fbf1da194300e1bed9a30a2a5f7366172f5247887
    volumeattachment.storage.k8s.io "csi-63fe882673981ce326e6eb7fbf1da194300e1bed9a30a2a5f7366172f5247887" deleted
    ...
    mariadb-0 pvc: pvc-9b95c69f-2e8e-47ec-ad79-2bc1ca5c0dde
    mariadb-0 volumeattachment id: csi-1d8d1834daf738654f4f79f587745f9c5469a3f7c0329b235b368f8b46f5c529
    volumeattachment.storage.k8s.io "csi-1d8d1834daf738654f4f79f587745f9c5469a3f7c0329b235b368f8b46f5c529" deleted
    ...
    rabbitmq-2 pvc: pvc-c201cc59-63fb-4cb2-8149-bfafe91d0d14
    rabbitmq-2 volumeattachment id: csi-b52b24c2da084ea89f816b2d9bb9417836937784ef9c65d0c36292b3302288bf
    volumeattachment.storage.k8s.io "csi-b52b24c2da084ea89f816b2d9bb9417836937784ef9c65d0c36292b3302288bf" deleted

(For netapp nfs)
Unmount /var/lib/nova/instances in every compute node
if netapp NFS is the default storage backend.::

    $ sudo umount /var/lib/nova/instances

Run burrito playbook with system tag.::

    $ ./run.sh burrito --tags=system

Upgrade openstack infra components
+++++++++++++++++++++++++++++++++++

Upgrade ingress (v1.1.3 -> v1.8.2).::

    $ ./scripts/burrito.sh install ingress

Check if ingress pods are running and ready.::

    root@btx-0:/# k get po -l application=ingress,component=server
    NAME        READY   STATUS    RESTARTS   AGE
    ingress-0   1/1     Running   0          2m
    ingress-1   1/1     Running   0          96s
    ingress-2   1/1     Running   0          57s

Upgrade mariadb (10.6.16 -> 10.11.7).::

    $ ./scripts/burrito.sh install mariadb

Check if mariadb server pods are running and ready.::

    root@btx-0:/# k get po -l application=mariadb,component=server
    NAME               READY   STATUS    RESTARTS   AGE
    mariadb-server-0   1/1     Running   0          4m53s
    mariadb-server-1   1/1     Running   0          4m53s
    mariadb-server-2   1/1     Running   0          4m53s

Upgrade rabbitmq (3.11.28 -> 3.12.11).::

    $ ./scripts/burrito.sh install rabbitmq

Check if rabbitmq server pods are running and ready.::

    root@btx-0:/# k get po -l application=rabbitmq,component=server
    NAME                  READY   STATUS    RESTARTS      AGE
    rabbitmq-rabbitmq-0   1/1     Running   0             4m25s
    rabbitmq-rabbitmq-1   1/1     Running   0             4m25s
    rabbitmq-rabbitmq-2   1/1     Running   1 (60s ago)   4m25s

Upgrade memcached (1.6.17 -> 1.6.22).::

    $ ./scripts/burrito.sh install memcached

Check if memcached pod is running and ready.::

    root@btx-0:/# k get po -l application=memcached
    NAME                                   READY   STATUS    RESTARTS   AGE
    memcached-memcached-5cd8fc7496-cpx5m   1/1     Running   0          22s

Upgrade libvirt (6.0.0 -> 8.0.0).::

    $ ./scripts/burrito.sh install libvirt

Check if libvirt pods are running and ready.::

    root@btx-0:/# k get po -l application=libvirt
    NAME                            READY   STATUS    RESTARTS   AGE
    libvirt-libvirt-default-rq85p   1/1     Running   0          74s

Upgrade openstack components
++++++++++++++++++++++++++++++

Upgrade keystone (21.0.2.dev3 -> 23.0.2.dev10).::

    $ ./scripts/burrito.sh install keystone

Check if keystone pods are running and ready.::

    root@btx-0:/# k get po -l application=keystone,component=api
    NAME                            READY   STATUS    RESTARTS   AGE
    keystone-api-786c7866d6-crzsz   1/1     Running   0          2m9s
    keystone-api-786c7866d6-gzc9g   1/1     Running   0          2m9s

If glance-api is a type of statefulset
(i.e. if the default storage is not netapp),
uninstall glance first.::

    $ k get po -l application=glance,component=api
    glance-api-0                 2/2     Running     0          72m
    glance-api-1                 2/2     Running     0          72m
    $ ./scripts/burrito.sh uninstall glance

Upgrade glance (24.2.2.dev1 -> 26.0.1.dev2).::

    $ ./scripts/burrito.sh install glance

One of glance-api pods can be stuck in init state (netapp nfs only).::

    root@btx-0:/# k get po -l application=glance,component=api
    NAME                          READY   STATUS     RESTARTS   AGE
    glance-api-596d7cf6c8-5srzp   2/2     Running    0          7m22s
    glance-api-596d7cf6c8-z4lnr   0/2     Init:0/2   0          7m22s

Just delete the Init-state pod. Then it will be running okay.

Check if glance pods are running and ready.

If glance-api is a type of deployment
(i.e. if the default storage is netapp)::

    root@btx-0:/# k delete po glance-api-596d7cf6c8-z4lnr
    root@btx-0:/# k get po -l application=glance,component=api
    NAME                          READY   STATUS    RESTARTS   AGE
    glance-api-596d7cf6c8-5srzp   2/2     Running   0          9m23s
    glance-api-596d7cf6c8-g7s7c   2/2     Running   0          94s

If glance-api is a type of statefulset
(i.e. if the default storage is not netapp)::

    root@btx-0:/# k get po -l application=glance,component=api
    NAME           READY   STATUS    RESTARTS   AGE
    glance-api-0   2/2     Running   0          25m
    glance-api-1   2/2     Running   0          25m

Upgrade placement (7.0.1 -> 9.0.1).::

    $ ./scripts/burrito.sh install placement

Check if placement pods are running and ready.::

    root@btx-0:/# k get po -l application=placement,component=api
    NAME                             READY   STATUS    RESTARTS   AGE
    placement-api-6d7948d754-9lfrg   1/1     Running   0          2m41s

Upgrade neutron (20.5.1.dev28 -> 22.1.1.dev110).::

    $ ./scripts/burrito.sh install neutron

Some pods(neutron-{dhcp,l3,meata}-agent) will be in Init state.
That's okay since they are waiting for nova pods.

Before upgrading nova, we need to preserve images_type variable value.
It is `qcow2` in Aster 1.4.2 and earlier while it is `rbd` in Begonia.

Set `images_type` to `qcow2` in
roles/burrito.openstack/templates/osh/nova.yml.j2.::

    libvirt:
      volume_use_multipath: {{ enable_multipath }}
      connection_uri: "qemu+tcp://127.0.0.1/system"
      images_type: "qcow2"

Upgrade nova (25.3.1.dev1 -> 27.2.1.dev19).::

    $ ./scripts/burrito.sh install nova

Check if nova pods are running and ready.::

    root@btx-0:/# k get po -l application=nova,component=compute
    NAME                         READY   STATUS    RESTARTS        AGE
    nova-compute-default-2vn7r   1/1     Running   0               10m

If cinder-volume is a type of statefulset
(i.e. if the default storage is not netapp),
uninstall cinder first.::

Upgrade cinder (20.3.3.dev2 -> 22.1.2.dev10).::

    $ ./scripts/burrito.sh install cinder

Check if cinder pods are running and ready.

If cinder-volume is a type of deployment
(i.e. if the default storage is netapp)::

    root@btx-0:/# k get po -l application=cinder,component=volume
    NAME                            READY   STATUS     RESTARTS   AGE
    cinder-volume-86cf778db-2469r   1/1     Running    0          6m2s
    cinder-volume-86cf778db-mhg7b   0/1     Init:0/4   0          6m2s

One of cinder-volume is stuck at Init state. This is the same problem as
glance-api.
Just delete the second cinder-volume and it will be okay.::

    root@btx-0:/# k delete po cinder-volume-86cf778db-mhg7b
    root@btx-0:/# k get po -l application=cinder,component=volume
    NAME                            READY   STATUS    RESTARTS   AGE
    cinder-volume-86cf778db-2469r   1/1     Running   0          7m33s
    cinder-volume-86cf778db-pxf5v   1/1     Running   0          28s

If cinder-volume is a type of statefulset
(i.e. if the default storage is not netapp)::

    root@btx-0:/# k get po -l application=cinder,component=volume
    NAME              READY   STATUS    RESTARTS   AGE
    cinder-volume-0   1/1     Running   0          5m20s
    cinder-volume-1   1/1     Running   0          5m20s

Upgrade horizon (22.1.0 -> 23.1.1.dev14).::

    $ ./scripts/burrito.sh install horizon

Check if horizon pods are running and ready.::

    root@btx-0:/# k get po -l application=horizon,component=server
    NAME                      READY   STATUS    RESTARTS   AGE
    horizon-bfdcc7bd6-4n655   1/1     Running   0          84s
    horizon-bfdcc7bd6-w9wqh   0/1     Running   0          84s

Sometimes One of horizon pods could not be ready.
Just delete it and it's all good.::

    root@btx-0:/# k get po -l application=horizon,component=server
    NAME                      READY   STATUS    RESTARTS   AGE
    horizon-bfdcc7bd6-4n655   1/1     Running   0          5m59s
    horizon-bfdcc7bd6-pg589   1/1     Running   0          76s

Last but not least, upgrade btx (1.2.3 -> 2.0.1).::

    $ ./scripts/burrito.sh uninstall btx
    $ ./scripts/burrito.sh install btx

Check btx is running.::

    $ kubectl get po btx-0 -n openstack
    NAME    READY   STATUS    RESTARTS   AGE
    btx-0   1/1     Running   0          79s

Go to btx shell and check openstack services.::

    $ bts
    root@btx-0:/# o compute service list
    root@btx-0:/# o volume service list
    root@btx-0:/# o network agent list

If everything is okay, start the previously stopped VM instances.::

    root@btx-0:/# o server start <VM_NAME> [<VM_NAME> ...]


OpenStack Upgrade is Done!!!

