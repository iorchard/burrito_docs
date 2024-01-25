Burrito Offline Installation
============================

This is a guide to install Burrito in offline environment.

Use the Burrito ISO to install.

You can build your own burrito iso using burrito_iso project
(https://github.com/iorchard/burrito_iso).

Supported OS
-------------

* Rocky Linux 8.x

System requirements
--------------------

This is the **minimum** system requirements to install Burrito.

If you have more resources, consider allocating more resources to each node.

=========  ============ ============ ============ ===================
node role     CPU(ea)   Memory (GB)  Disk (GB)     Extra Disks
=========  ============ ============ ============ ===================
control     8               16          50          N/A
compute     4                8          50          N/A
storage     4                8          50          3 ea x 50GB
=========  ============ ============ ============ ===================


Networks
-----------

The standard number of networks for burrito is 5.

* service network: Public service network (e.g. 192.168.20.0/24)
* management network: Management and internal network (e.g. 192.168.21.0/24)
* provider network: OpenStack provider network (e.g. 192.168.22.0/24)
* overlay network: OpenStack overlay network (e.g. 192.168.23.0/24)
* storage network: Ceph public/cluster network (e.g. 192.168.24.0/24)

If you do not know what each network is for, consult openstack experts.

Reference network architecture
++++++++++++++++++++++++++++++

This is the reference network architecture.

* control/compute machines have all 5 networks.
* No ip address is assigned on the provider network.
* storage machines have 2 networks (management and storage)

========  ============ ============ ============ ============ ============
hostname  service      management   provider     overlay      storage
--------  ------------ ------------ ------------ ------------ ------------
 .        eth0         eth1         eth2         eth3         eth4
 .        192.168.20.x 192.168.21.x 192.168.22.x 192.168.23.x 192.168.24.x 
========  ============ ============ ============ ============ ============
control1  .101          .101          (no ip)     .101           .101
control2  .102          .102          (no ip)     .102           .102
control3  .103          .103          (no ip)     .103           .103
compute1  .104          .104          (no ip)     .104           .104
compute2  .105          .105          (no ip)     .105           .105
storage1                .106                                     .106
storage2                .107                                     .107
storage3                .108                                     .108
========  ============ ============ ============ ============ ============

* KeepAlived VIP on management: 192.168.21.100
* KeepAlived VIP on service: 192.168.20.100

Pre-requisites
---------------

* OS is installed using Burrito ISO.
* The first node in control group is the ansible deployer.
* Ansible user in every node has a sudo privilege. I assume the ansible user
  is `clex` in this document.
* All nodes should be in /etc/hosts on the deployer node.

Here is the example of /etc/hosts on the deployer node.::

   127.0.0.1 localhost
   192.168.21.101 control1
   192.168.21.102 control2 
   192.168.21.103 control3 
   192.168.21.104 compute1 
   192.168.21.105 compute2 
   192.168.21.106 storage1 
   192.168.21.107 storage2 
   192.168.21.108 storage3 

Prepare
--------

Mount the iso file.::

   $ sudo mount -o loop,ro <path/to/burrito_iso_file> /mnt

Check the burrito tarball in /mnt.::

   $ ls /mnt/burrito-*.tar.gz
   /mnt/burrito-<version>.tar.gz

Untar the burrito tarball to user's home directory.::

   $ tar xzf /mnt/burrito-<version>.tar.gz

Go to burrito directory.::

   $ cd burrito-<version>

Run prepare.sh script with offline flag.::

   $ ./prepare.sh offline
   Enter management network interface name: eth1

It will prompt for the management network interface name. 
Enter the management network interface name. (e.g. eth1)

inventory hosts and variables
+++++++++++++++++++++++++++++

There are 4 groups of hosts in burrito.

* Control node: runs kubernetes and openstack control-plane components.
* Network node: runs kubernetes worker and openstack network services.
* Compute node: runs kubernetes worker and openstack hypervisor and network
  agent to operate instances.
* Storage node: runs Ceph storage services - monitor, manager, osd,
  rados gateway.

Network node is optional.
Control node usually acts as both control node and network node.

Edit inventory hosts
^^^^^^^^^^^^^^^^^^^^^

There are sample inventory files.

* hosts.sample (default):
    This is a sample file using ceph as the storage backend.
* hosts_powerflex.sample:
    This is a sample file using powerflex as the storage backend.
* hosts_powerflex_hci.sample:
    This is a sample file using powerflex HCI (Hyper-Converged Infrastructure).
* hosts_hitachi.sample:
    This is a sample file using hitachi as the storage backend.

.. warning::
    You need to get the powerflex rpm packages from Dell if you want to install
    powerflex in burrito.

.. warning::
    You need to get the hitachi container images from Hitachi if you want to 
    install HSPC (Hitachi Storage Plug-in for Containers) images in burrito.

When you run prepare.sh script, the default hosts.sample is copied to 
*hosts* file.

If you want to use powerflex storage, copy one of powerflex inventory files.::

   $ cp hosts_powerflex_hci.sample hosts

If you want to use hitachi storage, copy hitachi inventory file.::

   $ cp hosts_hitachi.sample hosts

Here are the sample inventory files.

.. collapse:: the default inventory file

   .. code-block::
      :linenos:

      control1 ip=192.168.21.101 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
      control2 ip=192.168.21.102
      control3 ip=192.168.21.103
      compute1 ip=192.168.21.104
      compute2 ip=192.168.21.105
      storage1 ip=192.168.21.106
      storage2 ip=192.168.21.107
      storage3 ip=192.168.21.108

      # ceph nodes
      [mons]
      storage[1:3]

      [mgrs]
      storage[1:3]

      [osds]
      storage[1:3]

      [rgws]
      storage[1:3]

      [clients]
      control[1:3]
      compute[1:2]

      # kubernetes nodes
      [kube_control_plane]
      control[1:3]

      [kube_node]
      control[1:3]
      compute[1:2]

      # openstack nodes
      [controller-node]
      control[1:3]

      [network-node]
      control[1:3]

      [compute-node]
      compute[1:2]

      ###################################################
      ## Do not touch below if you are not an expert!!! #
      ###################################################

.. collapse:: the powerflex inventory file

   .. code-block::
      :linenos:

      control1 ip=192.168.21.101 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
      control2 ip=192.168.21.102
      control3 ip=192.168.21.103
      compute1 ip=192.168.21.104
      compute2 ip=192.168.21.105
      storage1 ip=192.168.21.106
      storage2 ip=192.168.21.107
      storage3 ip=192.168.21.108

      # ceph nodes
      [mons]
      [mgrs]
      [osds]
      [rgws]
      [clients]

      # powerflex nodes
      [mdm]
      storage[1:3]

      [sds]
      storage[1:3]

      [sdc]
      control[1:3]
      compute[1:2]

      [gateway]
      storage[1:2]

      [presentation]
      storage3

      # kubernetes nodes
      [kube_control_plane]
      control[1:3]

      [kube_node]
      control[1:3]
      compute[1:2]

      # openstack nodes
      [controller-node]
      control[1:3]

      [network-node]
      control[1:3]

      [compute-node]
      compute[1:2]

      ###################################################
      ## Do not touch below if you are not an expert!!! #
      ###################################################

.. collapse:: the powerflex HCI inventory file

   .. code-block::
      :linenos:

      pfx-1 ip=192.168.21.131 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
      pfx-2 ip=192.168.21.132
      pfx-3 ip=192.168.21.133

      # ceph nodes
      [mons]
      [mgrs]
      [osds]
      [rgws]
      [clients]

      # powerflex nodes
      [mdm]
      pfx-[1:3]

      [sds]
      pfx-[1:3]

      [sdc]
      pfx-[1:3]

      [gateway]
      pfx-[1:2]

      [presentation]
      pfx-3

      # kubernetes nodes
      [kube_control_plane]
      pfx-[1:3]

      [kube_node]
      pfx-[1:3]

      # openstack nodes
      [controller-node]
      pfx-[1:3]

      [network-node]
      pfx-[1:3]

      [compute-node]
      pfx-[1:3]

      ###################################################
      ## Do not touch below if you are not an expert!!! #
      ###################################################

.. collapse:: the hitachi inventory file

   .. code-block::
      :linenos:

      control1 ip=192.168.21.101 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
      control2 ip=192.168.21.102
      control3 ip=192.168.21.103
      compute1 ip=192.168.21.104
      compute2 ip=192.168.21.105
      storage1 ip=192.168.21.106
      storage2 ip=192.168.21.107
      storage3 ip=192.168.21.108
      
      # ceph nodes
      [mons]
      [mgrs]
      [osds]
      [rgws]
      [clients]
      
      # kubernetes nodes
      [kube_control_plane]
      control[1:3]
      
      [kube_node]
      control[1:3]
      compute[1:2]
      
      # openstack nodes
      [controller-node]
      control[1:3]
      
      [network-node]
      control[1:3]
      
      [compute-node]
      compute[1:2]
      
      ###################################################
      ## Do not touch below if you are not an expert!!! #
      ###################################################


.. warning::
   Beware that control nodes are in network-node group since there is no
   network node in these sample files.

Edit vars.yml
^^^^^^^^^^^^^^

.. code-block:: yaml
   :linenos:

   ---
   ### define network interface names
   # set overlay_iface_name to null if you do not want to set up overlay network.
   # then, only provider network will be set up.
   svc_iface_name: eth0
   mgmt_iface_name: eth1
   provider_iface_name: eth2
   overlay_iface_name: eth3
   storage_iface_name: eth4
   
   ### ntp
   # Specify time servers for control nodes.
   # You can use the default ntp.org servers or time servers in your network.
   # If servers are offline and there is no time server in your network,
   #   set ntp_servers to empty list.
   #   Then, the control nodes will be the ntp servers for other nodes.
   # ntp_servers: []
   ntp_servers:
     - 0.pool.ntp.org
     - 1.pool.ntp.org
     - 2.pool.ntp.org
   
   ### keepalived VIP on management network (mandatory)
   keepalived_vip: ""
   # keepalived VIP on service network (optional)
   # Set this if you do not have a direct access to management network
   # so you need to access horizon dashboard through service network.
   keepalived_vip_svc: ""
   
   ### metallb
   # To use metallb LoadBalancer, set this to true
   metallb_enabled: false
   # set up MetalLB LoadBalancer IP range or cidr notation
   # IP range: 192.168.20.95-192.168.20.98 (4 IPs can be assigned.)
   # CIDR: 192.168.20.128/26 (192.168.20.128 - 191 can be assigned.)
   # Only one IP: 192.168.20.95/32
   metallb_ip_range:
     - "192.168.20.95-192.168.20.98"
   
   ### HA tuning
   # ha levels: moderato, allegro, and vivace
   # moderato: default liveness update and failover response
   # allegro: faster liveness update and failover response
   # vivace: fastest liveness update and failover response
   ha_level: "moderato"
   k8s_ha_level: "moderato"
   
   ### storage
   # storage backends: ceph and(or) netapp
   # If there are multiple backends, the first one is the default backend.
   storage_backends:
     - ceph
     - netapp
     - powerflex
     - hitachi
   
   # ceph: set ceph configuration in group_vars/all/ceph_vars.yml
   # netapp: set netapp configuration in group_vars/all/netapp_vars.yml
   # powerflex: set powerflex configuration in group_vars/all/powerflex_vars.yml
   # hitachi: set hitachi configuration in group_vars/all/hitachi_vars.yml

   ###################################################
   ## Do not edit below if you are not an expert!!!  #
   ###################################################

Description of each variable
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

\*_iface_name
  Set each network interface name.

  If you want to set up only provider network, set overlay_iface_name to null.
  Then, openstack neutron will disable self-service(overlay) network.

ntp_servers (default: {0,1,2}.pool.ntp.org)
  Specify time servers for control nodes.
  You can use the default ntp.org server or time servers in your network.

  If servers are offline and there is no time server in your network,
  set ntp_servers to empty list(ntp_servers: []). Then the control nodes
  will be the ntp servers for other nodes.

keepalived_vip (mandatory)
  Assign VIP address on management network for LoadBalancing and 
  High Availability to internal services. This is mandatory.

keepalived_vip_svc (optional)
  Assign VIP address on service network for horizon dashboard service.
  Set this if you do not have a direct access to management network.

  If it is not assigned, you have to connect to horizon dashboard via
  keepalived_vip on management network.

metallb_enabled (default: false)
  Set true to use metallb LoadBalancer.
  (See ` what is metallb? <https://metallb.universe.tf/>`_)

metallb_ip_range
  Set metallb LoadBalancer IP range or cidr notation.

  * IP range: 192.168.20.95-192.168.20.98 (4 IPs can be assigned.)
  * CIDR: 192.168.20.128/26 (192.168.20.128 - 191 can be assigned.)
  * Only one IP: 192.168.20.95/32 (192.168.20.95 can be assigned.)

ha_level
  Set KeepAlived/HAProxy HA level.
  It should be one of moderato(default), allegro, and vivace.
  Each level sets the following parameters.

  * interval: health check interval in seconds
  * timeout: health check timeout in seconds
  * rise: required number of success
  * fall: required number of failure 

k8s_ha_level
  Set kubernetes HA level.
  It should be one of moderato(default), allegro, and vivace.
  Each level sets the following parameters.

  * node_status_update_frequency: 
    Specifies how often kubelet posts node status to master.
  * node_monitor_period:
    The period for syncing NodeStatus in NodeController.
  * node_monitor_grace_period:
    Amount of time which we allow running Node to be unresponsive before
    marking it unhealthy.
  * not_ready_toleration_seconds:
    the tolerationSeconds of the toleration for notReady:NoExecute that is 
    added by default to every pod that does not already have such a toleration
  * unreachable_toleration_seconds:
    the tolerationSeconds of the toleration for unreachable:NoExecute that is
    added by default to every pod that does not already have such a toleration
  * kubelet_shutdown_grace_period:
    the total duration that the node should delay the shutdown by
  * kubelet_shutdown_grace_period_critical_pods:
    the duration used to terminate critical pods during a node shutdown

storage_backends
  Burrito supports the following storage backends -
  ceph, netapp, powerflex, and hitachi.

  If there are multiple backends, the first one is the default backend.
  It means the default storageclass, glance store and the default cinder 
  volume type is the first backend.

  The Persistent Volumes in k8s are created on the default backend
  if you do not specify the storageclass name.

  The volumes in openstack are created on the default backend
  if you do not specify the volume type.

storage variables
+++++++++++++++++

ceph
^^^^^

If ceph is in storage_backends, 
run lsblk command on storage nodes to get the device names.

.. code-block:: shell

   storage1$ lsblk -p
   NAME        MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
   /dev/sda      8:0    0  50G  0 disk 
   └─/dev/sda1   8:1    0  50G  0 part /
   /dev/sdb      8:16   0  50G  0 disk 
   /dev/sdc      8:32   0  50G  0 disk 
   /dev/sdd      8:48   0  50G  0 disk 

In this case, /dev/sda is the OS disk and /dev/sd{b,c,d} are for ceph
OSD disks.

Edit group_vars/all/ceph_vars.yml.

.. code-block::
   :linenos:

   ---
   # ceph config
   lvm_volumes:
     - data: /dev/sdb
     - data: /dev/sdc
     - data: /dev/sdd
   ...

netapp
^^^^^^^

If netapp is in storage_backends, edit group_vars/all/netapp_vars.yml.

.. code-block::
   :linenos:

   ---
   netapp:
     - name: netapp1
       managementLIF: "192.168.100.230"
       dataLIF: "192.168.140.19"
       svm: "svm01"
       username: "admin"
       password: "<netapp_admin_password>"
       nfsMountOptions: "lookupcache=pos"
       shares:
         - /dev03
   ...

You can add nfsvers in nfsMountOptions to use the specific nfs version.

For example, if you want to use nfs version 4.0, put nfsvers=4.0 in
nfsMountOptions (nfsMountOptions: "nfsvers=4.0,lookupcache=pos").
Then, you should check if nfs version 4 is enabled in NetApp NFS storage.

If you do not know what these variables are, contact a Netapp engineer.

powerflex
^^^^^^^^^^

If powerflex is in storage_backends,
run lsblk command on storage nodes to get the device names.

.. code-block::
   :linenos:

   storage1$ lsblk -p
   NAME        MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
   /dev/sda      8:0    0  50G  0 disk
   └─/dev/sda1   8:1    0  50G  0 part /
   /dev/sdb      8:16   0  50G  0 disk
   /dev/sdc      8:32   0  50G  0 disk
   /dev/sdd      8:48   0  50G  0 disk

In this case, /dev/sda is the OS disk and /dev/sd{b,c,d} are for powerflex
SDS disks.

Edit group_vars/all/powerflex_vars.yml.

.. code-block::
   :linenos:

   # MDM VIPs on storage networks
   mdm_ip:
     - "192.168.24.100"
   storage_iface_names:
     - eth4
   sds_devices:
     - /dev/sdb
     - /dev/sdc
     - /dev/sdd

   #
   # Do Not Edit below
   #

If you do not know what these variables are, contact a Dell engineer.

hitachi
^^^^^^^

Before using Hitachi Storage in Burrito,
you must manually set up Host Groups and Host Mode Options.

Please refer to the
:doc:`Hitachi Storage Manual Setup Guide <setup_hitachi_storage>`.

If hitachi is in storage_backends, edit group_vars/all/hitachi_vars.yml.

.. code-block::
   :linenos:

   ---
   # storage model: See hitachi_prefix_id below for your storage model
   hitachi_storage_model: vsp_e990
   
   ## k8s storageclass variables
   # Get hitachi storage serial number
   hitachi_serial_number: "<serial_number>"
   hitachi_pool_id: "0"
   # port_id to be used by k8s PV
   hitachi_port_id: "CL4-A"
   
   ## openstack cinder variables
   hitachi_san_ip: "<san_ip>"
   hitachi_san_login: "<san_login>"
   hitachi_san_password: "<san_password>"
   hitachi_ldev_range: "00:10:00-00:10:FF"
   hitachi_target_ports: "CL3-A"
   hitachi_compute_target_ports: "CL1-A,CL2-A,CL3-A,CL5-A,CL6-A"
   
   ########################
   # Do Not Edit below!!! #
   ########################

Contact a Hitachi engineer to get the information of the storage.

* hitachi_storage_model: Enter one of hitachi_prefix_id variable values.
* hitachi_serial_number: the 6-digit serial number
* hitachi_pool_id: Hitachi storage pool id
* hitachi_port_id: Port id for Kubernetes
* hitachi_san_ip: IP address of Hitachi controller
* hitachi_san_login: Username for Hitachi controller
* hitachi_san_password: Password for Hitachi controller
* hitachi_ldev_range: Range of the LDEV numbers in the format of 
  ‘aa:bb:cc-dd:ee:ff’ that can be used by the cinder driver.
* hitachi_target_ports: IDs of the storage ports used to attach volumes 
  to the control nodes
* hitachi_compute_target_ports: IDs of the storage ports used to attach 
  volumes to control and compute nodes

Create a vault secret file
+++++++++++++++++++++++++++

Create a vault file to encrypt passwords.::

   $ ./run.sh vault
   <user> password:
   openstack admin password:
   Encryption successful

Enter <user> password for ssh connection to other nodes.

Enter openstack admin password which will be used when you connect to 
openstack horizon dashboard.

Check the connectivity
++++++++++++++++++++++

Check the connections to other nodes.::

   $ ./run.sh ping

It should show SUCCESS on all nodes.

Install
--------

There should be no *failed* tasks in *PLAY RECAP* on each playbook run.

For example::

   PLAY RECAP *****************************************************************
   control1                   : ok=20   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
   control2                   : ok=19   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
   control3                   : ok=19   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

Each step has a verification process, so be sure to verify 
before proceeding to the next step. 

.. warning::
   **Never proceed to the next step if the verification fails.**

Step.1 Preflight
+++++++++++++++++

The Preflight installation step implements the following tasks.

* Set up a local yum repository.
* Configure NTP time servers and clients.
* Deploy the public ssh key to other nodes (if deploy_ssh_key is true).

Install
^^^^^^^

Run a preflight playbook.::

   $ ./run.sh preflight

Verify
^^^^^^

Check if the local yum repository is set up on all nodes.::

   $ sudo dnf repolist
   repo id                               repo name
   burrito                               Burrito Repo

Check if the ntp servers and clients are configured.

When you set ntp_servers to empty list (ntp_servers: []),
each control node should have other control nodes as time servers.::

   control1$ chronyc sources
   MS Name/IP address      Stratum Poll Reach LastRx Last sample               
   ========================================================================
   ^? control2             9   6   377   491   +397ms[ +397ms] +/-  382us
   ^? control3             9   6   377   490   -409ms[ -409ms] +/-  215us

Compute/storage nodes should have control nodes as time servers.::

   $ chronyc sources
   MS Name/IP address      Stratum Poll Reach LastRx Last sample               
   ========================================================================
   ^* control1             8   6   377    46    -15us[  -44us] +/-  212us
   ^- control2             9   6   377    47    -57us[  -86us] +/-  513us
   ^- control3             9   6   377    47    -97us[ -126us] +/-  674us

Step.2 HA 
++++++++++

The HA installation step implements the following tasks.

* Set up KeepAlived service.
* Set up HAProxy service.

KeepAlived and HAProxy services are the vital services for burrito platform.

The local container registry, local yum repository,
Ceph Rados Gateway services are dependent of them.

Install
^^^^^^^

Run a HA stack playbook.::

   $ ./run.sh ha

Verify
^^^^^^

Check if keepalived and haproxy are running on control nodes.::

   $ sudo systemctl status keepalived haproxy
   keepalived.service - LVS and VRRP High Availability Monitor
   ...
      Active: active (running) since Wed 2023-05-31 17:29:05 KST; 6min ago
   ...
   haproxy.service - HAProxy Load Balancer
   ...
      Active: active (running) since Wed 2023-05-31 17:28:52 KST; 8min ago

Check if keepalived_vip is created on the management interface 
in the first control node.::

   $ ip -br -4 address show dev eth1
   eth1             UP             192.168.21.101/24 192.168.21.100/32 

Check if keepalived_vip_svc is created on the service interface 
in the first control node if you set it up.::

   $ ip -br -4 address show dev eth0
   eth0             UP             192.168.20.101/24 192.168.20.100/32 

Step.3 Ceph
+++++++++++

Skip this step if ceph is **not** in storage_backends.

The Ceph installation step implements the following tasks.

* Install ceph server and client packages in storage nodes.
* Install ceph client packages in other nodes.
* Set up ceph monitor, manager, osd, rados gateway services on storage nodes.

Install
^^^^^^^

Run a ceph playbook if ceph is in storage_backends.::

   $ ./run.sh ceph

Verify
^^^^^^

Check ceph health after running ceph playbook.::

   $ sudo ceph health
   HEALTH_OK

It should show HEALTH_OK.

To get the detailed health status, run `sudo ceph -s` command.
It will show the output like this.::

   $ sudo ceph -s
     cluster:
       id:     cd7bdd5a-1814-4e6a-9e07-c2bdc3f53fea
       health: HEALTH_OK
    
     services:
       mon: 3 daemons, quorum storage1,storage2,storage3 (age 17h)
       mgr: storage2(active, since 17h), standbys: storage1, storage3
       osd: 9 osds: 9 up (since 17h), 9 in (since 17h)
       rgw: 3 daemons active (3 hosts, 1 zones)
    
     data:
       pools:   10 pools, 513 pgs
       objects: 2.54k objects, 7.3 GiB
       usage:   19 GiB used, 431 GiB / 450 GiB avail
       pgs:     513 active+clean

There are 4 services - mon, mgr, osd, and rgw.

Sometimes it could show `HEALTH_WARN <something> have recently crashed`.
Don't worry. it is mostly harmless warning.

List the crashes.::

   $ sudo ceph crash ls

Archive all crashes.::

   $ sudo ceph crash archive-all

Then, check ceph health again. It will show HEALTH_OK now.

Step.4 Kubernetes
+++++++++++++++++

The Kubernetes installation step implements the following tasks.

* Install kubernetes binaries in kubernetes nodes.
* Set up kubernetes control plane.
* Set up kubernete worker nodes.
* Set up the local registry in kube-system namespace.

Install
^^^^^^^

Run a k8s playbook.::

   $ ./run.sh k8s

Verify
^^^^^^

Check all nodes are in ready state.::

   $ sudo kubectl get nodes
   NAME       STATUS   ROLES           AGE   VERSION
   compute1   Ready    <none>          15m   v1.28.3
   compute2   Ready    <none>          15m   v1.28.3
   control1   Ready    control-plane   17m   v1.28.3
   control2   Ready    control-plane   16m   v1.28.3
   control3   Ready    control-plane   16m   v1.28.3


Step.5.1 Netapp
++++++++++++++++

Skip this step if netapp is **not** in storage_backends.

The Netapp installation step implements the following tasks.

* Install trident components in trident namespace.
* Set up a netapp backend.
* Create a netapp storageclass.

Install
^^^^^^^

Run a netapp playbook.::

   $ ./run.sh netapp

Verify
^^^^^^

Check if all pods are running and ready in trident namespace.::

   $ sudo kubectl get pods -n trident
   NAME                           READY   STATUS    RESTARTS   AGE
   trident-csi-6b96bb4f87-tw22r   6/6     Running   0          43s
   trident-csi-84g2x              2/2     Running   0          42s
   trident-csi-f6m8w              2/2     Running   0          42s
   trident-csi-klj7h              2/2     Running   0          42s
   trident-csi-kv9mw              2/2     Running   0          42s
   trident-csi-r8gqv              2/2     Running   0          43s

Check if netapp storageclass is created.::

   $ sudo kubectl get storageclass netapp
   NAME               PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
   netapp (default)   csi.trident.netapp.io   Delete          Immediate           true                   20h

Step.5.2 Powerflex
+++++++++++++++++++

Skip this step if powerflex is **not** in storage_backends.

The powerflex installation step implements the following tasks.

* Install powerflex rpm packages.
* Create powerflex MDM cluster.
* Configure gateway and presentation services.
* Set up Protection Domain, Storage Pool, and SDS devices.
* Install vxflexos controller and node in vxflexos namespace.
* Create a powerflex storageclass.

Install
^^^^^^^

Run a powerflex playbook.::

   $ ./run.sh powerflex

Verify
^^^^^^

Check if all pods are running and ready in vxflexos namespace.::

   $ sudo kubectl get pods -n vxflexos
   NAME                                   READY   STATUS    RESTARTS   AGE
   vxflexos-controller-744989794d-92bvf   5/5     Running   0          18h
   vxflexos-controller-744989794d-gblz2   5/5     Running   0          18h
   vxflexos-node-dh55h                    2/2     Running   0          18h
   vxflexos-node-k7kpb                    2/2     Running   0          18h
   vxflexos-node-tk7hd                    2/2     Running   0          18h

Check if powerflex storageclass is created.::

   $ sudo kubectl get storageclass powerflex
   NAME                  PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
   powerflex (default)   csi-vxflexos.dellemc.com   Delete          WaitForFirstConsumer   true                   20h

Step.5.3 Hitachi
+++++++++++++++++

Skip this step if hitachi is **not** in storage_backends.

The Hitachi installation step implements the following tasks.

* Install Hitachi Storage Plug-in for Containers (HSPC) in hspc-operator-system namespace.
* Create a hitachi storageclass.

Install
^^^^^^^

Run a hitachi playbook.::

   $ ./run.sh hitachi

Verify
^^^^^^

Check if all pods are running and ready in hspc-operator-system namespace.::

   $ sudo kubectl get pods -n hspc-operator-system
   NAME                                                READY   STATUS    RESTARTS        AGE
   hspc-csi-controller-7c4cbdccbc-sh7lz                6/6     Running   0               40s
   hspc-csi-node-2snpm                                 2/2     Running   0               42s
   hspc-csi-node-2t897                                 2/2     Running   0               42s
   hspc-csi-node-xd78f                                 2/2     Running   0               42s
   hspc-operator-controller-manager-599b69557b-6v9k7   1/1     Running   0               35s

Check if hitachi storageclass is created.::

   $ sudo kubectl get storageclass hitachi
   NAME                PROVISIONER            RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
   hitachi (default)   hspc.csi.hitachi.com   Delete          Immediate           true                   30s

Step.6 Patch
+++++++++++++

The Patch installation step implements the following tasks.

* Install ceph-csi driver if ceph is in storage_backends.
* Patch kube-apiserver.

Install
^^^^^^^

Run a patch playbook.::

   $ ./run.sh patch

Verify
^^^^^^

It will take some time to restart kube-apiserver after the patch.

Check if all pods are running and ready in kube-system namespace.

.. collapse:: pod list in kube-system namespace

   .. code-block:: shell

      $ sudo kubectl get pods -n kube-system
      NAME                                       READY STATUS    RESTARTS      AGE
      calico-kube-controllers-67c66cdbfb-rz8lz   1/1   Running   0             60m
      calico-node-28k2c                          1/1   Running   0             60m
      calico-node-7cj6z                          1/1   Running   0             60m
      calico-node-99s5j                          1/1   Running   0             60m
      calico-node-tnmht                          1/1   Running   0             60m
      calico-node-zmpxs                          1/1   Running   0             60m
      coredns-748d85fb6d-c8cj2                   1/1   Running   1 (28s ago)   59m
      coredns-748d85fb6d-gfv98                   1/1   Running   1 (27s ago)   59m
      dns-autoscaler-795478c785-hrjqr            1/1   Running   1 (32s ago)   59m
      kube-apiserver-control1                    1/1   Running   0             33s
      kube-apiserver-control2                    1/1   Running   0             34s
      kube-apiserver-control3                    1/1   Running   0             35s
      kube-controller-manager-control1           1/1   Running   1             62m
      kube-controller-manager-control2           1/1   Running   1             62m
      kube-controller-manager-control3           1/1   Running   1             62m
      kube-proxy-jjq5l                           1/1   Running   0             61m
      kube-proxy-k4kxq                           1/1   Running   0             61m
      kube-proxy-lqtgc                           1/1   Running   0             61m
      kube-proxy-qhdzh                           1/1   Running   0             61m
      kube-proxy-vxrg8                           1/1   Running   0             61m
      kube-scheduler-control1                    1/1   Running   2             62m
      kube-scheduler-control2                    1/1   Running   1             62m
      kube-scheduler-control3                    1/1   Running   1             62m
      nginx-proxy-compute1                       1/1   Running   0             60m
      nginx-proxy-compute2                       1/1   Running   0             60m
      nodelocaldns-5dbbw                         1/1   Running   0             59m
      nodelocaldns-cq2sd                         1/1   Running   0             59m
      nodelocaldns-dzcjr                         1/1   Running   0             59m
      nodelocaldns-plhwm                         1/1   Running   0             59m
      nodelocaldns-vlb8w                         1/1   Running   0             59m
      registry-5v9th                             1/1   Running   0             58m

Wait until the registry pod is running and ready.


Step.7 Registry
+++++++++++++++

The Registry installation step implements the following tasks.

* Get the registry pod name.
* Copy container images from ISO to the registry pod.

Install
^^^^^^^

Run a registry playbook.::

   $ ./run.sh registry

Verify
^^^^^^

Check the images are in the local registry.::

   $ curl -s <keepalived_vip>:32680/v2/_catalog | jq
   {
       "repositories": [
           "airshipit/kubernetes-entrypoint",
           "calico/cni",
           "calico/kube-controllers",
           ...
           "sig-storage/csi-resizer",
           "sig-storage/csi-snapshotter"
       ]
   }

Repositories in output should not be empty.

Step.8 Landing
+++++++++++++++

The Landing installation step implements the following tasks.

* Deploy the genesis registry service on control nodes.
* Patch bootstrap pods (kube-{apiserver,scheduler,controller-manager},
  kube-proxy, local registry, and csi driver pods) to change image url to 
  genesis registry.
* Deploy the local yum repository pod in burrito namespace.
* Register the registry and repository service in haproxy.
* Install Graceful Node Shutdown Helper (GNSH).

Install
^^^^^^^

Run landing playbook.::

   $ ./run.sh landing

Verify
^^^^^^

Check if the genesis registry service is running on control nodes.::

   $ sudo systemctl status genesis_registry.service gnsh.service
   genesis_registry.service - Geneis Registry service
   ...
    Active: active (running) since Fri 2023-09-22 14:39:41 KST; 3min 13s ago
   ...
   gnsh.service - Graceful Node Shutdown Helper
   ...
     Active: active (exited) since Fri 2023-09-22 14:42:36 KST; 19s ago

Check if the local repository pod is running and ready 
in kube-system namespace.::

   $ sudo kubectl get pods -n kube-system
   NAME                        READY   STATUS    RESTARTS   AGE
   ...
   localrepo-c4bc5b89d-nbtq9   1/1     Running   0          3m38s

Check if the Graceful Node Shutdown Helper (GNSH) service is running.::

   $ sudo systemctl status gnsh.service
    gnsh.service - Graceful Node Shutdown Helper
      Loaded: loaded (/etc/systemd/system/gnsh.service; enabled; vendor preset: di>
      Active: active (exited) since Tue 2023-11-07 13:58:34 KST; 25min ago
     Process: 435851 ExecStart=/usr/bin/gnsh start (code=exited, status=0/SUCCESS)
    Main PID: 435851 (code=exited, status=0/SUCCESS)
       Tasks: 0 (limit: 100633)
      Memory: 0B
      CGroup: /system.slice/gnsh.service
   
   Nov 07 13:58:34 control1 systemd[1]: Starting Graceful Node Shutdown Helper...
   Nov 07 13:58:34 control1 gnsh[435851]: Uncordon my node control1.
   Nov 07 13:58:34 control1 gnsh[435853]: node/control1 already uncordoned
   Nov 07 13:58:34 control1 systemd[1]: Started Graceful Node Shutdown Helper.


Congratulations! 

You've just finished the installation of burrito kubernetes platform.

Next you will install OpenStack on burrito kubernetes platform.

Step.9 Burrito
+++++++++++++++++

The burrito installation step implements the following tasks.

* Create a rados gateway user (default: cloudpc) and 
  a client configuration (s3cfg).
* Deploy nova vnc TLS certificate.
* Deploy OpenStack components.
* Create a nova ssh keypair and copy them on every compute nodes.

Install
^^^^^^^

Run a burrito playbook.::

   $ ./run.sh burrito

Verify
^^^^^^

Check all pods are running and ready in openstack namespace.::

   $ sudo kubectl get pods -n openstack
   NAME                                   READY   STATUS      RESTARTS   AGE
   barbican-api-664986fd5-jkp9x           1/1     Running     0          4m23s
   ...
   rabbitmq-rabbitmq-0                    1/1     Running     0          27m
   rabbitmq-rabbitmq-1                    1/1     Running     0          27m
   rabbitmq-rabbitmq-2                    1/1     Running     0          27m

Congratulations!

You've just finished the OpenStack installation on burrito kubernetes platform.

Horizon
----------

The horizon dashboard listens on tcp 31000 on control nodes.

Here is how to connect to the horizon dashboard on your browser.

#. Open your browser.

#. If keepalived_vip_svc is set,
   go to https://<keepalived_vip_svc>:31000/

#. If keepalived_vip_svc is not set,
   go to https://<keepalived_vip>:31000/

#. Accept the self-signed TLS certificate and log in.
   The admin password is the one you set when you run vault.sh script
   (openstack admin password:).

Next, perform the basic openstack operation test using btx (burrito toolbox).

BTX
---

BTX is a toolbox for burrito platform.
It should be already up and running.::

   $ sudo kubectl -n openstack get pods -l application=btx
   NAME    READY   STATUS    RESTARTS   AGE
   btx-0   1/1     Running   0          36m

Let's go into btx shell (bts).::

   $ . ~/.btx.env
   $ bts

Check openstack volume service status.::

   root@btx-0:/# openstack volume service list
   +------------------+------------------------------+------+---------+-------+----------------------------+
   | Binary           | Host                         | Zone | Status  | State | Updated At                 |
   +------------------+------------------------------+------+---------+-------+----------------------------+
   | cinder-scheduler | cinder-volume-worker         | nova | enabled | up    | 2023-05-31T12:05:02.000000 |
   | cinder-volume    | cinder-volume-worker@rbd1    | nova | enabled | up    | 2023-05-31T12:05:02.000000 |
   | cinder-volume    | cinder-volume-worker@netapp1 | nova | enabled | up    | 2023-05-31T12:05:07.000000 |
   +------------------+------------------------------+------+---------+-------+----------------------------+

Here is the example of the volume service status of hitachi storage backend.::

   root@btx-0:/# o volume service list
   +------------------+------------------------------+------+---------+-------+----------------------------+
   | Binary           | Host                         | Zone | Status  | State | Updated At                 |
   +------------------+------------------------------+------+---------+-------+----------------------------+
   | cinder-scheduler | cinder-volume-worker         | nova | enabled | up    | 2023-12-12T07:46:59.000000 |
   | cinder-volume    | cinder-volume-worker@hitachi | nova | enabled | up    | 2023-12-12T07:46:56.000000 |
   +------------------+------------------------------+------+---------+-------+----------------------------+

* All services should be `enabled` and `up`.
* If you set up both ceph and netapp storage backends, 
  both volume services are enabled and up in the output.
* The cinder-volume-worker@rbd1 is the service for ceph backend
  and the cinder-volume-worker@netapp1 is the service for Netapp backend.
* The cinder-volumeworker@powerflex is the service for Dell powerflex backend.
* The cinder-volumeworker@hitachi is the service for Hitachi backend.

Check openstack network agent status.::

   root@btx-0:/# openstack network agent list
   +--------------------------------------+--------------------+----------+-------------------+-------+-------+---------------------------+
   | ID                                   | Agent Type         | Host     | Availability Zone | Alive | State | Binary                    |
   +--------------------------------------+--------------------+----------+-------------------+-------+-------+---------------------------+
   | 0b4ddf14-d593-44bb-a0aa-2776dfc20dc9 | Metadata agent     | control1 | None              | :-)   | UP    | neutron-metadata-agent    |
   | 189c6f4a-4fad-4962-8439-0daf400fcae0 | DHCP agent         | control3 | nova              | :-)   | UP    | neutron-dhcp-agent        |
   | 22b0d873-4192-41ad-831b-0d468fa2e411 | Metadata agent     | control3 | None              | :-)   | UP    | neutron-metadata-agent    |
   | 4e51b0a0-e38a-402e-bbbd-5b759130220f | Linux bridge agent | compute1 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | 56e43554-47bc-45c8-8c46-fb2aa0557cc0 | DHCP agent         | control1 | nova              | :-)   | UP    | neutron-dhcp-agent        |
   | 7f51c2b7-b9e3-4218-9c7b-94076d2b162a | Linux bridge agent | compute2 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | 95d09bfd-0d71-40d4-a5c2-d46eb640e967 | DHCP agent         | control2 | nova              | :-)   | UP    | neutron-dhcp-agent        |
   | b76707f2-f13c-4f68-b769-fab8043621c7 | Linux bridge agent | control3 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | c3a6a32c-cbb5-406c-9b2f-de3734234c46 | Linux bridge agent | control1 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | c7187dc2-eea3-4fb6-a3f6-1919b82ced5b | Linux bridge agent | control2 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | f0a396d3-8200-41c3-9057-5d609204be3f | Metadata agent     | control2 | None              | :-)   | UP    | neutron-metadata-agent    |
   +--------------------------------------+--------------------+----------+-------------------+-------+-------+---------------------------+

* All agents should be :-) and UP.
* If you set overlay_iface_name to null, there is no 'L3 agent' in Agent Type
  column.
* If you set is_ovs to false, there should be 'Linux bridge agent' in Agent
  Type column.
* If you set is_ovs to true, there should be 'Open vSwitch agent' in Agent
  Type column.


Check openstack compute service status.::

   root@btx-0:/# openstack compute service list
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+
   | ID                                   | Binary         | Host                            | Zone     | Status  | State | Updated At                 |
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+
   | b31c814b-d210-4e52-9d6e-59090f8a641a | nova-scheduler | nova-scheduler-5bcc764f79-wkfgl | internal | enabled | up    | 2023-05-31T12:16:20.000000 |
   | 872555ad-dd52-46ce-be01-1ec7f8af9cd9 | nova-conductor | nova-conductor-56dfd9749-fn9xb  | internal | enabled | up    | 2023-05-31T12:16:21.000000 |
   | ff3710b8-f110-4949-b578-b09a1dbc19bb | nova-scheduler | nova-scheduler-5bcc764f79-5hcvx | internal | enabled | up    | 2023-05-31T12:16:21.000000 |
   | d6831741-677e-471f-a019-66b46150cbcc | nova-scheduler | nova-scheduler-5bcc764f79-sfclc | internal | enabled | up    | 2023-05-31T12:16:20.000000 |
   | 792ec442-5e04-4a5f-9646-7cb0001dfb9c | nova-conductor | nova-conductor-56dfd9749-s5c6j  | internal | enabled | up    | 2023-05-31T12:16:21.000000 |
   | 848f1573-3706-49ab-8c57-d6edf1631dce | nova-conductor | nova-conductor-56dfd9749-dfkgd  | internal | enabled | up    | 2023-05-31T12:16:21.000000 |
   | c5217922-bc1d-446e-a951-a4871d6020e3 | nova-compute   | compute2                        | nova     | enabled | up    | 2023-05-31T12:16:25.000000 |
   | 5f8cbde0-3c5f-404c-b31e-da443c1f14fd | nova-compute   | compute1                        | nova     | enabled | up    | 2023-05-31T12:16:25.000000 |
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+

* All services should be `enabled` and `up`.
* Each compute node should have nova-compute service.

Test
++++

The command "btx --test"

* Creates a provider network and subnet.
  When it creates a provider network, it will ask for an address pool range.
* Creates a cirros image.
* Adds security group rules.
* Creates a flavor.
* Creates an instance.
* Creates a volume.
* Attaches a volume to an instance.

If everything goes well, the output looks like this.::

   $ btx --test
   ...
   Creating provider network...
   Type the provider network address (e.g. 192.168.22.0/24): 192.168.22.0/24
   Okay. I got the provider network address: 192.168.22.0/24
   The first IP address to allocate (e.g. 192.168.22.100): 192.168.22.100
   Okay. I got the first address in the pool: 192.168.22.100
   The last IP address to allocate (e.g. 192.168.22.200): 192.168.22.108
   Okay. I got the last address of provider network pool: 192.168.22.108
   ...
   Instance status
   +------------------+------------------------------------------------------------------------------------+
   | Field            | Value                                                                              |
   +------------------+------------------------------------------------------------------------------------+
   | addresses        | public-net=192.168.22.104                                                          |
   | flavor           | disk='1', ephemeral='0', , original_name='m1.tiny', ram='512', swap='0', vcpus='1' |
   | image            | cirros (0b2787c1-fdb3-4a3c-ba9d-80208346a85c)                                      |
   | name             | test                                                                               |
   | status           | ACTIVE                                                                             |
   | volumes_attached | delete_on_termination='False', id='76edcae9-4b17-4081-8a23-26e4ad13787f'           |
   +------------------+------------------------------------------------------------------------------------+

Connect to the instance via provider network ip using ssh on the machine that 
has a provider network access.::

   (a node on provider network)$ ssh cirros@192.168.22.104
   cirros@192.168.22.104's password:
   $ ip address show dev eth0
   2: eth0:<BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast qlen 1000
       link/ether fa:16:3e:ed:bc:7b brd ff:ff:ff:ff:ff:ff
       inet 192.168.22.104/24 brd 192.168.22.255 scope global eth0
          valid_lft forever preferred_lft forever
       inet6 fe80::f816:3eff:feed:bc7b/64 scope link
          valid_lft forever preferred_lft forever

Password is the default cirros password.
(hint: password seems to be created by someone who loves Chicago Cubs
baseball team.)

