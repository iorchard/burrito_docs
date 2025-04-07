Upgrade Ingress Controller 
===========================

The version of nginx ingress controller in Burrito Aster Series is v1.1.3.

Several vulnerabilities are found in nginx ingress controller.

* `CVE-2025-24513 <https://github.com/kubernetes/kubernetes/issues/131005>`_
* `CVE-2025-24514 <https://github.com/kubernetes/kubernetes/issues/131006>`_
* `CVE-2025-1097 <https://github.com/kubernetes/kubernetes/issues/131007>`_
* `CVE-2025-1098 <https://github.com/kubernetes/kubernetes/issues/131008>`_
* `CVE-2025-1974 <https://github.com/kubernetes/kubernetes/issues/131009>`_

You should upgrade it to at least v1.11.5 or v1.12.1.

This is a guide about how to upgrade ingress controller to v1.12.1.

Prepare Image
--------------

Get the ingress-nginx controller v1.12.1 image.::

    $ sudo ctr -n k8s.io images pull \
        registry.k8s.io/ingress-nginx/controller:v1.12.1

Exrpot the image to the tarball file.::

    $ sudo ctr -n k8s.io images export ingress-nginx-v1.12.1.tar \
        registry.k8s.io/ingress-nginx/controller:v1.12.1

Put the tarball on your Burrito platform and import the tarball.::

    $ sudo ctr -n k8s.io images import ingress-nginx-v1.12.1.tar

Tag the image to match your local registry - 
it will be *<keepalived_vip>:5000*.::

    $ sudo ctr -n k8s.io images tag \
        registry.k8s.io/ingress-nginx/controller:v1.12.1 \
        <keepalived_vip>:5000/ingress-nginx/controller:v1.12.1

Push the tagged image to your local registry.::

    $ sudo ctr -n k8s.io images push --skip-verify --platform linux/amd64 \
        <keepalived_vip>:5000/ingress-nginx/controller:v1.12.1

Patch helm charts
------------------

Download :download:`a new ingress helm chart tarball
<../_static/aster_ingress_helm_chart_upgrade.tar.gz>`.

Back up your current ingress helm chart.::

    $ cd burrito-<version>
    $ mv openstack-helm-infra/ingress openstack-helm-ingra/ingress.bak

Put the tarball in your burrito directory and extract it.::

    $ tar xvzf aster_ingress_helm_chart_upgrade.tar.gz

Upgrade OpenStack Ingress Controller
-------------------------------------

Edit roles/burrito.openstack/templates/osh_infra/ingress.yml.j2.::

    images:
      tags:
        ...
        ingress: .../ingress-nginx/controller:v1.12.1
                                              ^^^^^^^- changed image tag here
    deployment:
      type: StatefulSet
      cluster:                                  -
        class: "nginx"                           |
        ingressClassByName: false                |- added these four lines
        controllerClass: "k8s.io/nginx-ingress" -
    network:
      host_namespace: true

Uninstall and install the ingress controller.::

    $ ./scripts/burrito.sh uninstall ingress
    $ ./scripts/burrito.sh install ingress

Check the ingress controller has a new version.::

    root@btx-0:/# k exec -it -n openstack ingress-0 -c ingress -- /nginx-ingress-controller --version
    -------------------------------------------------------------------------------
    NGINX Ingress controller
      Release:       v1.12.1
      Build:         51c2b819690bbf1709b844dbf321a9acf6eda5a7
      Repository:    https://github.com/kubernetes/ingress-nginx
      nginx version: nginx/1.25.5
    
    -------------------------------------------------------------------------------

Upgrade MariaDB Ingress Controller
-------------------------------------

Edit roles/burrito.openstack/templates/osh_infra/mariadb.yml.j2.::

    images:
      tags:
        ...
        ingress: .../ingress-nginx/controller:v1.12.1
                                              ^^^^^^^- changed image tag here

Uninstall and install mariadb.::

    $ ./scripts/burrito.sh uninstall mariadb
    $ ./scripts/burrito.sh install mariadb


Check the ingress controller has a new version.::

    root@btx-0:/# k exec mariadb-ingress-5885866bb4-6p2pp -c ingress -- /nginx-ingress-controller --version
    -------------------------------------------------------------------------------
    NGINX Ingress controller
      Release:       v1.12.1
      Build:         51c2b819690bbf1709b844dbf321a9acf6eda5a7
      Repository:    https://github.com/kubernetes/ingress-nginx
      nginx version: nginx/1.25.5

    -------------------------------------------------------------------------------


That's all.
