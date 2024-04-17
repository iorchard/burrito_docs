Upgrade from 1.3.x
=====================

This is a guide to upgrade Burrito 1.3.x to 1.4.0.

* Source version: 1.3.2 - 1.3.3
* Target version: 1.4.0

It assumes Burrito 1.3.2 or 1.3.3 is installed and running.

Reqeust for the upgrade tarball file (1.3.xto1.4.0.tar.gz) to 
:email:`iOrchard Support Team <support@iorchard.net>`.

1. Go to burrito directory and unarchive the tarball.::

    $ cd /path/to/burrito/directory
    $ tar xvzf /path/to/1.3.xto1.4.0.tar.gz

2. Patch the source to 1.4.0.

Use 1.3.2to1.4.0.patch for 1.3.2 source.::

    $ patch -Np1 < 1.3.2to1.4.0.patch

Use 1.3.3to1.4.0.patch for 1.3.3 source.::

    $ patch -Np1 < 1.3.3to1.4.0.patch

3. Run image_upgrade.yml playbook.
   It will import, tag, and push new images to the local registry.::

    $ ./run.sh image_upgrade

Verify the new images are uploaded to the local registry.::

    $ curl -s <keepalived_vip>:5000/v2/jijisa/asklepios/tags/list | jq
    {
      "name": "jijisa/asklepios",
      "tags": [
        "0.2.0"
      ]
    }

4. Run gnsh_disable.yml playbook.
   It will disable gnsh systemd service on each kubernetes node.::

    $ ./run.sh gnsh_disable

5. Install Asklepios auto-healing service.

    - First, add asklepios variables in vars.yml (refer to vars.yml.sample).::

        ### asklepios
        asklepios:
          version: "0.2.0"
          verbose: false
          sleep: 10
          kickout: 60
          kickin: 60
          balancer: false
          initialDelaySeconds: 5
          periodSeconds: 10
          failureThreshold: 3
          timeoutSeconds: 10
          terminationGracePeriodSeconds: 10
          tolerationSeconds: 20

    - Second, install asklepios.::

        $ ./run.sh patch --tags=asklepios

Verify Asklepios is running on kube-system namespace.::

    root@btx-0:/# k get po -l app=asklepios -n kube-system
    NAME                         READY   STATUS    RESTARTS   AGE
    asklepios-784cb67dc8-4m6wz   1/1     Running   0          25m

6. Run burrito.genesisregistry role.::

    $ ./run.sh landing --tags=genesisregistry

Verify Asklepios image url is updated to the genesis registry.::

    root@btx-0:/# k get po -l app=asklepios -n kube-system -o yaml | grep image: | head -1

7. Update OpenStack components.

    - Add `install_barbican: false` in vars.yml.
    - Add `enable_iscsi_map` and `enable_iscsi` in vars.yml.::

        install_barbican: false
        enable_iscsi_map:
          ceph: false
          netapp: true
          powerflex: false
          hitachi: true
          primera: true
        enable_iscsi: "{{ storage_backends|map('extract', enable_iscsi_map)|list is any }}"

    - Run updated openstack components - keystone, glance, placement, neutron
      nova, and cinder.::

        $ ./scripts/burrito.sh install keystone
        $ ./scripts/burrito.sh install glance
        $ ./scripts/burrito.sh install placement
        $ ./scripts/burrito.sh install neutron
        $ ./scripts/burrito.sh install nova
        $ ./scripts/burrito.sh install cinder

That's all!

You've completed the upgrade to Burrito 1.4.0.

