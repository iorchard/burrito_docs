Errata
=======

VM live migration issue when heartbeat_in_pthread is true
--------------------------------------------------------------

* Affected versions: 1.4.0 to 1.4.2

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

