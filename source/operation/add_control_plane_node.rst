Add control plane nodes
========================

You have a single control plane node in a Burrito cluster and
you want to add two control plane nodes.

This guide shows you how to add the control plane nodes 
in an existing Burrito cluster.

This is the current host inventory.::

    extend-control1 ip=192.168.21.131 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
    extend-compute ip=192.168.21.134
    extend-storage ip=192.168.21.135
    
    # ceph nodes
    [mons]
    extend-storage
    
    [mgrs]
    extend-storage
    
    [osds]
    extend-storage
    
    [rgws]
    extend-storage
    
    [clients]
    extend-control1
    extend-compute
    
    # kubernetes nodes
    [kube_control_plane]
    extend-control1
    
    [kube_node]
    extend-control1
    extend-compute
    
    # openstack nodes
    [controller-node]
    extend-control1
    
    [network-node]
    extend-control1
    
    [compute-node]
    extend-compute
    
    ###################################################
    ## Do not touch below if you are not an expert!!! #
    ###################################################


There is only one control plane node.
I will add two control plane nodes in the host inventory.

Edit hosts inventory file
--------------------------

Add extend-control{2,3} in hosts.::

    $ diff -u hosts.old hosts
    --- hosts.old
    +++ hosts
    @@ -1,4 +1,6 @@
     extend-control1 ip=192.168.21.131 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
    +extend-control2 ip=192.168.21.132
    +extend-control3 ip=192.168.21.133
     extend-compute ip=192.168.21.134
     extend-storage ip=192.168.21.135
    
    @@ -16,23 +18,23 @@
     extend-storage
    
     [clients]
    -extend-control1
    +extend-control[1:3]
     extend-compute
    
     # kubernetes nodes
     [kube_control_plane]
    -extend-control1
    +extend-control[1:3]
    
     [kube_node]
    -extend-control1
    +extend-control[1:3]
     extend-compute
    
     # openstack nodes
     [controller-node]
    -extend-control1
    +extend-control[1:3]
    
     [network-node]
    -extend-control1
    +extend-control[1:3]
    
     [compute-node]
     extend-compute
    
    ###################################################
    ## Do not touch below if you are not an expert!!! #
    ###################################################


Patch
------

Download a patch script 
:download:`add_control_patch.sh <../static/add_control_patch.sh>` and
put it in burrito top directory on the first control plane node.

Run the patch script.::

    $ chmod +x add_control_patch.sh
    $ ./add_control_patch.sh
    patching file roles/burrito.system/tasks/main.yml
    patching file run.sh

Preflight
----------

Run the preflight playbook with --limit parameter.::

    $ ./run.sh preflight --limit=extend-control2,extend-control3

Check if the yum repository is set up on the new control plane nodes.::

   [clex@extend-control2 ~]$ sudo dnf repoinfo
   Last metadata expiration check: 0:03:01 ago on Wed 16 Oct 2024 11:28:42 AM KST.
   Repo-id            : burrito
   Repo-name          : Burrito BaseOS
   Repo-revision      : 1713854508
   Repo-updated       : Tue 23 Apr 2024 03:41:48 PM KST
   Repo-pkgs          : 620
   Repo-available-pkgs: 620
   Repo-size          : 816 M
   Repo-baseurl       : http://192.168.21.131:8001/BaseOS
   Repo-expire        : 172,800 second(s) (last: Wed 16 Oct 2024 11:28:42 AM KST)
   Repo-filename      : /etc/yum.repos.d/burrito.repo
   Total packages: 620

Check if time is synced.::

   [clex@extend-control2 ~]$ chronyc tracking
   Reference ID    : C0A81583 (extend-control1)
   Stratum         : 9
   Ref time (UTC)  : Wed Oct 16 02:31:17 2024
   System time     : 0.000000000 seconds fast of NTP time
   Last offset     : -0.445706338 seconds
   RMS offset      : 0.445706338 seconds
   Frequency       : 0.125 ppm fast
   Residual freq   : +0.000 ppm
   Skew            : 41.850 ppm
   Root delay      : 0.000386291 seconds
   Root dispersion : 0.002296808 seconds
   Update interval : 0.0 seconds
   Leap status     : Normal

HA
---

Run the ha playbook to install keepalived and haproxy on new nodes.::

    $ ./run.sh ha

Check if keepalived and haproxy service are running on the new nodes.::

    $ sudo systemctl status keepalived haproxy

Check if the keepalived VIP is on the first control plane node.::

    FIRST_CONTROL_PLANE_NODE$ ip -br a s dev MGMT_IFACE

MGMT_IFACE is the management interface name (e.g. eth1).

The keepalived VIP could be moved to the other control plane node.
If it is moved, move it back to the first control plane node by restarting
keepalived service on the node having the keepalived VIP.::

    $ sudo systemctl restart keepalived.service

Ceph
-----

If ceph is in storage backends, 
run the ceph playbook with 'ceph_client' tag to install ceph client 
on the new nodes.::

    $ ./run.sh ceph --tags=ceph_client

Check 'ceph -s' command works on the new nodes.::

    $ sudo ceph -s
      cluster:
        id:     8d902f73-3445-449e-9246-03b8b459821f
        health: HEALTH_OK
     
      services:
        mon: 1 daemons, quorum extend-storage (age 17h)
        mgr: extend-storage(active, since 17h)
        osd: 3 osds: 3 up (since 17h), 3 in (since 17h)
        rgw: 1 daemon active (1 hosts, 1 zones)
     
      data:
        pools:   10 pools, 289 pgs
        objects: 2.31k objects, 6.8 GiB
        usage:   15 GiB used, 285 GiB / 300 GiB avail
        pgs:     289 active+clean
     
      io:
        client:   61 KiB/s wr, 0 op/s rd, 9 op/s wr


K8S
----

Before running the k8s playbook, we need to change kube-apiserver parameter
in the first control plane node.::

    $ sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
    ...
        - --anonymous-auth=true

Wait until kube-apiserver is restarted on each control node.

Check if we can connect to kube-apiserver on the first control plane node.::

    $ curl -sk https://THE_FIRST_CONTROL_PLANE_NODE_IP:6443/healthz
    ok

Run the k8s playbook.::

    $ ./run.sh k8s --extra-vars="registry_enabled="

Check the node list.::

    $ sudo kubectl get nodes
    NAME              STATUS   ROLES           AGE     VERSION
    extend-compute    Ready    <none>          4h19m   v1.28.3
    extend-control1   Ready    control-plane   4h20m   v1.28.3
    extend-control2   Ready    control-plane   110m    v1.28.3
    extend-control3   Ready    control-plane   110m    v1.28.3

Patch
------

Run the patch playbook.::

    $ ./run.sh patch

Landing
--------

Run the landing playbook.::

    $ ./run.sh landing --tags=genesisregistry

Check if the genesis registry service is running on the added nodes.::

    $ sudo systemctl status genesis_registry.service

Run the localrepo_haproxy_setup playbook.::

    $ ./run.sh localrepo_haproxy_setup

Check if the localrepo.cfg file is in /etc/haproxy/conf.d/ on the added nodes.::

    $ sudo ls -1 /etc/haproxy/conf.d/localrepo.cfg
    /etc/haproxy/conf.d/localrepo.cfg

Burrito.system
---------------

Run the burrito playbook with --tags=system.::

    $ ./run.sh burrito --tags=system

Check if you can run kubectl command on the added nodes.::

    $ kubectl get po -n kube-system


OpenStack
----------

Reinstall each openstack component.

There are two types of replicas - the HA replica and the quorum replica.

The HA replica type sets up two pods for high availability. 
The quorum replica type sets up three pods for quorum membership.

The mariadb and rabbitmq are the quorum replica type.
The others are the HA replica type except the ingress.
The ingress is a special replica type that works like a daemonset.

Install ingress.::

    $ ./scripts/burrito.sh install ingress

Check if there are three ingress pods.::

    root@btx-0:/# k get po -l application=ingress,component=server
    NAME                                   READY   STATUS    RESTARTS   AGE
    ingress-0                              1/1     Running   0          24h
    ingress-1                              1/1     Running   0          2m4s
    ingress-2                              1/1     Running   0          86s

Install mariadb.::

    $ ./scripts/burrito.sh install mariadb

Check if there are three mariadb server pods.::

    root@btx-0:/# k get po -l application=mariadb,component=server
    NAME               READY   STATUS    RESTARTS   AGE
    mariadb-server-0   1/1     Running   0          76s
    mariadb-server-1   1/1     Running   0          3m27s
    mariadb-server-2   1/1     Running   0          3m27s

Install rabbitmq.::

    $ ./scripts/burrito.sh install rabbitmq

Check if there are three rabbitmq pods.::

    root@btx-0:/# k get po -l application=rabbitmq,component=server
    NAME                  READY   STATUS    RESTARTS   AGE
    rabbitmq-rabbitmq-0   1/1     Running   0          25h
    rabbitmq-rabbitmq-1   1/1     Running   0          4m26s
    rabbitmq-rabbitmq-2   1/1     Running   0          4m26s

Install keystone.::

    $ ./scripts/burrito.sh install keystone

Check if there are two keystone-api pods.::

    root@btx-0:/# k get po -l application=keystone,component=api
    NAME                            READY   STATUS    RESTARTS   AGE
    keystone-api-667dfbb9bd-bjt6f   1/1     Running   0          112s
    keystone-api-667dfbb9bd-f5kjn   1/1     Running   0          112s

Install glance.::

    $ ./scripts/burrito.sh install glance

Check if there are two glance-api pods.::

    root@btx-0:/# k get po -l application=glance,component=api
    NAME           READY   STATUS    RESTARTS   AGE
    glance-api-0   2/2     Running   0          61m
    glance-api-1   2/2     Running   0          62m

Install neutron.::

    $ ./scripts/burrito.sh install neutron

Check if there are two neutron server pods.::

    root@btx-0:/# k get po -l application=neutron,component=server
    NAME                              READY   STATUS    RESTARTS   AGE
    neutron-server-567dfbfd84-p8vdr   2/2     Running   0          128m
    neutron-server-567dfbfd84-wjsmr   2/2     Running   0          128m

Install nova.::

    $ ./scripts/burrito.sh install nova

Check if there are two nova-api pods.::

    root@btx-0:/# k get po -l application=nova,component=os-api
    NAME                              READY   STATUS    RESTARTS   AGE
    nova-api-osapi-7d95bf7f85-h2prv   1/1     Running   0          6m26s
    nova-api-osapi-7d95bf7f85-twhvg   1/1     Running   0          6m26s

Install cinder.::

    $ ./scripts/burrito.sh install cinder

Check if there are two cinder-api pods.::

    root@btx-0:/# k get po -l application=cinder,component=api
    NAME                          READY   STATUS    RESTARTS   AGE
    cinder-api-7549d5dbb7-4j5tt   1/1     Running   0          2m10s
    cinder-api-7549d5dbb7-v9mw7   1/1     Running   0          2m10s

Install horizon.::

    $ ./scripts/burrito.sh install horizon

Check if there are two horizon pods.::

    root@btx-0:/# k get po -l application=horizon,component=server
    NAME                       READY   STATUS    RESTARTS   AGE
    horizon-56454f565f-5tdgv   1/1     Running   0          2m27s
    horizon-56454f565f-vc2vg   1/1     Running   0          2d


We have finished adding the control plane nodes in burrito cluster.

