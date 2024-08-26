Upgrade from 2.0.x
===================

This is a guide to upgrade Burrito Begonia 2.0.x to 2.1.0

I assume Burrito Begonia 2.0.x is already installed and running.
This guide will show you how to upgrade it to Burrito Begonia 2.1.0.

Here is the example node ip address table.

===============     ================
Hostname            management IP         
===============     ================
control1            192.168.21.111
control2            192.168.21.112
control3            192.168.21.113
compute1            192.168.21.114
compute2            192.168.21.115
===============     ================

* KeepAlived VIP: 192.168.21.110

This is a k8s cluster version table.

===============  ============= ==============
Components       Begonia 2.0.x  Begonia 2.1.0
===============  ============= ==============
containerd          v1.7.13     v1.7.16
kubernetes          v1.29.2     v1.30.3
kubeadm             v1.29.2     v1.30.3
etcd                v3.5.10     v3.5.12
calico              v3.26.4     v3.27.3
coredns             v1.11.1     same as left
helm                v3.14.2     same as left
nerdctl             1.7.1       1.7.4
crictl              v1.29.0     v1.30.0
nodelocaldns        1.22.28     same as left
cert-manager        v1.13.2     v1.14.7
metallb             v0.13.9     same as left
registry            2.8.3       same as left
===============  ============= ==============

Modify kube-apiserver manifest
--------------------------------

First,
we need to modify kube-apiserver manifest.

Modify --anonymous-auth to true in
/etc/kubernetes/manifests/kube-apiserver.yaml on every control node.::

    $ sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
    ...
        - --anonymous-auth=true

Wait until kube-apiserver is restarted on each control node.

Check if we can connect to each kube-apiserver.::

    $ curl -sk https://192.168.21.111:6443/healthz
    ok
    $ curl -sk https://192.168.21.112:6443/healthz
    ok
    $ curl -sk https://192.168.21.113:6443/healthz
    ok

Prepare 2.1.0 iso
--------------------

We will use Burrito 2.1.0 iso to upgrade the existing Burrito
2.0.x cluster.

Mount burrito-2.1.0_8.10.iso in /mnt.::

    $ sudo mount -o loop,ro burrito-2.1.0_8.10.iso /mnt

Unarchive burrito-2.1.0 tarball from the iso.::

    $ tar xzf /mnt/burrito-2.1.0.tar.gz

Remove localrepo.cfg and registry.cfg in /etc/haproxy/conf.d/.::

    $ sudo rm /etc/haproxy/conf.d/{localrepo,registry}.cfg

These haproxy configuration files will be recreated while upgrading.

Reload haproxy.service on the first control node.::

    $ sudo systemctl reload haproxy.service

Before running prepare.sh script, you need to download patch files and
put them in patches directory.

See :doc:`errata page <install/errata>`.

Run prepare.sh script.::

    $ cd burrito-2.1.0
    $ ./prepare.sh offline

Copy the patched vars.yml.sample to vars.yml.::

    $ cp vars.yml.sample vars.yml

Copy files from the existing burrito dir (e.g. $HOME/burrito-2.0.x).::

    $ cp $HOME/burrito-2.0.x/.vaultpass .
    $ cp $HOME/burrito-2.0.x/group_vars/all/vault.yml group_vars/all/
    $ cp $HOME/burrito-2.0.x/.offline_flag .

Edit hosts and vars.yml for your environment.::

    $ vi hosts
    $ vi vars.yml

Edit group_vars/all/\*.yml if you modified them
for your environment.::

    $ vi group_vars/all/netapp_vars.yml
    $ vi group_vars/all/ceph_vars.yml

Check the node connectivity.::

    $ ./run.sh ping

Check if keepalived_vip(192.168.21.110) is on the first control node.::

    $ ip -br a s dev eth1
    eth1             UP             192.168.21.111/24 192.168.21.110/32 fe80::5054:ff:feeb:2b8b/64

If it is not, move keepalived_vip to the first control node by restarting 
keepalived service.
For example, if keepalived_vip is on the second control node, 
restart keepalived service on the second control node.::

    $ sudo systemctl restart keepalived.service

Then the keepalived_vip will be moved to the first control node.

Remove registry, localrepo, and asklepios pods.::

    $ sudo kubectl delete deploy registry localrepo asklepios -n kube-system
    deployment.apps "registry" deleted
    deployment.apps "localrepo" deleted
    deployment.apps "asklepios" deleted

These pods will be recreated while upgrading.

Run preflight playbook.::

    $ ./run.sh preflight

Run HA playbook.::

    $ ./run.sh ha

You are ready to upgrade kubernetes cluster.

Upgrade kubernetes
-------------------

Run k8s playbook with upgrade_cluster_setup=true.::

    $ ./run.sh k8s -e upgrade_cluster_setup=true

It will take a long time. 
It took about 50 minutes in my testbed.

Check if the kubernetes version is v1.30.3.::

    $ sudo kubectl version
    Client Version: v1.30.3
    Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
    Server Version: v1.30.3

Run storage playbook.::

    $ ./run.sh storage

Run patch playbook.::

    $ ./run.sh patch

Run registry playbook.::

    $ ./run.sh registry

Check the new images(e.g. kube-apiserver:v1.30.3) are added to 
the local registry.::

    $ curl -sk https://192.168.21.110:32680/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.30.3","v1.29.2"]}

Run landing playbook.::

    $ ./run.sh landing

Check the new images (e.g. kube-apiserver:v1.29.2) are added to 
the genesis registry.::

    $ curl -sk https://192.168.21.110:6000/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.29.2","v1.30.3"]}

Run burrito playbook with system tag to update /etc/hosts file.::

    $ ./run.sh burrito --tags=system

Kubernetes upgrade is done!

