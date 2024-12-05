NetApp NFS over RDMA Support
=============================

This is a document to configure NetApp NFS over RDMA when you install Burrito.

After running prepare.sh script, you need to modify the following three files.

1. Modify group_vars/all/netapp_vars.yml.::

    +netapp_nfs_protocol: rdma
    +netapp_nfs_mount_options: "proto={{ netapp_nfs_protocol }},lookupcache=pos,nfsvers=3,nconnect=16"
     netapp:
       - name: netapp1
         managementLIF: "192.168.100.230"
         dataLIF: "192.168.140.19"
         svm: "svm01"
         username: "admin"
    -    nfsMountOptions: "lookupcache=pos"
    +    nfsMountOptions: "{{ netapp_nfs_mount_options }}"
         nas_secure_file_operations: false
         nas_secure_file_permissions: false
         shares:
    -      - /dev03
    +      - 10.1.1.21:/n1data
    +      - 10.1.1.22:/n2data

You add `netapp_nfs_protocol` and `netapp_nfs_mount_options` variables 
at the top and modify `nfsMountOptions` to use `netapp_nfs_mount_options` 
variable.
And modify `shares` list values from VOLUME_NAME to IP:VOLUME_NAME.

2. Modify openstack-helm/cinder/templates/bin/_cinder-volume.sh.tpl.::

    -    echo {{ $dataLIF }}:{{ $share }} >> /etc/cinder/share_{{ $name }}
    +    echo {{ $share }} >> /etc/cinder/share_{{ $name }}

Since we modified `shares` list values in netapp_vars.yml,
we change the content of `/etc/cinder/share_{{ $name }}`.

3. Modify roles/burrito.openstack/templates/osh/nova.yml.j2.::

          hw_disk_discard: unmap
    +     nfs_mount_options: "{{ netapp_nfs_mount_options }}"
        scheduler:

Add `nfs_mount_options` in nova.yml.j2. It is used when nova-compute 
mounts nfs volumes.

That's it.

You can proceed with the next installation procedures.

