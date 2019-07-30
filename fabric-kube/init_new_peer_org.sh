#!/bin/bash

# creates new peer org certificates using project_folder/newpeerorg-crypto-config.yaml
# and copies them to hlf-kube/ folder

if test "$#" -ne 1; then
   echo "usage: init_new_peer_org.sh <project_folder>"
   exit 2
fi

# exit when any command fails
set -e

project_folder=$1
work_folder=/tmp

current_folder=$(pwd)

cd $project_folder

# convert newpeerorg-crypto-config.yaml to usable format for cryptogen
yq -y '.PeerOrgs = .NewPeerOrgs | del(.NewPeerOrgs)' newpeerorg-crypto-config.yaml > "$work_folder/crypto-config.yaml"

# generate certs
echo "-- creating certificates  --"
cryptogen generate --config "$work_folder/crypto-config.yaml" --output crypto-config

# copy stuff hlf-kube folder (as helm charts cannot access files outside of chart folder)
# see https://github.com/helm/helm/issues/3276#issuecomment-479117753
cd $current_folder

rm -rf hlf-kube/crypto-config

cp -r $project_folder/crypto-config hlf-kube/
cp -r $project_folder/newpeerorg-configtx.yaml hlf-kube/