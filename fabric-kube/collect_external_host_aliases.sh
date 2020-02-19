#!/bin/bash

if [ "$#" -lt 2 ]; then
   echo "usage: collect_host_aliases.sh <ingress|loadbalancer> <project_folder> [additional arguments for kubectl]"
   exit 2
fi

# exit when any command fails
set -e

expose_type=$1
project_folder=$2

case "$expose_type" in
    "ingress")
        peer_ingress_ip=$(kubectl --namespace kube-system get svc -l release=hlf-peer-ingress,component=controller -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
        orderer_ingress_ip=$(kubectl --namespace kube-system get svc -l release=hlf-orderer-ingress,component=controller -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

        kubectl get svc -l component=hlf-peer \
            -o jsonpath='{range..items[*]}- ip: '"$peer_ingress_ip"'{"\n"}  hostnames: [{.metadata.labels.fqdn}]{"\n"}{end}' \
            "${@:3}" \
            > $project_folder/externalHostAliases.yaml

        kubectl get svc -l component=hlf-orderer \
            -o jsonpath='{range..items[*]}- ip: '"$orderer_ingress_ip"'{"\n"}  hostnames: [{.metadata.labels.fqdn}]{"\n"}{end}' \
            "${@:3}" \
            >> $project_folder/externalHostAliases.yaml
        ;;

    "loadbalancer")
        kubectl get svc -l addToExternalHostAliases=true \
            -o jsonpath='{range..items[*]}- ip: {.status.loadBalancer.ingress[0].ip}{"\n"}  hostnames: [{.metadata.labels.fqdn}]{"\n"}{end}' \
            "${@:3}" \
            > $project_folder/externalHostAliases.yaml
        ;;

    *)
        echo "unknown expose type: '"$expose_type"', should be either 'ingress' or 'loadbalancer'"
        exit 2
esac


cat $project_folder/externalHostAliases.yaml