OpenStack HA test
=================

This is a test to see how long openstack services are unavailable when
non-graceful control node shutdown occurrs.

The openstack API service test is done by
`cocina <https://github.com/iorchard/cocina>`_

Test environment
-----------------

* jijisa-dev: OpenStack client machine that runs cocina
* Burrito cluster

    - control1,2,3: 3 control nodes
    - compute1,2: 2 compute nodes
    - storage1,2,3: 3 ceph storage nodes

All machines are virtual machines based on KVM/libvirt.

Test procedures
---------------

* Procedure for powering off one of control node non-gracefully.

    * Run cocina os_probe.sh on the jijisa-dev machine.
      (All openstack API service queries should succeed.)
    * Destroy one of control nodes using *virsh destroy* command.
      (All or partial openstack API service queries will fail.)
    * Wait for all openstack API services to succeed.
    * Wait until all pods in openstack namespace are running and ready.
    * Try creating volumes and instances to verify that they are created
      successfully.

* Procedure for starting the powered-off control node

    * Run cocina os_probe.sh on the jijisa-dev machine.
      (All openstack API service queries should succeed.)
    * Start the powered-off control node using *virsh start* command.
    * Wait until all pods in openstack namespace are running and ready.
      (The rabbitmq/mariadb pods will be moved to the recovered node.)
    * Try creating volumes and instances to verify that they are created
      successfully.

Test results
-------------

control3
+++++++++

non-graceful poweroff of control3
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Power off control3 using virsh destroy.::

    $ date && virsh destroy control3
    Tue 19 Mar 2024 08:27:18 PM KST
    Domain control3 destroyed

.. note::
   The registry pod is moved from control3 to control1 by Asklepios.
   
   The rabbitmq-2 pod is moved from control3 to control2 by Asklepios.

OpenStack API service probe log::

    $ grep FAIL output/control3_destroy1.log
          NOVA       2024-03-19T20:27:18     FAIL(000)
     PLACEMENT       2024-03-19T20:27:20     FAIL(000)
        GLANCE       2024-03-19T20:27:22     FAIL(000)
    ...
         NOVA        2024-03-19T20:32:16     FAIL(503)
          NOVA       2024-03-19T20:32:18     FAIL(503)
          NOVA       2024-03-19T20:32:20     FAIL(503)
    
    api total down time: 5m 2s

Instance creation test.::

    vm2: 2024-03-19T11:35:21Z -> ACTIVE
    vm3: 2024-03-19T11:36:42Z -> ACTIVE
    vm4: 2024-03-19T11:37:42Z -> ACTIVE
    vm5: 2024-03-19T11:39:29Z -> ACTIVE

Start control3
^^^^^^^^^^^^^^^

Start control3 using *virsh start* command.::

    $ date && virsh start control3
    Tue 19 Mar 2024 08:42:11 PM KST
    Domain control3 started

.. note::
   The rabbitmq-2 pod is moved from control2 to control3 by descheduler.

OpenStack API service probe log::

    $ grep FAIL output/control3_start_after_destroy1.log
     PLACEMENT       2024-03-19T20:46:24     FAIL(500)
       NEUTRON       2024-03-19T20:46:27     FAIL(000)

Instance creation test.::

    vm2: 2024-03-19T11:49:52Z -> ACTIVE
    vm3: 2024-03-19T11:50:43Z -> ACTIVE
    vm4: 2024-03-19T11:51:23Z -> ACTIVE
    vm5: 2024-03-19T14:02:22Z -> ACTIVE

control2
+++++++++

non-graceful poweroff of control2
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Power off control2 using virsh destroy.::

    $ date && virsh destroy control2
    Tue 19 Mar 2024 11:07:48 PM KST
    Domain control2 destroyed

.. note::
   The rabbitmq-1 pod is moved from control2 to control3 by Asklepios.

OpenStack API service probe log::

    $ grep FAIL output/control2_destroy1.log
          NOVA       2024-03-19T23:07:50     FAIL(000)
     PLACEMENT       2024-03-19T23:07:51     FAIL(000)
        GLANCE       2024-03-19T23:07:52     FAIL(000)
    ...
          NOVA	 2024-03-19T23:09:31	 FAIL(503)
          NOVA	 2024-03-19T23:09:34	 FAIL(503)
          NOVA	 2024-03-19T23:09:36	 FAIL(503)

api total down time: 1m 46s

Instance creation test.::

    vm3: 2024-03-19T14:14:39Z -> ACTIVE
    vm2: 2024-03-19T14:16:17Z -> ACTIVE
    vm4: 2024-03-19T14:17:13Z -> ACTIVE

Start control2
^^^^^^^^^^^^^^^

Start control2 using *virsh start* command.::

    $ date && virsh start control2
    Tue 19 Mar 2024 11:19:09 PM KST
    Domain control2 started

.. note::
   The rabbitmq-1 pod is moved from control3 to control2 by descheduler.

OpenStack API service probe log::

    $ grep FAIL output/control2_start_after_destroy1.log
       NEUTRON   2024-03-19T23:21:10     FAIL(000)
       NEUTRON   2024-03-19T23:21:15     FAIL(000)

Instance creation test.::

    vm2: 2024-03-19T14:24:15Z -> ACTIVE
    vm3: 2024-03-19T14:25:02Z -> ACTIVE
    vm4: 2024-03-19T14:25:55Z -> ACTIVE

control1
+++++++++

non-graceful poweroff of control1
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Power off control1 using virsh destroy.::

    $ date && virsh destroy control1
    Tue 19 Mar 2024 11:29:09 PM KST
    Domain control1 destroyed

.. note::
   The registry pod is moved from control1 to control2 by Asklepios.

   The rabbitmq-0 pod is moved from control1 to control2 by Asklepios.

OpenStack API service probe log::

    $ grep FAIL output/control1_destroy1.log
          NOVA   2024-03-19T23:29:10     FAIL(000)
     PLACEMENT   2024-03-19T23:29:12     FAIL(000)
        GLANCE   2024-03-19T23:29:13     FAIL(000)
    ...
          NOVA   2024-03-19T23:33:57     FAIL(503)
          NOVA   2024-03-19T23:33:59     FAIL(503)
          NOVA   2024-03-19T23:34:03     FAIL(000)

api total down time: 4m 53s

Instance creation test.::

    vm2: 2024-03-19T14:36:30Z -> ACTIVE
    vm3: 2024-03-19T14:37:40Z -> ACTIVE
    vm4: 2024-03-19T14:38:38Z -> ACTIVE

Start control1
^^^^^^^^^^^^^^^

Start control1 using *virsh start* command.::

    $ date && virsh start control1
    Tue 19 Mar 2024 11:42:57 PM KST
    Domain control1 started

.. note::
   The rabbitmq-0 pod is moved from control2 to control1 by descheduler.

OpenStack API service probe log::

    $ grep FAIL output/control1_start_after_destroy1.log
        CINDER   2024-03-19T23:47:02     FAIL(500)
          NOVA   2024-03-19T23:47:06     FAIL(000)
        CINDER   2024-03-19T23:47:08     FAIL(000)

Instance creation test.::

    vm2: 2024-03-19T14:50:01Z -> ACTIVE
    vm3: 2024-03-19T14:51:28Z -> ACTIVE
    vm4: 2024-03-19T14:55:37Z -> ACTIVE

Summary
--------

+---------+----------+--------------------------+
|Nodename |   Action |  OpenStack API down time |
+=========+==========+==========================+
|control3 | Poweroff |   5m 2s                  |
+         +----------+--------------------------+
|         |   Start  |     Negligible           |
+---------+----------+--------------------------+
|control2 | Poweroff |   1m 46s                 |
+         +----------+--------------------------+
|         |   Start  |     Negligible           |
+---------+----------+--------------------------+
|control1 | Poweroff |   4m 53s                 |
+         +----------+--------------------------+
|         |   Start  |     Negligible           |
+---------+----------+--------------------------+


