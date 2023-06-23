Errata
=======

burrito.sh issue
-----------------

* Affected version: 1.2.0

The burrito.sh script is broken.

The burrito.yml playbook is moved out of kubespray upstream repo but burrito.sh script is still looking for it in the kubespray directory.

This is a patch.::

   @@ -7,7 +7,7 @@
    OSH_INFRA_PATH=${CURRENT_DIR}/../openstack-helm-infra
    OSH_PATH=${CURRENT_DIR}/../openstack-helm
    BTX_PATH=${CURRENT_DIR}/../btx/helm
   -KUBESPRAY_PATH=${CURRENT_DIR}/../kubespray
   +TOP_PATH=${CURRENT_DIR}/..
    OVERRIDE_PATH=$HOME/openstack-artifacts
    
    declare -A path_arr=(
   @@ -67,7 +67,7 @@
        ansible-playbook --extra-vars=@vars.yml ${OFFLINE_VARS} \
            --extra-vars="{\"$KEY\": [\"${NAME}\"]}" \
            ${TAG_OPTS} \
   -        ${KUBESPRAY_PATH}/burrito.yml
   +        ${TOP_PATH}/burrito.yml
      popd
    }
    uninstall() {

