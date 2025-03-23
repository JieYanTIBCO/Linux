# Application Exposure Flow
This diagram demonstrates how applications are exposed using Calico, Kubernetes, and infrastructure components.

```mermaid
flowchart TB
    subgraph External["External Access"]
        client["Client"]
        lb["Cloud Load Balancer"]
    end

    subgraph K8s["Kubernetes Components"]
        ing["Ingress Controller"]
        svc["Service"]
        kproxy["kube-proxy"]
    end

    subgraph Calico["Calico Security"]
        felix["Felix"]
        policy["Network Policies"]
    end

    client -->|1. Request| lb
    lb -->|2. Forward| ing
    ing -->|3. Route| svc
    svc -->|4. Load Balance| kproxy
    kproxy -->|5. Forward| pod["Pod"]
    felix -->|Apply Security| policy
    policy -->|Filter| pod
```

Shows the path of external traffic through load balancers, ingress controllers, and services, with Calico providing security through network policies.
