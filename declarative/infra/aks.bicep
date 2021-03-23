@secure()
param sshKey string

param aksSubnetId string
param appgwId string
param appgwName string
param logAnalyticsResourceId string

var location = resourceGroup().location
var roleContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var roleAcrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// Identities and RBAC
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'aks'
  location: location
}

resource aksIdentityRoleCluster 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('aksIdentityRoleCluster', resourceGroup().id)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleContributor)
    principalId: aksIdentity.properties.principalId
  }
}

resource aksIdentityRoleAcr 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('aksIdentityRoleAcr', resourceGroup().id)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAcrPull)
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
  }
}

resource appGwExisting 'Microsoft.Network/applicationGateways@2020-05-01' existing = {
  name: 'appgw'
}

resource aksIdentityRoleAppgw 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('aksIdentityRoleAppgw', resourceGroup().id)
  scope: appGwExisting
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleContributor)
    principalId: aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
  }
}

resource externalDnsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'externalDns'
  location: location
}

// AKS cluster
resource aks 'Microsoft.ContainerService/managedClusters@2021-02-01' = {
  name: 'aks-demo'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }
  properties: {
    kubernetesVersion: '1.19.6'
    dnsPrefix: 'aks-demo'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskType: 'Ephemeral'
        count: 2
        osDiskSizeGB: 32
        vmSize: 'Standard_D2as_v4'
        enableAutoScaling: true
        minCount: 2
        maxCount: 4
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: aksSubnetId
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
      }
    ]
    linuxProfile: {
      adminUsername: 'tomas'
      ssh: {
        publicKeys: [
          {
            keyData: sshKey
          }
        ]
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      podCidr: '192.168.0.0/16'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: [
        '2f003f7d-d039-4f87-8575-c2d45d091c2c'
      ]
    }
    addonProfiles:{
      'azurepolicy': {
        enabled: true
      }
      'gitops': {
        enabled: true
      }
      'omsagent': {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsResourceId
        }
      }
      'azureKeyvaultSecretsProvider': {
        enabled: true
        config: {
          enableSecretRotation: 'false'
        }
      }
      'ingressApplicationGateway': {
        enabled: true
        config: {
            applicationGatewayId: appgwId
            watchNamespace: ''
        }
    }
    }
    podIdentityProfile: {
      enabled: true
      allowNetworkPluginKubenet: false
      userAssignedIdentities: [
        {
          name: 'secrets-reader'
          namespace: 'default'
          identity: {
            resourceId: externalDnsIdentity.id
            clientId: externalDnsIdentity.properties.clientId
            objectId: externalDnsIdentity.properties.principalId
          }
        }
      ]
      // userAssignedIdentityExceptions: [
      //   {
      //     name: 'string'
      //     namespace: 'string'
      //     podLabels: {}
      //   }
      // ]
    }
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: uniqueString(subscription().id)
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}