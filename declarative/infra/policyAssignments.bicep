param aksName string
param acrName string
param KubernetesNodeAffinity string
resource aks 'Microsoft.ContainerService/managedClusters@2021-02-01' existing = {
  name: aksName
}


// Kubernetes clusters should not allow container privilege escalation
resource noPrivilegeEscalationn 'Microsoft.Authorization/policyAssignments@2019-09-01' = {
    name: 'noPrivilegeEscalationn'
    scope: aks
    properties: {
        displayName: 'Kubernetes clusters should not allow container privilege escalation'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/1c6e92c9-99f0-4e55-9cf2-0c234dc48f99'
        parameters: {
          effect: {
            value: 'deny'
          }
          namespaces: {
            value: [
              'secure'
            ]
          }
        }
    }
}

// Kubernetes cluster should not allow privileged containers
resource noPrivilegeContainers 'Microsoft.Authorization/policyAssignments@2019-09-01' = {
    name: 'noPrivilegeContainers'
    scope: aks
    properties: {
        displayName: 'Kubernetes cluster should not allow privileged containers'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/95edb821-ddaf-4404-9732-666045e056b4'
        parameters: {
          effect: {
            value: 'deny'
          }
          namespaces: {
            value: [
              'secure'
            ]
          }
        }
    }
}


// Kubernetes cluster pods should use specified labels
resource podLabels 'Microsoft.Authorization/policyAssignments@2019-09-01' = {
    name: 'podLabels'
    scope: aks
    properties: {
        displayName: 'Kubernetes cluster pods should use specified labels'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/46592696-4c7b-4bf3-9e45-6c2763bdc0a6'
        parameters: {
          effect: {
            value: 'deny'
          }
          namespaces: {
            value: [
              'secure'
            ]
          }
          labelsList: {
            value: [
              'app'
            ]
          }
        }
    }
}


// Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits
resource maxLimits 'Microsoft.Authorization/policyAssignments@2019-09-01' = {
  name: 'maxLimits'
  scope: aks
  properties: {
      displayName: 'Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits'
      policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/e345eecc-fa47-480f-9e88-67dcc122b164'
      parameters: {
        effect: {
          value: 'deny'
        }
        namespaces: {
          value: [
            'secure'
          ]
        }
        cpuLimit: {
          value: '100m'
        }
        memoryLimit: {
          value: '100Mi'
        }
      }
  }
}


// Kubernetes cluster pods and containers should only run with approved user and group IDs
resource noRoot 'Microsoft.Authorization/policyAssignments@2019-09-01' = {
  name: 'noRoot'
  scope: aks
  properties: {
      displayName: 'Kubernetes cluster pods and containers should only run with approved user and group IDs'
      policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/f06ddb64-5fa3-4b77-b166-acb36f7f6042'
      parameters: {
        effect: {
          value: 'deny'
        }
        namespaces: {
          value: [
            'secure'
          ]
        }
        runAsUserRule: {
          value: 'MustRunAsNonRoot'
        }
      }
  }
}


// Kubernetes cluster containers should only use allowed images
resource allowedImages 'Microsoft.Authorization/policyAssignments@2019-09-01' = {
  name: 'allowedImages'
  scope: aks
  properties: {
      displayName: 'Kubernetes cluster containers should only use allowed images'
      policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/febd0533-8e55-448f-b837-bd0e06f16469'
      parameters: {
        effect: {
          value: 'deny'
        }
        namespaces: {
          value: [
            'secure'
          ]
        }
        allowedContainerImagesRegex: {
          value: '^${acrName}.azurecr.io/.+$'
        }
      }
  }
}

// CUSTOM: Require Pods to run on specified Nodes
resource nodeAffinity 'Microsoft.Authorization/policyAssignments@2019-09-01' = {
  name: 'nodeAffinity'
  scope: aks
  properties: {
      displayName: 'Require Pods to run on specified Nodes'
      policyDefinitionId: KubernetesNodeAffinity
      parameters: {
        effect: {
          value: 'deny'
        }
        namespaces: {
          value: [
            'secure'
          ]
        }
        nodeLabels: {
          value: [
            'protected'
          ]
        }
      }
  }
}
