Errata
=======

placement and barbican replica issue
-------------------------------------

* Affected version: 1.2.3 and earlier

The replicas for OpenStack placement and barbican api pod is set to 1.
It should be set to at least 2 if there are multiple control nodes.

If Burrito is not installed yet,
download :download:`the patch <../_static/00-patch-placement-barbican-replicas.txt>` and
put it in <burrito_source_dir>/patches/ directory.

If Burrito is already installed, 
go to btx shell and scale placement and barbican deployments.::

    root@btx-0:/# k scale --replicas=2 deploy barbican-api 
    root@btx-0:/# k scale --replicas=2 deploy placement-api

