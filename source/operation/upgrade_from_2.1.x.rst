Upgrade from 2.1.x
===================

This is a guide to upgrade Burrito Begonia 2.1.x to 2.2.0.

I assume Burrito Begonia 2.1.x is already installed and running.
This guide will show you how to upgrade it to Burrito Begonia 2.2.0.

Here is the example node ip address table.

===============     ================
Hostname            management IP         
===============     ================
control1            192.168.21.111
control2            192.168.21.112
control3            192.168.21.113
compute1            192.168.21.114
compute2            192.168.21.115
storage1            192.168.21.116
storage2            192.168.21.117
storage3            192.168.21.118
===============     ================

* KeepAlived VIP: 192.168.21.110

This is a version table between 2.1.x and 2.2.0.

===============  ============= ==============
Components       Begonia 2.1.x  Begonia 2.2.0
===============  ============= ==============
ceph                v18.2.1     v18.2.7
ceph-client         v18.2.1     v18.2.2
containerd          v1.7.16     v2.0.5
kubernetes          v1.30.3     v1.31.9
etcd                v3.5.12     v3.5.16
calico              v3.27.3     same as left
coredns             v1.11.1     v1.11.3
helm                v3.14.2     v1.16.4
nerdctl             1.7.4       2.0.5
crictl              v1.30.0     v1.31.1
nodelocaldns        1.22.28     1.25.0
cert-manager        v1.14.7     v1.15.3
metallb             v0.13.9     same as left
registry            2.8.3       same as left
===============  ============= ==============

Modify kube-apiserver
----------------------

Modify \--anonymous-auth to true in
/etc/kubernetes/manifests/kube-apiserver.yaml on every control node.::

    $ sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
    ...
        - --anonymous-auth=true

Wait until kube-apiserver is restarted on each control node.

Check if we can connect to each kube-apiserver.::

    $ curl -sk https://control1:6443/healthz
    ok
    $ curl -sk https://control2:6443/healthz
    ok
    $ curl -sk https://control3:6443/healthz
    ok

Prepare 2.2.0 iso
--------------------

We will use Burrito 2.2.0 iso to upgrade the existing Burrito
2.1.x cluster.

Mount burrito-2.2.0_8.10.iso in /mnt.::

    $ sudo mount -o loop,ro burrito-2.2.0_8.10.iso /mnt

Unarchive burrito-2.2.0 tarball from the iso.::

    $ tar xzf /mnt/burrito-2.2.0.tar.gz

Remove localrepo.cfg and registry.cfg in /etc/haproxy/conf.d/.::

    $ sudo mv /etc/haproxy/conf.d/localrepo.cfg \
        /etc/haproxy/conf.d/localrepo.cfg.bak
    $ sudo mv /etc/haproxy/conf.d/registry.cfg \
        /etc/haproxy/conf.d/registry.cfg.bak

These haproxy configuration files will be recreated while upgrading.

Reload haproxy.service on the first control node.::

    $ sudo systemctl reload haproxy.service

Run prepare.sh script.::

    $ cd burrito-2.2.0
    $ ./prepare.sh offline

Copy files from the existing burrito dir (e.g. $HOME/burrito-2.1.x).::

    $ cp $HOME/burrito-2.1.x/.vaultpass .
    $ cp $HOME/burrito-2.1.x/group_vars/all/vault.yml group_vars/all/

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
    eth1             UP             192.168.21.111/24 192.168.21.110/32

If it is not, move keepalived_vip to the first control node by restarting 
keepalived service.
For example, if keepalived_vip is on the second control node, 
restart keepalived service on the second control node.::

    $ sudo systemctl restart keepalived.service

Then the keepalived_vip will be moved to the first control node.

Remove asklepios and registry pods.::

    $ sudo kubectl delete deploy asklepios registry -n kube-system
    deployment.apps "asklepios" deleted
    deployment.apps "registry" deleted

These pods will be recreated while upgrading.

Run preflight playbook.::

    $ ./run.sh preflight

You are ready to upgrade.

Update OpenStack
-----------------

Update OpenStack Infra components
+++++++++++++++++++++++++++++++++++

Update ingress, libvirt, mariadb, memcached, and rabbitmq.::

    $ ./scripts/burrito.sh install ingress
    $ ./scripts/burrito.sh install libvirt
    $ ./scripts/burrito.sh install mariadb
    $ ./scripts/burrito.sh install memcached
    $ ./scripts/burrito.sh install rabbitmq
    ...

Make sure the upated pods are running and ready before you move on to the next
component.


Update OpenStack components
++++++++++++++++++++++++++++

(For netapp nfs only)
Before upgrade, stop all VM instances.::

    root@btx-0:/# o server stop <VM_NAME> [<VM_NAME> ...]

Update keystone, placement, neutron.::

    $ ./scripts/burrito.sh install keystone
    $ ./scripts/burrito.sh install placement
    $ ./scripts/burrito.sh install neutron

Nova cannot be updated while it is running.
So we will uninstall nova.

(For netapp nfs only)
Preserve nova-instances PVC if NetApp NFS is the default storage backend.
Patch nova-instances PVC.::

    $ NOVA_INSTANCES_PVC=$(kubectl get pvc nova-instances -n openstack \
        -o jsonpath='{.spec.volumeName}')
    $ echo $NOVA_INSTANCES_PVC
    pvc-cc0d533d-eaaf-4a8f-81a0-3e11d9720944
    $ sudo kubectl patch pv $NOVA_INSTANCES_PVC -p \
        '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
    persistentvolume/pvc-cc0d533d-eaaf-4a8f-81a0-3e11d9720944 patched

Uninstall nova which cannot be upgraded while it is running.::

    $ ./scripts/burrito.sh uninstall nova

(For netapp nfs only)
Patch nova-instances PVC to nullify the claim.::

    $ sudo kubectl patch pv $NOVA_INSTANCES_PVC -p \
        '{"spec":{"claimRef": {"resourceVersion": null, "uid": null}}}'
    persistentvolume/pvc-cc0d533d-eaaf-4a8f-81a0-3e11d9720944 patched

(For netapp nfs only)
Add volumeName in openstack-helm/nova/templates/pvc-instances.yaml.::

    spec:
      accessModes: [ "ReadWriteMany" ]
      resources:
        requests:
          storage: {{ .Values.volume.size }}
      storageClassName: {{ .Values.volume.class_name }}
      volumeName: pvc-cc0d533d-eaaf-4a8f-81a0-3e11d9720944
    {{- end }}

(For netapp nfs only)
Unmount /var/lib/nova/instances in every compute node
if netapp NFS is the default storage backend
Run the following ansible command.::

    $ . ~/.envs/burrito/bin/activate && \
      ansible --become compute-node -m ansible.posix.mount \
        -a "path=/var/lib/nova/instances state=unmounted"

Install nova, glance, cinder, and horizon.::

    $ ./scripts/burrito.sh install nova
    $ ./scripts/burrito.sh install glance
    $ ./scripts/burrito.sh install cinder
    $ ./scripts/burrito.sh install horizon

Make sure the updated pods are running and ready before you move on to the next
component.

Check any openstack operations are okay.

* checking openstack compute, volume and network agent services
* listing images, volumes and instances
* creating an image and a volume, and an instance
* deleting an instance, a volume, and an image

If everything is okay, start the previously stopped VM instances.::

    root@btx-0:/# o server start <VM_NAME> [<VM_NAME> ...]

OpenStack is updated.


Upgrade Ceph
--------------

If ceph is not installed, skip this.

We will upgrade Burrito 2.1.8 (ceph reef 18.2.1) to Burrito 2.2.0
(ceph reef 18.2.7).

Here is the example ceph node table.

===============     ================    ==============
Host                Role                IP address
===============     ================    ==============
storage1            mon,mgr,osd         192.168.24.116
storage2            mon,mgr,osd,rgw     192.168.24.117
storage3            mon,osd,rgw         192.168.24.118
===============     ================    ==============

* ceph public/cluster network: 192.168.24.0/24
* osd devices on each osd node: /dev/sdb, /dev/sdc, /dev/sdd

Check ceph health status.::

    $ sudo ceph -s

Turn off autoscale.::

    $ sudo ceph osd pool set noautoscale
    noautoscale is set, all pools now have autoscale off

Upgrade to ceph v18.2.7.::

    $ sudo ceph orch upgrade start --image 192.168.21.110:5000/ceph/ceph:v18.2.7
    Initiating upgrade to 192.168.21.110:5000/ceph/ceph:v18.2.7

Check upgrade status.::

    $ sudo ceph orch upgrade status
    {
        "target_image": "192.168.21.110:5000/ceph/ceph:v18.2.7",
        "in_progress": true,
        "which": "Upgrading all daemon types on all hosts",
        "services_complete": [],
        "progress": "",
        "message": "Doing first pull of 192.168.21.110:5000/ceph/ceph:v18.2.7 image",
        "is_paused": false
    }

It will upgrade manager, monitor, crash, osd, and radosgw in that order.

Check each ceph component is upgraded to new versions.::

    $ sudo ceph versions
    {
        "mon": {
            "ceph version 18.2.7 (6b0e988052ec84cf2d4a54ff9bbbc5e720b621ad) reef (stable)": 3
        },
        "mgr": {
            "ceph version 18.2.7 (6b0e988052ec84cf2d4a54ff9bbbc5e720b621ad) reef (stable)": 2
        },
        "osd": {
            "ceph version 18.2.7 (6b0e988052ec84cf2d4a54ff9bbbc5e720b621ad) reef (stable)": 9
        },
        "rgw": {
            "ceph version 18.2.7 (6b0e988052ec84cf2d4a54ff9bbbc5e720b621ad) reef (stable)": 2
        },
        "overall": {
            "ceph version 18.2.7 (6b0e988052ec84cf2d4a54ff9bbbc5e720b621ad) reef (stable)": 16
        }
    }

The 18.2.7 ceph-common package is not available for Rocky Linux 8.
The latest ceph-common package for Rocky Linux 8 is v18.2.2.
Upgrade the ceph client package to v18.2.2 on every node.::

    $ . ~/.envs/burrito/bin/activate && \
      ansible all -m package -a "name=ceph-common state=latest" --become

Check the ceph client version.::

    $ ceph --version
    ceph version 18.2.2 (531c0d11a1c5d39fbfe6aa8a521f023abf3bf3e2) reef (stable)

Turn back on autoscale.::

    $ sudo ceph osd pool unset noautoscale
    noautoscale is unset, all pools now back to its previous mode

Ceph upgrade is done!

Upgrade kubernetes
-------------------

There is a problem with upgrading k8s v1.30 to v1.31. 

When kubelet is upgraded and restarted before kube-apiserver is upgraded,
some pods go to the failed states due to version skew problem and
the upgrade job is aborted.

To work around this problem, 
edit vars.yml to add *CreateJob* in kubeadm_ignore_preflight_errors.::

    kubeadm_ignore_preflight_errors:
      - "Port-{{ kube_apiserver_port }}"
      - "CreateJob"

Run k8s playbook with upgrade_cluster_setup=true.::

    $ ./run.sh k8s -e upgrade_cluster_setup=true

It will take a long time. 
It took about 50 minutes in my testbed.

Check if the kubernetes version is upgraded to v1.31.9.::

    $ kubectl version
    Client Version: v1.31.9
    Kustomize Version: v5.4.2
    Server Version: v1.31.9

(For netapp nfs only)
Uninstall trident before running storage playbook.::

    $ sudo tridentctl uninstall -n trident

Run storage playbook.::

    $ ./run.sh storage

Run patch playbook.::

    $ ./run.sh patch

Run registry playbook.::

    $ ./run.sh registry

Check the new images(e.g. kube-apiserver:v1.31.9) are added to 
the local registry.::

    $ curl -sk https://192.168.21.110:32680/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.30.3","v1.31.9"]}

Run landing playbook.::

    $ ./run.sh landing

Check the new images (e.g. kube-apiserver:v1.31.9) are added to 
the genesis registry.::

    $ curl -sk https://192.168.21.110:6000/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.30.3","v1.31.9"]}

Kubernetes upgrade is done!

You’ve completed the upgrade to Burrito 2.2.0.

