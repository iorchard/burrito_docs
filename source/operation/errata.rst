Errata
=======

kubernetes certificates are not renewed automatically
--------------------------------------------------------

This is a regression bug.

* Affected versions: 1.2.4 - 2.1.2

Do the following tasks on the control plane nodes for the affected versions.

1. Update k8s-certs-renew.sh script.

Before::

    until printf "" 2>>/dev/null >>/dev/tcp/127.0.0.1/6443; do sleep 1; done

After::

    until printf "" 2>>/dev/null >>/dev/tcp/192.168.21.91/6443; do sleep 1; done

192.168.21.91 is the management ip address.

2. Verify that the k8s-certs-renew.sh script is running.

The k8s-certs-renew.sh script should be running in the affected versions.::

    $ ps axuww |grep k8s-certs-renew.sh
    root     3452430  0.0  0.0 235784  3540 ?        Ss    2023 372:17 /bin/bash /usr/bin/k8s-certs-renew.sh

3. Kill the process.::

    $ sudo kill 3452430

As soon as you kill it, the k8s-certs-renew.sh script will start
and renew the certifcate. 

4. Verify that it is renewed with the following command.::

    $ sudo kubeadm certs check-expiration

Now that the k8s-certs-renew.sh script has been patched, 
your next certificate renewal should work fine.



