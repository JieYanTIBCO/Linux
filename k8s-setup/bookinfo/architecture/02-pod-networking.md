# Pod Networking Flow
This diagram illustrates how Calico and Kubernetes components work together for pod networking.

```mermaid
flowchart TB
    subgraph K8s["Kubernetes Components"]
        kubelet["kubelet"]
        cni["CNI Interface"]
        kproxy["kube-proxy"]
    end

    subgraph Calico["Calico Components"]
        felix["Felix"]
        bird["BIRD BGP"]
        ipam["IPAM"]
    end

    kubelet -->|1. Request IP| cni
    cni -->|2. Configure Network| felix
    felix -->|3. Program Routes| bird
    felix <-->|4. Assign IP| ipam
    bird -->|5. Advertise Routes| bird2["Other Nodes' BIRD"]
    kproxy -->|6. Setup Service Rules| iptables["iptables/IPVS"]
```

Illustrates how Calico's CNI plugin, Felix, and BIRD components work with Kubernetes to provide pod networking.
