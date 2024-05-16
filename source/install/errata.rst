Errata
=======

1. Nova configuration issue when netapp is the default storage
----------------------------------------------------------------

* Affected version: 2.0.5, 2.0.4, and 2.0.3

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

2. VM live migration issue when heartbeat_in_pthread is true
--------------------------------------------------------------

* Affected versions: 2.0.1 to 2.0.6

The configuration `heartbeat_in_pthread` is set to true in nova.conf from
Begonia version 2.0.1 by default.

It is for a wsgi service like nova-api but nova-compute, 
nova-conductor, and nova-scheduler are not running as a wsgi service.
This setting makes the non-wsgi services unstable.
The VM instance live-migration fails due to this setting.

So it is better to set `heartbeat_in_pthread` to false.

Edit roles/burrito.openstack/templates/osh/nova.yml.j2.::

    heartbeat_timeout_threshold: {{ heartbeat_timeout_threshold }}
    heartbeat_rate: {{ heartbeat_rate }}
    heartbeat_in_pthread: false

Redeploy nova.::

    $ ./scripts/burrito.sh install nova

