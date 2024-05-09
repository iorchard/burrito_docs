Upgrade
========

This is a guide to upgrade Burrito Aster to Burrito Begonia.

I assume Burrito Aster 1.4.2 is already installed and running.
This guide will show you how to upgrade it to Burrito Begonia 2.0.5.

This is a version table.

===============  ============ ==============
Components       Aster 1.4.2  Begonia 2.0.5
===============  ============ ==============
containerd          v1.7.7      v1.7.13
kubernetes          v1.28.3     v1.29.2
kubeadm             v1.28.3     v1.29.2
etcd                v3.5.9      v3.5.10
calico              v3.26.3     v3.26.4
coredns             v1.10.1     v1.11.1
helm                v3.13.1     v3.14.2
nerdctl             1.6.0       1.7.1
crictl              v1.28.0     v1.29.0
nodelocaldns        1.22.20     1.22.28
cert-manager        v1.11.1     v1.13.2
metallb             v0.13.9     v0.13.9
registry            2.8.2       2.8.3
===============  ============ ==============


Prepare Begonia iso
--------------------

We will use Burrito Begonia 2.0.5 iso to upgrade the existing Burrito
Aster cluster.

Mount burrito-2.0.5_8.9.iso in /mnt.::

    $ sudo mount -o loop,ro burrito-2.0.5_8.9.iso /mnt

Unarchive burrito-2.0.5 tarball from the iso.::

    $ tar xzf /mnt/burrito-2.0.5.tar.gz

Back up localrepo.cfg and registry.cfg in /etc/haproxy/conf.d/.::

    $ sudo mv /etc/haproxy/conf.d/localrepo.cfg \
                /etc/haproxy/conf.d/localrepo.cfg.bak
    $ sudo mv /etc/haproxy/conf.d/registry.cfg \
                /etc/haproxy/conf.d/registry.cfg.bak

Reload haproxy.service on the first control node.::

    $ sudo systemctl reload haproxy.service

Run prepare.sh script.::

    $ cd burrito-2.0.5
    $ ./prepare.sh offline

Copy files from the existing burrito dir (e.g. $HOME/burrito-1.4.2).::

    $ cp $HOME/burrito-1.4.2/.vaultpass .
    $ cp $HOME/burrito-1.4.2/group_vars/all/vault.yml group_vars/all/
    $ cp $HOME/burrito-1.4.2/.offline_flag .

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

You are ready to upgrade kubernetes cluster now.

Upgrade kubernetes
-------------------

Run k8s playbook with upgrade_cluster_setup=true.::

    $ ./run.sh k8s -e upgrade_cluster_setup=true

It will take a long time. 
It took about 52 minutes in my VM environment.

Check if the kubernetes version is v1.29.2.::

    $ kubectl version
    Client Version: v1.29.2
    Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
    Server Version: v1.29.2

Run asklepios playbook.::

    $ ./run.sh patch --tags=asklepios

Run k8spatch playbook.::

    $ ./run.sh patch --tags=k8spatch

Run registry playbook.::

    $ ./run.sh registry

Check the new images(e.g. kube-apiserver:v1.29.2) are added to 
the local registry.::

    $ curl -s 192.168.21.110:32680/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.28.3","v1.29.2"]}

Run landing playbook.::

    $ ./run.sh landing

Check the new images(e.g. kube-apiserver:v1.29.2) are added to 
the genesis registry.::

    $ curl -s 192.168.21.110:6000/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.28.3","v1.29.2"]}


Congratulations!
Upgrading Burrito Aster to Begonia is done!

