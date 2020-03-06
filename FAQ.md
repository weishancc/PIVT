### I don't want to launch the whole Fabric network but part of it, can I still use these charts?

Yes, you can. Network topology is defined in `crypto-config.yaml` file, just strip it down to desired components.

See the [cross-cluster-raft-network](https://github.com/APGGroeiFabriek/PIVT#cross-cluster-raft-network) sample for a complete running example and details.

### I'm not using `cryptogen` tool but we are creating our own certificates, can I still use these charts?

Yes, you can. As long as you arrange your certificates in a folder structure compatible with `cryptogen` tool.

If you are using intermediary certificates, possibly you need to extend the charts for that.

If you implement this, please feel free to share your extensions :)

### Why is chaincode flow invoking chaincodes? Isn't that creating unnecessary transactions?

Peers create chaincode containers at the very first time chaincode is invoked. This is a time taking operation.
We found it handy to invoke chaincodes for a dummy method immediately to force peers to create chaincode containers.

Anyway, this behaviour can be disabled by passing `flow.invoke.enabled=false` parameter to chaincode flow.

### Can I add new organizations/peers to an already running network?

Yes you can. See the [adding new peer organizations](https://github.com/APGGroeiFabriek/PIVT#adding-new-peer-organizations)
and [adding new peers to organizations](https://github.com/APGGroeiFabriek/PIVT/blob/master/README.md#adding-new-peers-to-organizations)
sections respectively.

### How can I distinguish between endorser and committer peers when running a network with multiple peers per organization?

We do not distinguish between endorser and committer peers for the sake of simplicity. Each peer is both endorser and committer. 
Technically speaking, the only difference is endorser peers need chaincodes installed to them.

But you can still make your own distinction at application level, as each peer can be accessed separately via its `peer service`

You can also fine tune chaincode flow not to install chaincodes to all peers. (No need to implement anything, 
just invoke chaincode flow with different `crypto-config.yaml` files)

### Why not use Kubernetes native [volume snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/) for backup/restore?

Kubernetes volume snapshots do not provide any [consistency guarantees](https://kubernetes.io/blog/2018/10/09/introducing-volume-snapshot-alpha-for-kubernetes/). 
Users are supposed to pause the application or freeze the filesystem etc. before taking the snapshot. So, as Fabric does not provide 
a mechanism for [pausing the peers and orderers](https://jira.hyperledger.org/browse/FAB-15542) for now, we still need to take down 
peers and orderers to take the backup.

For storing backup contents, using an Argo flow seemed more convenient. Volume snapshots are not yet supported by every cloud provider (read AKS) and restoring from a volume snapshot looks like a bit more complicated then our flow.

### Why not use cloud native disk snaphots for backup/restore?

Similar to above, cloud native disk snaphots do not provide any consistency guarantees.

Also, taking snapshot and restoring from it requires lots of cloud specific scripting. Our flow feels much more convenient as it will work on any cloud provider or even locally.

### What are those `no pem content for file` warnings?

You might see `warning` logs like below when orderer and peer pods are first launching or in Argo task logs:
```
2020-03-05 23:44:18.965 UTC [msp] getPemMaterialFromDir -> WARN 001 Failed reading file /etc/hyperledger/fabric/msp/admincerts/cert.pem: no pem content for file /etc/hyperledger/fabric/msp/admincerts/cert.pem
```

Theses logs are `harmless`and happens when you create the certificates with `cryptogen` version `1.4.3+`.

Since version `1.4.3`, `cryptogen` does not create certificates in the `admincerts` folder any more but creates `OU=admin` classification in the admin certificate. As a result, `hlf-kube` chart mounts an empty file to `admincerts/cert.pem` and we got this warning. This mount is necessary for `cryptogen` versions prior to `1.4.3` and hence for backward compatibility.
