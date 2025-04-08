Upgrade Ingress Controller
===========================

The version of nginx ingress controller in Burrito Begonia Series is v1.8.2.

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

Patch nginx.tmpl on mariadb helm chart
++++++++++++++++++++++++++++++++++++++

Back up the current nginx.tmpl.::

    $ cd openstack-helm-infra/mariadb/files
    $ mv nginx.tmpl nginx.tmpl.bak

Download :download:`a new nginx.tmpl <../static/nginx.tmpl>`.

Put the downloaded file (nginx.tmpl) in openstack-helm-infra/mariadb/files/.

Upgrade OpenStack Ingress Controller
-------------------------------------

Change ingress image tag from v1.8.2 to v1.12.1 in 
roles/burrito.openstack/templates/osh_infra/ingress.yml.j2.::

    ingress: {{ kube_image_repo }}/ingress-nginx/controller:v1.12.1

Redeploy ingress helm chart.::

    $ ./scripts/burrito.sh install ingress

Check the ingress controller has a new version.::

    root@btx-0:/# k exec -it ingress-0 -c ingress -- /nginx-ingress-controller --version
    -------------------------------------------------------------------------------
    NGINX Ingress controller
      Release:       v1.12.1
      Build:         51c2b819690bbf1709b844dbf321a9acf6eda5a7
      Repository:    https://github.com/kubernetes/ingress-nginx
      nginx version: nginx/1.25.5
    
    -------------------------------------------------------------------------------

Upgrade MariaDB Ingress Controller
-------------------------------------

Change ingress image tag from v1.8.2 to v1.12.1 in 
roles/burrito.openstack/templates/osh_infra/mariadb.yml.j2.::

    images:
      tags:
        ...
        ingress: .../ingress-nginx/controller:v1.12.1

Install the new mariadb ingress.::

    $ ./scripts/burrito.sh install mariadb

Check the mariadb ingress controller has a new version.::

    root@btx-0:/# k exec <mariadb-ingress-pod> -c ingress -- /nginx-ingress-controller --version
    -------------------------------------------------------------------------------
    NGINX Ingress controller
      Release:       v1.12.1
      Build:         51c2b819690bbf1709b844dbf321a9acf6eda5a7
      Repository:    https://github.com/kubernetes/ingress-nginx
      nginx version: nginx/1.25.5

    -------------------------------------------------------------------------------

That's all.
