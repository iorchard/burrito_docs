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
    NAME             STATUS   ROLES           AGE    VERSION
    aster-compute    Ready    <none>          3d3h   v1.24.8
    aster-control1   Ready    control-plane   3d3h   v1.24.8
    aster-control2   Ready    control-plane   3d3h   v1.24.8
    aster-control3   Ready    control-plane   3d3h   v1.24.8

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

4. Install Asklepios auto-healing service.

    $ ./run.sh asklepios

Verify Asklepios is running on kube-system namespace.::

    root@btx-0:/# k get po -l app=asklepios -n kube-system
    NAME                         READY   STATUS    RESTARTS   AGE
    asklepios-784cb67dc8-4m6wz   1/1     Running   0          25m

That's all!

You've completed the installation of Asklepios.

