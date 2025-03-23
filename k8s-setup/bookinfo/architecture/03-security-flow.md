# Security Flow
This diagram shows how Calico and Kubernetes components interact to secure application access.

```mermaid
flowchart TB
    subgraph K8s["Kubernetes Components"]
        api["API Server"]
        etcd["etcd"]
    end

    subgraph Calico["Calico Components"]
        controller["Policy Controller"]
        felix["Felix"]
    end

    subgraph Node["Node Components"]
        iptables["iptables/IPVS"]
        pod1["Pod A"]
        pod2["Pod B"]
    end

    netpol["NetworkPolicy YAML"] -->|1. Apply| api
    api -->|2. Store| etcd
    controller -->|3. Watch| api
    controller -->|4. Update| felix
    felix -->|5. Program Rules| iptables
    pod1 -->|6. Filtered Traffic| pod2
```

Demonstrates how NetworkPolicies are implemented through Calico's policy controller and Felix to secure pod-to-pod communication.
