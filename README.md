# Hyperledger Fabric meets Kubernetes with RaspberryPi-4
![Fabric Meets K8S](https://raft-fabric-kube.s3-eu-west-1.amazonaws.com/images/fabric_meets_k8s.png)

* [Preliminaries](#preliminaries)
* [Requirements](#requirements)
* [Scaled-up Raft network with TLS](#scaled-up-raft-network-with-tls)
  * [Set up](#set-up)
  * [Build up the network](#build-up-the-network)
* [Adding new peer organizations](#adding-new-peer-organizations)
* [Todo List](#todo-list)

## [Preliminaries](#preliminaries)
This repository applys [PIVT](https://github.com/hyfen-nl/PIVT) on RaspberryPi-4(RPi)
* The blockchain network configuration is based on [SFIOT](https://github.com/weishancc/SFIOT_blockchain) 
  * Initial 3 orgs with 2 peers of each, and 5 raft orderers
  * Chaincode is designed for manipulating data from smart meter/deep neural network model
* Still lack arm-based declarative flow
* Add new peer organizations to an already running network
* For more details please refer to orginal [README](https://github.com/hyfen-nl/PIVT/blob/master/README.md)

## [Requirements](#requirements)
* A running Kubernetes cluster, Minikube should also work, but not tested
* HL Fabric binaries (arm version!!)
* [Helm3](https://github.com/helm)
* [jq](https://stedolan.github.io/jq/download/) 1.5+ and [yq](https://pypi.org/project/yq/) 2.6+
* [Argo](https://github.com/argoproj/argo), both CLI and Controller 2.4.0+
* [Minio](https://github.com/argoproj/argo/blob/master/docs/configure-artifact-repository.md), required for new-peer-org flows
* Run all the commands in *fabric-kube* folder
* AWS EKS users please also apply this [fix](https://github.com/APGGroeiFabriek/PIVT/issues/1)
* A NFS-server which we used as [storageclass](https://kubernetes.io/docs/concepts/storage/storage-classes/)

## [Scaled-up Raft network with TLS](#scaled-up-raft-network-with-tls)

### [Set up](#set-up)
First install chart dependencies, you need to do this only once:
```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm dependency update ./hlf-kube/
```

---
NFS provisioner
```
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner . \
--set nfs.server=YOUR-NFS-SERVER-IP \
--set nfs.path=YOUR-NFS-SERVER-PATH \
--set image.repository=quay.io/external_storage/nfs-client-provisioner-arm
```

---
Argo
```
kubectl create ns argo
kubectl apply -n argo -f argo-install.yaml
kubectl create rolebinding default-admin --clusterrole=admin --serviceaccount=default:default
```

---
Minio
```
helm install argo-artifacts minio/minio \
--set service.type=LoadBalancer \
--set fullnameOverride=argo-artifacts \
--set persistence.storageClass=nfs-client \
--set defaultBucket.enabled=true \
--set defaultBucket.name=my-bucket 
```
Then configure the [configmap](https://github.com/argoproj/argo-workflows/blob/master/docs/configure-artifact-repository.md)
```
kubectl edit configmap workflow-controller-configmap -n argo
```

### [Build up the network](#build-up-the-network)
Now, lets launch a scaled up network based on three Raft orderer nodes spanning two Orderer organizations. This sample also demonstrates how to enable TLS and use actual domain names for peers and orderers instead of internal Kubernetes service names. Note this repo on RPi used Fabric 1.4.4, therefore the TLS should be enabled.

First tear down everything:
```
argo delete --all
helm delete hlf-kube --purge
```

Wait a bit until all pods are terminated:
```
kubectl  get pod --watch
```

Then create necessary stuff:
```
./init.sh ./samples/scaled-raft-tls/ ./samples/chaincode/
```

Lets launch our Raft based Fabric network in _broken_ state:
```
helm install ./hlf-kube --name hlf-kube -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/crypto-config.yaml 
```

The pods will start but they cannot communicate to each other since domain names are unknown. You might also want to use the option `--set peer.launchPods=false --set orderer.launchPods=false` to make this process faster.

Run this command to collect the host aliases:
```
./collect_host_aliases.sh ./samples/scaled-raft-tls/ 
```

Next, let's update the network with this host aliases information. These entries goes into pods' `/etc/hosts` file via Pod [hostAliases](https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/) spec.
```
helm upgrade hlf-kube ./hlf-kube -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/crypto-config.yaml -f samples/scaled-raft-tls/hostAliases.yaml  
```

Again lets wait for all pods are up and running:
```
kubectl get pod --watch
```

Congrulations you have a running scaled up HL Fabric network in Kubernetes, with 3 Raft orderer nodes spanning 2 Orderer organizations and 2 peers per organization. But unfortunately, due to TLS, your application cannot use them with transparent load balancing, you need to connect to relevant peer and orderer services separately.

Lets create the channels:
```
helm template channel-flow/ -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/crypto-config.yaml -f samples/scaled-raft-tls/hostAliases.yaml | argo submit - --watch
```

And install chaincodes:
```
helm template chaincode-flow/ -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/crypto-config.yaml -f samples/scaled-raft-tls/hostAliases.yaml | argo submit - --watch
```

## [Adding new peer organizations](#adding-new-peer-organizations)

First tear down and re-launch and populate the Raft network as described in [scaled-up-raft-network](#scaled-up-raft-network-with-tls)(scaled-up-raft-network) but pass the following additional flag: `-f samples/scaled-raft-tls/persistence.yaml`

At this point we can update the original configtx.yaml, crypto-config.yaml and network.yaml for the new organizations. First take backup of the originals:
```
rm -rf tmp && mkdir -p tmp && cp samples/scaled-raft-tls/configtx.yaml samples/scaled-raft-tls/crypto-config.yaml samples/scaled-raft-tls/network.yaml tmp/
```

Then override with extended ones:
```
cp samples/scaled-raft-tls/extended/* samples/scaled-raft-tls/ && cp samples/scaled-raft-tls/configtx.yaml hlf-kube/
```

Create new crypto material:
```
./extend.sh samples/scaled-raft-tls
```

Update the network for the new crypto material and configtx and launch new peers:
```
helm upgrade hlf-kube ./hlf-kube -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/crypto-config.yaml -f samples/scaled-raft-tls/persistence.yaml -f samples/scaled-raft-tls/hostAliases.yaml
```

Collect extended host aliases:
```
./collect_host_aliases.sh ./samples/scaled-raft-tls/ 
```

Upgrade host aliases in pods and wait for all pods are up and running:
```
helm upgrade hlf-kube ./hlf-kube -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/crypto-config.yaml -f samples/scaled-raft-tls/hostAliases.yaml -f samples/scaled-raft-tls/persistence.yaml
kubectl  get pod --watch
```

Let's create the new peer organizations:
```
helm template peer-org-flow/ -f samples/scaled-raft-tls/configtx.yaml -f samples/scaled-raft-tls/crypto-config.yaml -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/hostAliases.yaml | argo submit - --watch
```

Then run the channel flow to create new channels and populate existing ones regarding the new organizations:
```
helm template channel-flow/ -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/crypto-config.yaml -f samples/scaled-raft-tls/hostAliases.yaml | argo submit - --watch
```

Finally run the chaincode flow to populate the chaincodes regarding new organizations:
```
helm template chaincode-flow/ -f samples/scaled-raft-tls/network.yaml -f samples/scaled-raft-tls/crypto-config.yaml -f samples/scaled-raft-tls/hostAliases.yaml --set chaincode.version=2.0 | argo submit - --watch
```
Please note, we increased the chaincode version. This is required to upgrade the chaincodes with new policies. Otherwise, new peers' endorsements will fail.


Restore original files
```
cp tmp/configtx.yaml tmp/crypto-config.yaml tmp/network.yaml samples/scaled-raft-tls/
```

## [Todo list](#todo-list)
- [x] Arm-based declarative flow
- [x] Intergrate with [caliper](https://github.com/hyperledger/caliper)
