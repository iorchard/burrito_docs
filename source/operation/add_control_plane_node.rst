Add control planes
=====================

This is a guide to add control planes in the existing burrito cluster.

There is a single control plane in the burrito cluster 
and I want to add two control plane nodes.

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

I will add two control plane nodes.

Add extend-control{2,3} in hosts.::

    $ diff -u hosts.old hosts
    --- hosts.old	2024-10-16 11:09:39.412476505 +0900
    +++ hosts	2024-10-16 11:09:32.814476505 +0900
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

* Run preflight playbook with --limit parameter.::

    $ ./run.sh preflight --limit=extend-control2,extend-control3

Check burrito repo is set up.::

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

Check time is synced.::

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


* Run ha playbook to install keepalived and haproxy on new nodes.::

    $ ./run.sh ha

Check keepalived and haproxy service are running on the new nodes.::

    $ sudo systemctl status keepalived haproxy

Check the keepalived VIP is on the first control plane node.::

    FIRST_CONTROL_PLANE_NODE$ ip -br a s dev MGMT_IFACE

MGMT_IFACE is the management interface name (e.g. eth1).
The keepalived VIP could be moved to the other control plane node.
If it is moved, move it back to the first control plane node by restarting
keepalived service on the node.::

    $ sudo systemctl restart keepalived.service


* If ceph is in storage backends, 
  run ceph with 'ceph_client' tag to install ceph client on the new nodes.::

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

Before running k8s playbook, we need to change kube-apiserver parameter
in the first control plane node.::

    $ sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
    ...
        - --anonymous-auth=true

Wait until kube-apiserver is restarted on each control node.

Check if we can connect to kube-apiserver on the first control plane node.::

    $ curl -sk https://THE_FIRST_CONTROL_PLANE_NODE_IP:6443/healthz
    ok

* Run k8s playbook.::

    $ ./run.sh k8s --extra-vars=registry_enabled=false

Check the node list.::

    $ sudo kubectl get nodes
    NAME              STATUS   ROLES           AGE     VERSION
    extend-compute    Ready    <none>          4h19m   v1.28.3
    extend-control1   Ready    control-plane   4h20m   v1.28.3
    extend-control2   Ready    control-plane   110m    v1.28.3
    extend-control3   Ready    control-plane   110m    v1.28.3

* Run patch playbook.::

    $ ./run.sh patch

* Run landing playbook.::

    $ ./run.sh landing --tags=genesisregistry

Check the genesis registry service is running on the added nodes.

* Add haproxy.yml task file in burrito.localrepo role.::

    $ vi roles/burrito.localrepo/tasks/haproxy.yml
    ---
    - name: Local Repo | template local repo
      ansible.builtin.template:
        dest: "{{ item.dest }}"
        src: "{{ ansible_os_family | lower }}{{ item.dest + '.j2' }}"
        owner: "root"
        group: "root"
        mode: "0644"
      loop:
        - {dest: "/etc/yum.repos.d/burrito.repo"}
      become: true
    
    - name: Local Repo | add localrepo haproxy config
      ansible.builtin.template:
        dest: "{{ item.dest }}"
        src: "{{ ansible_os_family | lower }}{{ item.dest + '.j2' }}"
        owner: "{{ item.owner }}"
        group: "{{ item.group }}"
        mode: "{{ item.mode }}"
      loop: "{{ service_conf }}"
      become: true
      when: inventory_hostname in groups['kube_control_plane']
      notify:
        - haproxy reload service
    ...

Add localrepo_haproxy_setup.yml.::

    $ vi localrepo_haproxy_setup.yml
    ---
    - name: Set up local repo haproxy
      hosts: kube_control_plane
      any_errors_fatal: true
      tasks:
        - name: Set up local repo haproxy
          include_role:
            name: burrito.localrepo
            tasks_from: haproxy_setup
    ...


Run localrepo_haproxy_setup playbook.::

    $ ./run.sh localrepo_haproxy_setup

Check the localrepo.cfg file is in /etc/haproxy/conf.d/.::

    $ sudo ls -l /etc/haproxy/conf.d/localrepo.cfg


