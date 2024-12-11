Multiple Glance Stores
=======================

OpenStack Glance - the image service - supports different locations to store
the images since Train release.
We added this feature in Burrito 2.1.4 release.

In previous versions of Burrito, it set up a single glance store that 
uses the first storage even if there were multiple storage backends.

Now it sets up glance store for each storage backend.

For example, if you have three storage backends in the following order 
(netapp, ceph, and powerstore) in vars.yml,
you will have three glance stores, as shown below.::

             glance stores 
        |-> netapp  powerstore <-|          
        |         ceph <----------------------> pool=images 
        |                        |              ceph cluster
        |-> netapp  powerstore <-|
             cinder backends    

The glance stores for netapp and powerstore are cinder backends for each 
storage and the glance store for ceph is the images rbd pool in ceph cluster.
The default glance store is the first storage backend so it is netapp in this
case.

Check the glance stores.::

    root@btx-0:~# glance stores-info
    +----------+----------------------------------------------------------------------------------+
    | Property | Value                                                                            |
    +----------+----------------------------------------------------------------------------------+
    | stores   | [{"id": "netapp", "description": "netapp cinder backend", "default": "true"},    |
    |          | {"id": "ceph", "description": "ceph rbd backend"}, {"id": "powerstore",          |
    |          | "description": "powerstore cinder backend"}]                                     |
    +----------+----------------------------------------------------------------------------------+

You can see three glance stores and the default is netapp store.

When you upload an image file to the default glance store, it is saved in 
the netapp cinder backend.::

    root@btx-0:~# curl -Lo debian12.raw \
        https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.raw
    root@btx-0:~# o image create \
        --container-format bare \
        --disk-format raw \
        --property hw_disk_bus=scsi \
        --property hw_scsi_model=virtio-scsi \
        --property os_type=linux \
        --property os_distro=debian \
        --property os_admin_user=debian \
        --property os_version='12.7' \
        --public \
        --progress \
        --file debian12.raw \
        debian12

You can see the locations field in properties.::

    root@btx-0:~# o image show debian12 -c properties -f value
    ...
    'locations': [{'url':
    'cinder://netapp/a243651e-539a-4e5a-8c77-4f2c9f8ceead', 'metadata':
    {'store': 'netapp'}}]

The image can be located at cinder://netapp/VOLUME_UUID.

Now you can copy this image to other glance stores.::

    root@btx-0:~# glance image-import IMAGE_UUID --all-stores True \
        --import-method copy-image

See the locations again.::

    'locations': [{'url': 
    'cinder://netapp/2b232973-bc74-4368-b42e-17fe331a35fd', 
    'metadata': {'store': 'netapp'}}, 
    {'url': 'rbd://548a81fa-b391-11ef-8ca8-525400835d12/images/d367ae66-c497-46ab-9341-68a38d24d253/snap', 
    'metadata': {'store': 'ceph'}}, 
    {'url': 'cinder://powerstore/d367ae66-c497-46ab-9341-68a38d24d253',
    'metadata': {'store': 'powerstore'}}]

The image is copied to other stores.

Now cinder creates a volume from the image in the glance store that matches
the volume type.



