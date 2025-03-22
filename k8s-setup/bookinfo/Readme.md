Customer Success Technical Assessment

Next Interview Structure
• 30min Technical Challenge demo
• 15min presentation
• Q&A throughout the interview

Technical Challenge Setup:
• Install a kubernetes cluster using the distribution and the environment of your choice (your laptop or
cloud) including 1x master and 2x nodes. Do not use managed kubernetes such as EKS, AKS or
GKE.
• Install calico, bookinfo app (attached), and an alpine pod for testing.  
• The bookinfo app is managed by a team called dev1
• Expose bookinfo product page using the method of your choice to users accessing it from outside of
the cluster from a well-defined network range
• Implement granular calico policies restricting communication among bookinfo micro-services to the
bare minimum. Define your strategy with respect to implementing ingress only, egress only, or
ingress and egress controls.

Technical Challenge Demo Process:
• Test access to bookinfo micro-services from within dev1 environment
• Test access to bookinfo micro-services from within the cluster, outside of dev1 environment
• Test access to bookinfo micro-services from outside of the cluster
• Explain the details of the configuration and testing
• Explain the details of the underlying routing that allows pods communication
• Explain the challenges you faced and how you resolved them

Presentation:
Prepare a few slides explaining the following:  
• Kubernetes components that interact for deploying an application  
• Calico and kubernetes components that interact for provisioning Pod networking
• Calico and kubernetes components that interact for securing access to an application
• Calico, kubernetes and infrastructure components that interact for exposing an application
