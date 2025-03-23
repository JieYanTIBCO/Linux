# Application Deployment Flow
This diagram shows how Kubernetes components interact when deploying an application.

```mermaid
flowchart TB
    subgraph User["User Actions"]
        kubectl["kubectl apply"]
    end

    subgraph K8s["Kubernetes Control Plane"]
        api["API Server"]
        etcd["etcd"]
        cm["Controller Manager"]
        sched["Scheduler"]
    end

    subgraph Node["Worker Node"]
        kubelet["kubelet"]
        runtime["Container Runtime"]
    end

    kubectl -->|1. Submit YAML| api
    api -->|2. Store| etcd
    api -->|3. Notify| cm
    cm -->|4. Create Pod| api
    api -->|5. Schedule Pod| sched
    sched -->|6. Assign Node| api
    api -->|7. Create Pod| kubelet
    kubelet -->|8. Start Container| runtime
```

Shows the sequence of component interactions when deploying an application, from kubectl command to container creation.
