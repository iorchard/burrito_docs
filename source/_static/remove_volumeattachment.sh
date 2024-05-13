#!/bin/bash

declare -a PV_INGRESS
declare -a PV_MARIADB
declare -a PV_RABBITMQ

# Get ingress, mariadb, rabbitmq pv
PV_INGRESS[0]=$(sudo kubectl get pv|grep ingress-0|cut -d' ' -f1)
PV_INGRESS[1]=$(sudo kubectl get pv|grep ingress-1|cut -d' ' -f1)
PV_INGRESS[2]=$(sudo kubectl get pv|grep ingress-2|cut -d' ' -f1)

PV_MARIADB[0]=$(sudo kubectl get pv|grep mariadb-server-0|cut -d' ' -f1)
PV_MARIADB[1]=$(sudo kubectl get pv|grep mariadb-server-1|cut -d' ' -f1)
PV_MARIADB[2]=$(sudo kubectl get pv|grep mariadb-server-2|cut -d' ' -f1)

PV_RABBITMQ[0]=$(sudo kubectl get pv|grep rabbitmq-0|cut -d' ' -f1)
PV_RABBITMQ[1]=$(sudo kubectl get pv|grep rabbitmq-1|cut -d' ' -f1)
PV_RABBITMQ[2]=$(sudo kubectl get pv|grep rabbitmq-2|cut -d' ' -f1)

for i in ${!PV_INGRESS[@]}; do
  if [ ! -z ${PV_INGRESS[$i]} ]; then
    echo "ingress-${i} pvc: ${PV_INGRESS[$i]}"
    # get volumeattachment id
    VAID=$(sudo kubectl get volumeattachment|grep ${PV_INGRESS[$i]}|cut -d' ' -f1)
    echo "ingress-${i} volumeattachment id: ${VAID}"
    # delete volumeattachment
    sudo kubectl delete volumeattachment ${VAID}
  fi
done
for i in ${!PV_MARIADB[@]}; do
  if [ ! -z ${PV_MARIADB[$i]} ]; then
    echo "mariadb-${i} pvc: ${PV_MARIADB[$i]}"
    # get volumeattachment id
    VAID=$(sudo kubectl get volumeattachment|grep ${PV_MARIADB[$i]}|cut -d' ' -f1)
    echo "mariadb-${i} volumeattachment id: ${VAID}"
    # delete volumeattachment
    sudo kubectl delete volumeattachment ${VAID}
  fi
done
for i in ${!PV_RABBITMQ[@]}; do
  if [ ! -z ${PV_RABBITMQ[$i]} ]; then
    echo "rabbitmq-${i} pvc: ${PV_RABBITMQ[$i]}"
    # get volumeattachment id
    VAID=$(sudo kubectl get volumeattachment|grep ${PV_RABBITMQ[$i]}|cut -d' ' -f1)
    echo "rabbitmq-${i} volumeattachment id: ${VAID}"
    # delete volumeattachment
    sudo kubectl delete volumeattachment ${VAID}
  fi
done
