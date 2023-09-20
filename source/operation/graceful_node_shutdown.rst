Graceful Node Shutdown
========================

Kubernetes has a Graceful Node Shutdown feature since 1.21.
(https://kubernetes.io/docs/concepts/architecture/nodes/#graceful-node-shutdown)

It uses systemd inhibitor lock to delay shutdown process when it detects
shutdown event.

The current k8s version of burrito is 1.24.14 and the graceful node shutdown
feature is already enabled by default.

But this feature is not stable when we tested it.
There are many issues reported on this feature.

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

Here are the logs when a node is powering off.::

    Sep  9 17:45:37 control3 systemd-logind[666]: Power key pressed.
    Sep  9 17:45:37 control3 systemd-logind[666]: Powering Off...
    Sep  9 17:45:37 control3 kubelet[973]: I0909 17:45:37.860271     973 nodeshutdown_manager_linux.go:262] "Shutdown manager detected new shutdown event, isNodeShuttingDownNow" event=true
    ...
    Sep  9 17:46:08 control3 kubelet[973]: I0909 17:46:08.890638     973 nodeshutdown_manager_linux.go:324] "Shutdown manager completed processing shutdown event, node will shutdown shortly"
    Sep  9 17:46:08 control3 systemd-logind[667]: System is powering down.
    ...
             Stopping Graceful Node Shutdown Helper...
    [  920.090119] gnsh[13450]: Show the node status.
    [  920.209689] gnsh[13452]: NAME       STATUS     ROLES           AGE    VERSION
    [  920.211873] gnsh[13452]: control3   NotReady   control-plane   3d5h   v1.24.14
    [  925.214986] gnsh[13450]: Let's drain my node control3
    [  925.338511] gnsh[13483]: node/control3 cordoned
    [  925.376366] gnsh[13483]: evicting pod kube-system/nodelocaldns-rxnzq
    [  925.378692] gnsh[13483]: evicting pod kube-system/kube-proxy-fs9f7
    [  925.381179] gnsh[13483]: evicting pod kube-system/calico-node-sr9qk
    ...
    [  925.421417] gnsh[13483]: pod/calico-node-sr9qk evicted
    [  925.424240] gnsh[13483]: pod/kube-proxy-fs9f7 evicted
    [  925.427133] gnsh[13483]: pod/nodelocaldns-rxnzq evicted
    [  925.429745] gnsh[13483]: node/control3 drained
    [  930.450105] gnsh[13450]: Graceful Node Shutdown Helper (GNSH) completed a drain process
    [  OK  ] Stopped Graceful Node Shutdown Helper.
    ...
             Stopping Kubernetes Kubelet Server...
    ...
    [  OK  ] Stopped Kubernetes Kubelet Server.
    ...
             Stopping containerd container runtime...
    ...
    [  OK  ] Stopped containerd container runtime.
    ...
    [  933.761678] reboot: Power down


When the node starts, kubelet will make the node Ready and GNSH uncordon the
node to make it schedulable.


