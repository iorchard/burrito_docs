Hitachi Storage Setup Guide
===========================

Overview
---------

The Burrito platform services OpenStack in a Kubernetes environment.

This document provides manual setup instructions for using Hitachi Storage as a storage backend on the Burrito platform.

The reference model is the Hitachi VSP E990.

The Burrito platform services OpenStack in a Kubernetes environment.

You need to set up Hitachi Storage Plug-in for Containers (HSPC) for
Kubernetes Persistent Volume service and Hitachi Block Storage Driver (HBSD)
for OpenStack Cinder Volume service.

Host Group Naming Rules
------------------------

Host groups can be created automatically or manually, but the automatic host
group setting method cannot be used due to the different host group naming 
rules defined by HSPC and HBSD.

HSPC's Host Group naming rule is **spc-<wwn1>-<wwn2>-<wwn3>**.

* Sort each WWN in ascending order and use the first three WWNs.
* If the host has two HBA ports, the Host Group name rule would be 
  spc-<wwn1>-<wwn2>.
* If the host has more than three HBA ports, the Host Group name is still
  spc-<wwn1>-<wwn2>-<wwn3>.

The Host Group naming rule for HBSD is **HBSD-<wwn>**.

* If there are multiple HBA ports, sort each wwn in ascending order and
  use the first wwn.

Preparation
------------

Fill in the WWN and Host Name information for each host in the following
table with the help of a Hitachi engineer.

Example) Assume there are 2 HBA ports for each node.

=====  ================  ===========    ======================================
Port    HBA WWN          Host Name      Host Group
=====  ================  ===========    ======================================
CL3-A  51402ec0181c5148   control-1     
CL4-A  51402ec0181c514a   control-1     
CL2-A  51402ec0181c5158   compute-1     
CL1-A  51402ec0181c515a   compute-1     
CL5-A  51402ec0181c50a8   compute-2     
CL6-A  51402ec0181c50aa   compute-2     
=====  ================  ===========    ======================================

* Port: The port name of the Hitachi Storage
* HBA WWN: HBA WWN of the node

Now, enter the Host Group name for manual configuration in the table below according to the rules.

In Burrito, only the control node uses Kubernetes PV, so the first WWN of 
the control node is mapped to Host Group name HBSD-<wwn1> for OpenStack, and 
the second WWN is mapped to Host Group name spc-<wwn1>-<wwn2> for Kubernetes.

The Compute node does not use Kubernetes PV, so all HBA WWNs are mapped to
Host Group name HBSD-<wwn1> for OpenStack.

=====  ================  ===========    ======================================
Port    HBA WWN          Host Name      Host Group
=====  ================  ===========    ======================================
CL3-A  51402ec0181c5148   control-1     HBSD-51402ec0181c5148
CL4-A  51402ec0181c514a   control-1     spc-51402ec0181c5148-51402ec0181c514a
CL2-A  51402ec0181c5158   compute-1     HBSD-51402ec0181c5158
CL1-A  51402ec0181c515a   compute-1     HBSD-51402ec0181c5158
CL5-A  51402ec0181c50a8   compute-2     HBSD-51402ec0181c50a8
CL6-A  51402ec0181c50aa   compute-2     HBSD-51402ec0181c50a8
=====  ================  ===========    ======================================


Manual Host Group Setup
------------------------

Based on the table above, create and set up a manual Host Group in the 
Hitachi Virtual Storage Platform (VSP) UI.

Connect to Hitachi VSP. (Contact a Hitachi engineer for access instructions)

Click "Ports/Host Groups/iSCSI Targets" in the left 
Explorer -> Storage Systems -> VSP E990 (S/N:xxxxxx) tree menu.

Click the Create Host Groups button on the right panel to create each host 
group as shown in the table above.

.. image:: ../_static/images/hitachi/create_hostgroup_1.png
   :width: 600
   :alt: Create Host Group

* Enter the host group name.
* Clock Host Mode Options and select Mode No. 2, 13, 22, 68, 91 to enable.
* Under Available Hosts, select the HBA WWN that is mapped.
* Under Available Ports, select the Storage port that is mapped.

Click the Add button, and then click the Finish button to create the host
group.

The following is a list of host groups after all host groups are created.

.. image:: ../_static/images/hitachi/hostgroup_list.png
   :width: 600
   :alt: List Host Group


Click the host group name and click the Host Mode Options tab to view the Host Mode Options settings.
2, 13, 22, 68. 91 should be enabled.

.. image:: ../_static/images/hitachi/hostgroup_hmo_list.png
   :width: 600
   :alt: Host Mode Options

The Host Group setup is complete.
Now that your Hitachi Storage is ready to use,
you can proceed to install :doc:`Burrito <install_offline>`.

