Errata
=======

checklist issue
-----------------

* Affected version: 1.2.2

In the checklist.yml playbook that pre-checks before installing Burrito,
there is a task to check if all interfaces are up, which includes 
the storage nodes. The storage nodes may not have an overlay or a provider 
interface so they should be excluded from this task.

Download :download:`the patch <../_static/00-patch-checklist.txt>` and
put it in burrito/patches/ directory.

Apply the patch.::

    $ cd burrito-1.2.2
    $ ./scripts/patch.sh 


