Errata
=======

Uncordon issue when gnsh.service starts
----------------------------------------

* Affected version: 1.3.3 and earlier

Gnsh is the Graceful Node Shutdown Helper program.
It cordons and drains the node when the node is gracefully powered off and
uncordons the node when the node is booted.

When gnsh systemd service starts at boot,
/usr/bin/gnsh script tries to uncordon the node only once and 
can fail if kube-apiserver is not ready yet.

I modified /usr/bin/gnsh script to try to uncordon the node 
10 times over 30 seconds if the node is not uncordoned.

Download :download:`the modified gnsh script <../_static/gnsh>` and
put it in /usr/bin/ directory on all kubernetes nodes.::

    $ chmod +x gnsh
    $ sudo cp gnsh /usr/bin/

Then, It will be applied on next boot.

