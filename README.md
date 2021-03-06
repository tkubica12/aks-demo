# Azure Kubernetes Service demo
This repo contains my demo for AKS and related cloud-native patterns and projects.

**Work in progress**

There are two different styles of demos here:
- **Imperative** demo is using CLI tools and step by step process. With this approach you can start from empty environment building things layered on top allowing you to better understand what those components are and how they interact. Purpose of this demo is to learn details of features and components, not to demonstrate overall solution, outcomes, operations or deployment procedures.
- **Declarative** demo is using orchestration tools and CI/CD to deploy complete solution with all demos on single "click". Main purpose is to quickly spin up complete environment to demonstrate monitoring, running apps and explain technologies used.

Follow [Imperative guide](./imperative/README.md) or [Declarative guide](./imperative/README.md).

# Design goals for imperative demo
- Reproducible everywhere - no dependencies, everything can be done in any Azure subscription just by issuing the same commands
- Go step by step so it is clear how technologies and components interact with each other
- Guide user to follow some logical path to explore all aspects as journey

Implemented features
- AKS deployment
- AAD integration
- Scaling with KEDA
- Managed Ingress controller
- External DNS
- Pod identity
- Secrets management with Azure Key Vault and CSI
- Using Azure Database for PostgreSQL with Private Link, AAD integration and Pod identity
- Persistent Volume basics with Disks and Files

# Design goals for declarative demo
- Ability to spin everything up using GitHub Actions (might require some work to clone and modify for different subscription/project)
- As declarative as possible as recommended approach for production environment
- Document "how to demo" using monitoring, UI and CLI when needed

Implemented features
- AKS deployment
- AAD integration
- Managed Ingress controller
- External DNS
- Pod identity
- Secrets management with Azure Key Vault and CSI
- Using Azure Database for PostgreSQL with Private Link, AAD integration and Pod identity
- Distributed Tracing with Application Insights, OpenTelemetry
- Open Service Mesh
- DAPR
- Scrapping Prometheus metrics using Azure Monitor
- Grafana dashboard on top of Azure Monitor
- Azure Monitor for Containers - monitoring and telemetry
- Security policy with Azure Policy
  
# Backlog of features
- Canary and A/B testing with Flagger
- Scaling with KEDA
- Azure Arc for Kubernetes (hybrid solution)
- Using Kibana to search logs using K2Bridge
- Windows nodes
- Persistent storage with Azure Disk and Azure Files
- Azure Functions on Kubernetes
- Azure Logic Apps on Kubernetes
- Azure Cognitive Services on Kubernetes
- Azure API Management self-hosted gateway in Kubernetes
- Azure Defender for Kubernetes
- Cognitive Services in containers
