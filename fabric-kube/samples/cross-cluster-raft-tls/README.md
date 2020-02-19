This sample demonstrates how to spread scaled-raft-tls sample over three Kubernetes clusters.

The layout is as follows:

Cluster-One:
    OrdererOrgs:
    - Name: Groeifabriek
      NodeCount: 2
    PeerOrgs:
    - Name: Karga
      PeerCount: 2
    
Cluster-Two:
    OrdererOrgs:
    - Name: Pivt
      NodeCount: 1
    PeerOrgs:
    - Name: Atlantis
      PeerCount: 2
  
Cluster-Three:
    PeerOrgs:
    - Name: Nevergreen
      PeerCount: 2

