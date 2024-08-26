Errata
=======

kube-apiservers use only the first etcd node cert and key
----------------------------------------------------------

* Affected version: 2.1.0 and earlier

This issue is described at 
`issue 220 <https://github.com/iorchard/burrito/issues/220>`_.

Put the patch file before running prepare.sh script.

Download :download:`12-patch-kubespray-control-plane-kubeadm-secondary.txt <../_static/12-patch-kubespray-control-plane-kubeadm-secondary.txt>` and
put it in patches directory of burrito source on the first control node.::

    $ cp 12-patch-kubespray-control-plane-kubeadm-secondary.txt \
        burrito-<version>/patches/

Then, It is applied when you run prepare.sh script.

kube-apiserver has a wrong --advertise-address
-------------------------------------------------

* Affected version: 2.1.0

This issue is described at
`issue 221 <https://github.com/iorchard/burrito/issues/221>`_.

Put the patch file before running prepare.sh script.

Download :download:`12-patch-221-222.txt <../_static/12-patch-221-222.txt>` and
put it in patches directory of burrito source on the first control node.::

    $ cp 12-patch-221-222.txt \
        burrito-<version>/patches/

Then, It is applied when you run prepare.sh script.

kubernetes upgrade fails
---------------------------

* Affected version: 2.1.0

This issue is described at
`issue 222 <https://github.com/iorchard/burrito/issues/222>`_.

Put the patch file before running prepare.sh script.

Download :download:`12-patch-221-222.txt <../_static/12-patch-221-222.txt>` and
put it in patches directory of burrito source on the first control node.::

    $ cp 12-patch-221-222.txt \
        burrito-<version>/patches/

Then, It is applied when you run prepare.sh script.

