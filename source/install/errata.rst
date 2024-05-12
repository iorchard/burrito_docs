Errata
=======

Nova configuration issue when netapp is the default storage
------------------------------------------------------------

* Affected version: 2.0.5 and 2.0.4

We changed the default glance store type from `file` to `cinder`
When netapp is the default storage.

And there is `volume_use_multipath` config in libvirt section of nova.conf.
It is set to true when glance store type is cinder.

There will be an error when nova-compute tries to attach the volume since
multipath is not working for netapp NFS backend.

If you use netapp as the default storage, 
Edit roles/openstack/templates/osh/nova.conf 
to modify `volume_use_multipath` to `false`.::

    libvirt:
      volume_use_multipath: false
      connection_uri: "qemu+tcp://127.0.0.1/system"

If you already installed nova component, install nova again.::

    $ ./scripts/burrito.sh install nova

