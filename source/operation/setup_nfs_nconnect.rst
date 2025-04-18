Set up NFS nconnect option in pre-installed platform
=======================================================

Linux NFS client has the `nconnect` mount option that enables multiple TCP 
connections for a single NFS mount.
Setting nconnect as a mount option enables the NFS client to open multiple 
TCP connections for the same NFS server.

Starting with Burrito Begonia 2.1.4 and later, 
the NFS nconnect option is set by default.

This is a guide to setting up the nconnect option in the pre-installed
platform without the nconnect option.

.. warning::
   Your NetApp NFS server must support the nconnect option.
   Consult your NetApp representative.

Step1. Shut off all your instances
------------------------------------

First, you should shut off all your instances running on the compute nodes
for remounting a NFS volume with the nconnect option.::

    root@btx-0/# o server stop <vm1> <vm2> ...

Step2. Uninstall nova
----------------------

Patch nova-instances PV to preserve.::

    root@btx-0:/# NOVA_INSTANCES_PV=$(k get pvc nova-instances \
            -o jsonpath='{.spec.volumeName}')
    root@btx-0:/# echo $NOVA_INSTANCES_PV
    pvc-10448817-dacc-4206-95c6-186c47ea297f
    root@btx-0:/# k patch pv $NOVA_INSTANCES_PV -p \
            '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
    persistentvolume/pvc-10448817-dacc-4206-95c6-186c47ea297f patched

Uninstall nova. We will reinstall it with the nconnect option later.::

    $ cd burrito-<version>
    $ ./scripts/burrito.sh uninstall nova

Patch nova-instances PV to nullify claim.::

    root@btx-0:/# k patch pv $NOVA_INSTANCES_PV -p \
        '{"spec":{"claimRef": {"resourceVersion": null, "uid": null}}}'
    persistentvolume/pvc-10448817-dacc-4206-95c6-186c47ea297f patched

Patch nova-instances PV to add mountOptions.::

    root@btx-0:/# k patch pv $NOVA_INSTANCES_PV -p \
        '{"spec":{"mountOptions": ["lookupcache=pos", "nconnect=16"]}}'
    persistentvolume/pvc-10448817-dacc-4206-95c6-186c47ea297f patched

Add volumeName in openstack-helm/nova/templates/pvc-instances.yaml.::

    $ vi openstack-helm/nova/templates/pvc-instances.yaml
    ...
    spec:
      accessModes: [ "ReadWriteMany" ]
      resources:
        requests:
          storage: {{ .Values.volume.size }}
      storageClassName: {{ .Values.volume.class_name }}
      volumeName: pvc-10448817-dacc-4206-95c6-186c47ea297f
    {{- end }}

Step3. Unmount any NFS mounted volumes on all compute nodes
------------------------------------------------------------

Log into each compute node and there will be NFS mounted volumes like this.::

    $ mount |grep <NFS_SERVER_IP>
    192.168.140.19:/trident_pvc_10448817_dacc_4206_95c6_186c47ea297f on 
    /var/lib/nova/instances type nfs4 (rw,relatime,vers=4.2,rsize=65536,
    wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,
    clientaddr=192.168.21.164,lookupcache=pos,local_lock=none,
    addr=192.168.140.19)
    192.168.140.19:/dev12 on /var/lib/nova/mnt/7d14f8e82b407d5bf7e8d7916fe8869d
    type nfs4 (rw,relatime,vers=4.2,rsize=65536,wsize=65536,namlen=255,hard,
    proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.21.164,
    lookupcache=pos,local_lock=none,addr=192.168.140.19)

Unmount all NFS mounted volumes.::

    $ sudo umount /var/lib/nova/instances
    $ sudo umount /var/lib/nova/mnt/7d14f8e82b407d5bf7e8d7916fe8869d

Step4. Edit netapp storage class
---------------------------------

Edit a netapp storage class to add the nconnect mount option.::

    root@btx-0:/# k edit storageclass netapp
    ...
    mountOptions:
    - lookupcache=pos
    - nconnect=16

Step5. Add nfs_mount_options in nova configuration
---------------------------------------------------

Add conf.nova.libvirt.nfs_mount_options in nova.yml.j2.::

    $ cd burrito-<version>
    $ vi roles/burrito.openstack/templates/osh/nova.yml.j2
    ...
          virt_type: kvm
          disk_cachemodes: "network=writeback"
          hw_disk_discard: unmap
          nfs_mount_options: "lookupcache=pos,nconnect=16"
        scheduler:

Step6. Install Nova
--------------------

Install a nova helm chart.::

    $ ./scripts/burrito.sh install nova

Wait until all nova pods are ready and running.

Step7. Check if nconnect is applied
-------------------------------------

Check if NFS volumes are mounted with the nconnect option on the compute
nodes.::

    $ sudo mount |grep <NFS_SERVER_IP>
    192.168.140.19:/trident_pvc_10448817_dacc_4206_95c6_186c47ea297f on 
    /var/lib/kubelet/pods/c330fc9f-5887-4365-aacb-9d9e4218e064/volumes/
    kubernetes.io~csi/pvc-10448817-dacc-4206-95c6-186c47ea297f/mount type 
    nfs4 (rw,relatime,vers=4.2,rsize=65536,wsize=65536,namlen=255,hard,
    proto=tcp,nconnect=16,timeo=600,retrans=2,sec=sys,
    clientaddr=192.168.21.164,lookupcache=pos,local_lock=none,
    addr=192.168.140.19)
    192.168.140.19:/trident_pvc_10448817_dacc_4206_95c6_186c47ea297f on 
    /var/lib/nova/instances type nfs4 (rw,relatime,vers=4.2,rsize=65536,
    wsize=65536,namlen=255,hard,proto=tcp,nconnect=16,timeo=600,retrans=2,
    sec=sys,clientaddr=192.168.21.164,lookupcache=pos,local_lock=none,
    addr=192.168.140.19)

Check if there are multiple TCP connections between the compute node and
the NFS server.::

    $ ss -atn |grep <NFS_SERVER_IP>
    ESTAB      0      0      192.168.21.54:682   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:773   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:858   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:780   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:955   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:840   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:846   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:733   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:737   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:919   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:892   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:727   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:719   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:743   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:907   192.168.140.19:2049
    ESTAB      0      0      192.168.21.54:696   192.168.140.19:2049

Step8. Start all instances
------------------------------

Start all instances.::

    root@btx-0/# o server start <vm1> <vm2> ...

Now with the nconnect mount option, data IO for all instances is spread 
across multiple TCP connections.
