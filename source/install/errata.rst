Errata
=======

burrito.sh issue
-----------------

* Affected version: 1.2.0

The burrito.sh script is broken.

The burrito.yml playbook is moved out of kubespray upstream repo but burrito.sh script is still looking for it in the kubespray directory.

Download :download:`the patch <../_static/00-patch-burrito-sh.txt>` and
put it in <burrito_source_dir>/patches/ directory.

Aply the patch.::

    $ cd <burrito_src_dir>
    $ ./scripts/patch.sh

