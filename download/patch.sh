#!/bin/bash

## MGMT Keepalived IP
keep_ip="192.168.20.200"

## MGMT Controller IP
control_01_ip="192.168.20.201"
control_02_ip="192.168.20.202"
control_03_ip="192.168.20.203"


###################################################
## Do not edit below if you are not an expert!!!  #
###################################################
manifests_dir="/etc/kubernetes/manifests"
new_port="6000"

## Controller
hosts=(
  "$control_01_ip"
  "$control_02_ip"
  "$control_03_ip"
)

## Check if SSH key is present and copy it if not
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
  echo "id_rsa key created successfully"
  cat ~/.ssh/id_rsa.pub
  ssh-copy-id $control_02_ip
  ssh-copy-id $control_03_ip
else
  echo "id_rsa key already exists."
fi

## Check control-01 SSH key copy
if ssh -q -o PasswordAuthentication=no "$control_01_ip" exit; then
  echo "SSH key is already set up for control-01"
else
    ssh-copy-id $control_01_ip
fi

## image list
images=(
  "$keep_ip:5000/sig-storage/csi-provisioner:v3.3.0"
  "$keep_ip:5000/sig-storage/csi-snapshotter:v6.1.0"
  "$keep_ip:5000/sig-storage/csi-attacher:v4.0.0"
  "$keep_ip:5000/sig-storage/csi-resizer:v1.6.0"
  "$keep_ip:5000/cephcsi/cephcsi:v3.7.2"
  "$keep_ip:5000/sig-storage/csi-node-driver-registrar:v2.5.1"
  "$keep_ip:5000/kube-apiserver:v1.24.8"
  "$keep_ip:5000/kube-controller-manager:v1.24.8"
  "$keep_ip:5000/kube-scheduler:v1.24.8"
  "$keep_ip:5000/kube-proxy:v1.24.8"
)


## Controller image tagging and push
for host in "${hosts[@]}"; do
  for image in "${images[@]}"; do
    new_image="${host}:$new_port/${image#*/}"
    # image tagging
    ssh -l clex "$host" sudo nerdctl tag "${image}" "$new_image"

    # Push new tagging image
    ssh -l clex "$host" sudo nerdctl push "$new_image" > /dev/null 2>&1

    echo "Pushed image $new_image to $host"
  done
done

## Ceph-csi Patch
# Ceph-csi rbdplugin provisioner rolling update
sudo kubectl get deploy csi-rbdplugin-provisioner -n ceph-csi -o yaml > provisioner-deploy.yaml
sudo sed -i "s/maxSurge: 25%/maxSurge: 0/" provisioner-deploy.yaml
sudo sed -i "s/maxUnavailable: 25%/maxUnavailable: 1/" provisioner-deploy.yaml
sudo sed -i "s|$keep_ip:5000|$keep_ip:$new_port|g" provisioner-deploy.yaml
sudo kubectl apply -f provisioner-deploy.yaml -n ceph-csi
sudo rm provisioner-deploy.yaml
    echo "Rolling update csi-rbdplugin-provisioner"

# Ceph-csi rbd plugin Patch
sudo kubectl get ds csi-rbdplugin -n ceph-csi -o yaml > rbdplugin-daemon.yaml
sudo sed -i "s|$keep_ip:5000|$keep_ip:$new_port|g" rbdplugin-daemon.yaml
sudo kubectl apply -f rbdplugin-daemon.yaml -n ceph-csi
sudo rm rbdplugin-daemon.yaml
    echo "Patched ceph-csi rbdplugin image: 5000 -> $new_port"

## K8S Patch
# kube-proxy image patch
  sudo kubectl patch ds -n kube-system kube-proxy \
    -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"kube-proxy\",\"image\":\"$keep_ip:6000/kube-proxy:v1.24.8\"}]}}}}"
  echo "Patched kube-proxy image: 5000 -> $new_port"

# Patch for kube-apiserver.yaml
ssh -l clex "$host" sudo sed -i "s/$keep_ip:5000/$keep_ip:$new_port/g" "$manifests_dir/kube-apiserver.yaml"

# Patch for kube-controller-manager.yaml
ssh -l clex "$host" sudo sed -i "s/$keep_ip:5000/$keep_ip:$new_port/g" "$manifests_dir/kube-controller-manager.yaml"

# Patch for kube-scheduler.yaml
ssh -l clex "$host" sudo sed -i "s/$keep_ip:5000/$keep_ip:$new_port/g" "$manifests_dir/kube-scheduler.yaml"

echo "K8S images New port in kube-apiserver, kube-controller-manager, kube-scheduler to use port $new_port"

