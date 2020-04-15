#!/bin/bash

# extends certificates using project_folder/crypto-config.yaml
# and copies them to hlf-kube/ folder

if test "$#" -ne 1; then
   echo "usage: extend.sh <project_folder>"
   exit 2
fi

# exit when any command fails
set -e

project_folder=$1
current_folder=$(pwd)

cd $project_folder

# extend certificates
echo "-- extending certificates --"
cryptogen extend --config ./crypto-config.yaml --input crypto-config

# place holder empty folders for external peer orgs
externalPeerOrgs=$(yq '.ExternalPeerOrgs // empty' ./crypto-config.yaml -r -c)
if [ "$externalPeerOrgs" ]; then
    echo "-- creating empty folders for external peer orgs --"
    for peerOrgDomain in $(echo "$externalPeerOrgs" | jq -r '.[].Domain'); do
        echo "$peerOrgDomain"
        mkdir -p "./crypto-config/peerOrganizations/$peerOrgDomain/msp"
    done
fi 

# copy stuff hlf-kube folder (as helm charts cannot access files outside of chart folder)
# see https://github.com/helm/helm/issues/3276#issuecomment-479117753
cd $current_folder

rm -rf hlf-kube/crypto-config

cp -r $project_folder/crypto-config hlf-kube/
cp -r $project_folder/configtx.yaml hlf-kube/