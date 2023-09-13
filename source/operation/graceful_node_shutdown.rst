Graceful Node Shutdown
========================

Kubernetes has a Graceful Node Shutdown feature since 1.21.
(https://kubernetes.io/docs/concepts/architecture/nodes/#graceful-node-shutdown)

It uses systemd inhibitor lock to delay shutdown process when it detects
shutdown event.

But this feature is not stable when we tested it.
And there are many issues about this feature.

Here are some of them.

* https://github.com/kubernetes/kubernetes/issues/112443
* https://github.com/kubernetes/kubernetes/issues/110755
* https://github.com/kubernetes/kubernetes/issues/107158

So we developed Graceful Node Shutdown Helper (GNSH, pronounce 'gee-en-sh')
and added burrito.gnsh role in burrito 1.2.4.

GNSH is a little script to run when a node is started and is shutdown/rebooted.

When a node is shutdown or rebooted, this is a process to help evicting pods on
the node.

#. kubelet registers an inhibitor lock to delay shutdown for 300 seconds at boot
   time
#. systemctl [poweroff|reboot] or press power key, etc...
#. kubelet detects shutdown event.
#. kubelet Shutdown Manager changes the node status to NotReady.
#. kubelet Shutdown Manager kills pods and update pod status to the api server.
#. Kubelet Shutdown Manager completed processing shutdown event and unlock the
   delay inhibitor lock.
#. Now GNSH stop process is triggered by systemd daemon.
#. GNSH runs a process to drain the node.
#. The node is cordoned so the node status is changed to SchedulingDisabled.
#. All pods except static and daemonset are evicted if there are pods left on
   the node.
#. GNSH completes a drain process.
#. And systemd does the rest of the shutdown procedure.

When the node starts, kubelet will make the node Ready and GNSH uncordon the
node to make it schedulable.


