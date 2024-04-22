Install Asklepios
==================

This is a guide to installing 
`Asklepios <https://github.com/iorchard/asklepios>`_
where Burrito versions prior to 1.4.0 is already installed.

Reqeust for the asklepios tarball (asklepios.tar.gz) to
:email:`iOrchard Support Team <support@iorchard.net>`.

1. Go to burrito directory and unarchive the tarball.::

    $ cd /path/to/burrito/directory
    $ tar xzf /path/to/asklepios.tar.gz

2. Add --feature-gates parameter in kube-controller-manager 
   if and only if the kubernetes version is v1.24.x.

.. warning::
    Skip this step if your kubernetes version is v1.25 or later.
    Go to step 3.
   
Get the kubernetes version.::

    $ sudo kubectl get nodes
    NAME       STATUS   ROLES           AGE    VERSION
    compute    Ready    <none>          3d3h   v1.24.8
    control1   Ready    control-plane   3d3h   v1.24.8
    control2   Ready    control-plane   3d3h   v1.24.8
    control3   Ready    control-plane   3d3h   v1.24.8

If your kubernetes version is v1.24.x,
add `--feature-gates=NodeOutOfServiceVolumeDetach=true` to 
the kube-controller-manager manifest file on all control nodes.::

    $ sudo vi /etc/kubernetes/manifests/kube-controller-manager.yaml
    ...
      - command:
        - kube-controller-manager
        - --feature-gates=NodeOutOfServiceVolumeDetach=true
        - --allocate-node-cidrs=true

The kube-controller-manager will be recreated and running.

Verify the feature is added.::

    $ ps axuww |grep NodeOutOf
    root     1927410 16.8  0.5 828872 86204 ?        Ssl  16:15   0:02 kube-controller-manager --feature-gates=NodeOutOfServiceVolumeDetach=true ...

3. Import, tag the asklepios image and push it to the genesis registry.::

    $ zcat asklepios-0.2.0.tgz | sudo ctr -n k8s.io images import -
    $ sudo ctr -n k8s.io images tag --force docker.io/jijisa/asklepios:0.2.0 \
        KEEPALIVED_VIP:6000/jijisa/asklepios:0.2.0
    $ sudo ctr -n k8s.io images push --plain-http \
        KEEPALIVED_VIP:6000/jijisa/asklepios:0.2.0


Verify the new image is uploaded to the genesis registry.::

    $ curl -s KEEPALIVED_VIP:6000/v2/jijisa/asklepios/tags/list | jq
    {
      "name": "jijisa/asklepios",
      "tags": [
        "0.2.0"
      ]
    }

.. warning::
    Modify KEEPALIVED_VIP to match your site.


4. Install Asklepios auto-healing service.::

    $ ./run.sh asklepios

Verify Asklepios is running on kube-system namespace.::

    root@btx-0:/# k get po -l app=asklepios -n kube-system
    NAME                         READY   STATUS    RESTARTS   AGE
    asklepios-784cb67dc8-4m6wz   1/1     Running   0          25m

That's all!

You've completed the installation of Asklepios.

HA failover test
-----------------

Asklepios checks the control nodes status every 10 seconds.
Here are the logs.::

    I0419 08:57:29.755918       1 serve.go:154] "Node is ready" node="control1" status="True" kickedIn=true
    I0419 08:57:29.777117       1 serve.go:154] "Node is ready" node="control2" status="True" kickedIn=true
    I0419 08:57:29.800869       1 serve.go:154] "Node is ready" node="control3" status="True" kickedIn=true

Non-graceful node shutdown test
+++++++++++++++++++++++++++++++++

When a node is terminated abnormally, it became in NotReady status.

Terminate a node non-gracefully.
(I used `virsh destroy` command to terminate the control2 VM.)::

    $ virsh destroy control2

See the control2 node status changed.::

    NAME       STATUS      ROLES           AGE    VERSION
    control2   NotReady    control-plane   154m   v1.29.2

The control2 node becomes `NotReady`.
Asklepios will count down the kickout timeout and set the node unschedulable
and add the out-of-service taint on the node after timeout expiry.::

    I0305 05:43:06.488590       1 serve.go:145] "Node is not ready" node="control3" status="False" kickedOut=false timeToKickOut=51
    ...
    I0305 05:44:08.882515       1 k8s.go:167] "Succeeded to process the node" node="control3" action="Make the node unschedulable"
    I0305 05:44:12.524590       1 k8s.go:131] "Succeeded to process the node" node="control3" action="Add the out-of-service taint"

Now, see the control2 node status.::

    NAME       STATUS                         ROLES           AGE    VERSION
    control2   NotReady,SchedulingDisabled    control-plane   154m   v1.29.2

It becomes `NotReady,SchedulingDisabled`.

Look at the statefulset pods - mariadb and rabbitmq.::

    mariadb-server-0      1/1     Running   0          26h     10.203.198.32    control1   <none>           <none>
    mariadb-server-1      1/1     Running   0          14m     10.203.116.135   control3   <none>           <none>
    mariadb-server-2      1/1     Running   0          3m23s   10.203.116.156   control3   <none>           <none>
    rabbitmq-rabbitmq-0   1/1     Running   0          90m     10.203.116.130   control3   <none>           <none>
    rabbitmq-rabbitmq-1   1/1     Running   0          3m23s   10.203.116.155   control3   <none>           <none>
    rabbitmq-rabbitmq-2   1/1     Running   0          26h     10.203.198.33    control1   <none>           <none>

The pods (mariadb-server-2 and rabbitmq-rabbitmq-1) are moved to control3.

Restore the non-graceful shutdown node
+++++++++++++++++++++++++++++++++++++++++

Start the abnormally terminated node.
(I used `virsh start` command to terminate the control2 VM.)::

    $ virsh start control2

Now, see the control2 node status.::

    NAME       STATUS                      ROLES           AGE    VERSION
    control2   Ready,SchedulingDisabled    control-plane   160m   v1.29.2

The kubelet daemon is started on the node but it is still cordoned.
So the control2 status is `Ready,SchedulingDisabled`.

Asklepios will count down the kickin timeout and set the node schedulable
and remove the out-of-service taint on the node after the timeout expiry.::

    I0326 16:36:43.031326 1949139 k8s.go:342] "Succeeded to process the node" node="control2" action="Make the node schedulable"
    I0326 16:36:46.092946 1949139 k8s.go:306] "Succeeded to process the node" node="control2" action="Remove the out-of-service taint"

If you set askleios.balancer to true (Asklepios config file is 
burrito/roles/burrito.asklepios/defaults/main.yml.), Asklepios will move 
mariadb and rabbitmq pods to the recovered node.::

    I0326 16:36:46.159824 1949139 k8s.go:270] "Check RabbitMQ duplicate pods" dupFound=true podToKill="rabbitmq-rabbitmq-1"
    I0326 16:36:46.427518 1949139 k8s.go:221] "Check MariaDB duplicate pods" dupFound=true podToKill="mariadb-server-2"
    I0326 16:36:46.774089 1949139 serve.go:153] "Node is ready" node="control3" status="True" kickedIn=true
    I0326 16:36:47.126138 1949139 k8s.go:270] "Check RabbitMQ duplicate pods" dupFound=true podToKill="rabbitmq-rabbitmq-1"
    I0326 16:36:47.462799 1949139 k8s.go:221] "Check MariaDB duplicate pods" dupFound=true podToKill="mariadb-server-2"

See the mariadb and rabbitmq pods.::

    mariadb-server-0      1/1     Running   0          26h    10.203.198.32    control1   <none>           <none>
    mariadb-server-1      1/1     Running   0          25m    10.203.116.135   control3   <none>           <none>
    mariadb-server-2      1/1     Running   0          65s    10.201.206.177   control2   <none>           <none>
    rabbitmq-rabbitmq-0   1/1     Running   0          101m   10.203.116.130   control3   <none>           <none>
    rabbitmq-rabbitmq-1   1/1     Running   0          59s    10.201.206.178   control2   <none>           <none>
    rabbitmq-rabbitmq-2   1/1     Running   0          26h    10.203.198.33    control1   <none>           <none>

The mariadb-server-2 and rabbitmq-rabbitmq-1 are moved to the control2 node.


