A simple HL Fabric network with a single node Raft orderer and one peer per organization. 
Also demonstrates how TLS can be enabled and actual domain names (instead of internal Kubernetes service names) can be used.

Transparent load balancing is not posssible because of TLS as of Fabric 1.4.1.
https://jira.hyperledger.org/browse/FAB-15648
