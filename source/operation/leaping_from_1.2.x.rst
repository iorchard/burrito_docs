Leaping from 1.2.x
===================

There is a significant gap in the kubernetes versions 
between Burrito 1.2.x and 1.3.x.
The k8s version of 1.2.x is v1.24.14 and that of 1.3.x is v1.28.3.

We created this release (aster-leap) to pave the way 
to upgrade Burrito 1.3.x from 1.2.x.

You will upgrade the k8s minor version one by one - v1.25.13, v1.26.8 and
v1.27.5 using Burrito aster-leap release
Then, you can upgrade to v1.28.x using Burrito 1.3.3 release.

I assume Burrito 1.2.5 is already installed and running.

This guide will show you how to upgrade kubernetes to v1.27.5 
using Burrito aster-leap release and eventually to v1.28.3 using
Burrito 1.3.3.

This is a version table.

===============  ============ ==============    =============
Components       Aster 1.2.5  Aster Leap        Aster 1.3.3
===============  ============ ==============    =============
containerd          v1.7.1      v1.7.5          v1.7.7
kubernetes          v1.24.14    v1.27.5         v1.28.3
etcd                v3.5.6      v3.5.7          v3.5.9
calico              v3.25.1     v3.25.2         v3.26.3
coredns             v1.8.6      v1.10.1         v1.10.1
helm                v3.12.0     v3.12.3         v3.13.1
nerdctl             1.4.0       1.5.0           1.6.0
crictl              v1.24.0     v1.27.1         v1.28.0
nodelocaldns        1.22.18     1.22.20         1.22.20
cert-manager        v1.11.1     v1.11.1         v1.11.1
metallb             v0.13.9     v0.13.9         v0.13.9
registry            2.8.2       2.8.2           2.8.2
===============  ============ ==============    =============

What you need
---------------

You need to have two iso files.

* burrito-aster-leap_8.9.iso
* burrito-1.3.3_8.9.iso

Ask for these files from SK Broadband CloudPC Team.

Modify kube-apiserver manifest
--------------------------------

First,
modify \--anonymous-auth to true in
/etc/kubernetes/manifests/kube-apiserver.yaml on every control node.::

    $ sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
    ...
        - --anonymous-auth=true

Wait until kube-apiserver is restarted on each control node.

Check if you can connect to each kube-apiserver.::

    $ curl -sk https://control1:6443/healthz
    ok
    $ curl -sk https://control2:6443/healthz
    ok
    $ curl -sk https://control3:6443/healthz
    ok

Prepare Aster-Leap iso
-----------------------

Use Burrito Aster Leap iso to upgrade the existing Burrito 1.2.x cluster.

Mount burrito-aster-leap_8.9.iso in /mnt.::

    $ sudo mount -o loop,ro burrito-aster-leap_8.9.iso /mnt

Unarchive burrito-aster-leap tarball from the iso.::

    $ tar xzf /mnt/burrito-aster-leap.tar.gz

Back up localrepo.cfg and registry.cfg in /etc/haproxy/conf.d/.::

    $ sudo mv /etc/haproxy/conf.d/localrepo.cfg \
                /etc/haproxy/conf.d/localrepo.cfg.bak
    $ sudo mv /etc/haproxy/conf.d/registry.cfg \
                /etc/haproxy/conf.d/registry.cfg.bak

Reload haproxy.service on the first control node.::

    $ sudo systemctl reload haproxy.service

Run prepare.sh script.::

    $ cd burrito-aster-leap
    $ ./prepare.sh offline

Copy files from the existing burrito directory (e.g. $HOME/burrito-1.2.x).::

    $ cp $HOME/burrito-1.2.x/.vaultpass .
    $ cp $HOME/burrito-1.2.x/group_vars/all/vault.yml group_vars/all/

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

Remove a localrepo pod and service.::

    $ sudo kubectl delete deploy localrepo -n burrito
    deployment.apps "localrepo" deleted
    $ sudo kubectl delete svc localrepo -n burrito
    service "localrepo" deleted

These pods will be recreated while upgrading.

Run preflight playbook.::

    $ ./run.sh preflight

You are ready to upgrade kubernetes cluster now.

Upgrade kubernetes
-------------------

You will upgrade the kubernetes three times with aster-leap release.

Upgrade to k8s v1.25.13
++++++++++++++++++++++++++

The first upgrade should be to v1.25.13.
Make sure kube_version is v1.25.13 in vars.yml.::

    # aster-leap release is a bridge release for leaping
    # from burrito 1.2.x (k8s v1.24.x) to burrito 1.3.x (k8s v1.28.3)
    # so I put kube_version variable here in editable area.
    # aster-leap supports k8s v1.25.13, v1.26.8, and v1.27.5
    kube_version: v1.25.13

Run k8s playbook with upgrade_cluster_setup=true.::

    $ ./run.sh k8s -e upgrade_cluster_setup=true

It will take a long time. 
It took about 52 minutes in my VM environment.

Check if the kubernetes version is v1.25.13.::

    $ kubectl version
    WARNING: This version information is deprecated and will be replaced with the output from kubectl version --short.  Use --output=yaml|json to get the full version.
    Client Version: version.Info{Major:"1", Minor:"25", GitVersion:"v1.25.13", GitCommit:"5244794d27b4cc68290bc496b00e248857ac8b47", GitTreeState:"clean", BuildDate:"2023-08-24T00:01:27Z", GoVersion:"go1.20.7", Compiler:"gc", Platform:"linux/amd64"}
    Kustomize Version: v4.5.7
    Server Version: version.Info{Major:"1", Minor:"25", GitVersion:"v1.25.13", GitCommit:"5244794d27b4cc68290bc496b00e248857ac8b47", GitTreeState:"clean", BuildDate:"2023-08-23T23:54:36Z", GoVersion:"go1.20.7", Compiler:"gc", Platform:"linux/amd64"}


Upgrade to k8s v1.26.8
++++++++++++++++++++++++++

The second upgrade should be to v1.26.8.
Set kube_version to v1.26.8 in vars.yml.::

    # aster-leap release is a bridge release for leaping
    # from burrito 1.2.x (k8s v1.24.x) to burrito 1.3.x (k8s v1.28.3)
    # so I put kube_version variable here in editable area.
    # aster-leap supports k8s v1.25.13, v1.26.8, and v1.27.5
    kube_version: v1.26.8

Run k8s playbook with upgrade_cluster_setup=true.::

    $ ./run.sh k8s -e upgrade_cluster_setup=true

Check if the kubernetes version is v1.26.8.::

    $ kubectl version
    WARNING: This version information is deprecated and will be replaced with the output from kubectl version --short.  Use --output=yaml|json to get the full version.
    Client Version: version.Info{Major:"1", Minor:"26", GitVersion:"v1.26.8", GitCommit:"395f0a2fdc940aeb9ab88849e8fa4321decbf6e1", GitTreeState:"clean", BuildDate:"2023-08-24T00:50:44Z", GoVersion:"go1.20.7", Compiler:"gc", Platform:"linux/amd64"}
    Kustomize Version: v4.5.7
    Server Version: version.Info{Major:"1", Minor:"26", GitVersion:"v1.26.8", GitCommit:"395f0a2fdc940aeb9ab88849e8fa4321decbf6e1", GitTreeState:"clean", BuildDate:"2023-08-24T00:43:07Z", GoVersion:"go1.20.7", Compiler:"gc", Platform:"linux/amd64"}


Upgrade to k8s v1.27.5
++++++++++++++++++++++++++

The third upgrade should be to v1.27.5.
Set kube_version to v1.27.5 in vars.yml.::

    # aster-leap release is a bridge release for leaping
    # from burrito 1.2.x (k8s v1.24.x) to burrito 1.3.x (k8s v1.28.3)
    # so I put kube_version variable here in editable area.
    # aster-leap supports k8s v1.25.13, v1.26.8, and v1.27.5
    kube_version: v1.27.5

Run k8s playbook with upgrade_cluster_setup=true.::

    $ ./run.sh k8s -e upgrade_cluster_setup=true

Check if the kubernetes version is v1.27.5.::

    $ kubectl version
    WARNING: This version information is deprecated and will be replaced with the output from kubectl version --short.  Use --output=yaml|json to get the full version.
    Client Version: version.Info{Major:"1", Minor:"27", GitVersion:"v1.27.5", GitCommit:"93e0d7146fb9c3e9f68aa41b2b4265b2fcdb0a4c", GitTreeState:"clean", BuildDate:"2023-08-24T00:48:26Z", GoVersion:"go1.20.7", Compiler:"gc", Platform:"linux/amd64"}
    Kustomize Version: v5.0.1
    Server Version: version.Info{Major:"1", Minor:"27", GitVersion:"v1.27.5", GitCommit:"93e0d7146fb9c3e9f68aa41b2b4265b2fcdb0a4c", GitTreeState:"clean", BuildDate:"2023-08-24T00:42:11Z", GoVersion:"go1.20.7", Compiler:"gc", Platform:"linux/amd64"}


Upgrade to Aster 1.3.3 (k8s v1.28.3)
++++++++++++++++++++++++++++++++++++++

Stop the offline services.::

    $ ./scripts/offline_services.sh -d

Unmount burrito-aster-leap_8.9.iso and
mount burrito-1.3.3_8.9.iso in /mnt.::

    $ sudo umount /mnt
    $ sudo mount -o loop,ro burrito-1.3.3_8.9.iso /mnt

Unarchive burrito-1.3.3 tarball from the iso.::

    $ tar xzf /mnt/burrito-1.3.3.tar.gz

Run prepare.sh script.::

    $ cd burrito-1.3.3
    $ ./prepare.sh offline

Copy files from the burrito-aster-leap directory.::

    $ cp $HOME/burrito-aster-leap/.vaultpass .
    $ cp $HOME/burrito-aster-leap/group_vars/all/vault.yml group_vars/all/

Edit hosts and vars.yml for your environment.::

    $ vi hosts
    $ vi vars.yml

Edit group_vars/all/\*.yml if you modified them for your environment.::

    $ vi group_vars/all/netapp_vars.yml
    $ vi group_vars/all/ceph_vars.yml

Check the node connectivity.::

    $ ./run.sh ping

Run k8s playbook with upgrade_cluster_setup=true.::

    $ ./run.sh k8s -e upgrade_cluster_setup=true

Check if the kubernetes version is v1.28.3.::

    $ kubectl version
    Client Version: v1.28.3
    Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
    Server Version: v1.28.3

Whew~~
Upgrading kubernetes is done!


Last but not least
-------------------

After you upgraded kubernetes, the following playbooks should be run.

Run patch playbook.::

    $ ./run.sh patch

Run registry playbook.::

    $ ./run.sh registry

Check the new images(e.g. kube-apiserver:v1.28.3) are added to 
the local registry.::

    $ curl -s control1:32680/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.24.14","v1.28.3"]}

Run landing playbook.::

    $ ./run.sh landing

Check the new images (e.g. kube-apiserver:v1.28.3) are added to 
the genesis registry.::

    $ curl -s control1:6000/v2/kube-apiserver/tags/list
    {"name":"kube-apiserver","tags":["v1.24.14","v1.28.3"]}

You finished a long upgrade journey from k8s v1.24.14 to v1.28.3.

Next, update each openstack component.

Update OpenStack components
----------------------------

Upgrade openstack components in 1.3.3.::

        $ ./run.sh burrito --tags=openstack

Check to see if any openstack operations are okay such as 

* listing openstack volume, compute services, and network agent service
* listing volumes and instances
* creating an image and a volume
* creating an instance

You've completed the upgrade to Burrito 1.3.3.
