@secure()
param sshKey string

param aksSubnetId string
param appgwId string
param appgwName string
param logAnalyticsResourceId string
param dnsZoneName string
param keyvaultName string
param userObjectId string
param aksVersion string

var location = resourceGroup().location
var roleContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var roleAcrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var roleDnsContributor = 'b12aa53e-6015-4669-85d0-8515ebb3ae7f'
var roleKeyVaultSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'
var roleAksClusterAdmin = 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
var roleReader = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var roleMonitoringReader = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
var vmSize = 'Standard_D4ds_v4'

// Identities and RBAC
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'aks'
  location: location
}

resource aksIdentityRoleAcr 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('aksIdentityRoleAcr', resourceGroup().id)
  scope: aks
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleContributor)
    principalId: aksIdentity.properties.principalId
  }
}

resource aksIdentityRoleCluster 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('aksIdentityRoleCluster', resourceGroup().id)
  properties: {
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAksClusterAdmin)
    principalId: userObjectId
  }
}

resource userRoleAksClusterAdmin 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('userRoleAksClusterAdmin', resourceGroup().id)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleContributor)
    principalId: aksIdentity.properties.principalId
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

resource dnsZoneExisting 'Microsoft.Network/privateDnsZones@2018-09-01' existing = {
  name: dnsZoneName
}

resource externalDnsRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('externalDnsRole', resourceGroup().id)
  scope: dnsZoneExisting
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDnsContributor)
    principalId: externalDnsIdentity.properties.principalId
  }
}

resource keyvaultIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'secretsReader'
  location: location
}

resource keyvaultExisting 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyvaultName
}

resource keyvaultSecretsRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('keyvaultSecretsRole', resourceGroup().id)
  scope: keyvaultExisting
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleKeyVaultSecretsUser)
    principalId: keyvaultIdentity.properties.principalId
  }
}

resource kedaIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'keda'
  location: location
}

resource kedaReaderRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('kedaReaderRole', resourceGroup().id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleReader)
    principalId: kedaIdentity.properties.principalId
  }
}

resource kedaMonitoringReaderRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('kedaMonitoringReaderRole', resourceGroup().id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleMonitoringReader)
    principalId: kedaIdentity.properties.principalId
  }
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
    kubernetesVersion: aksVersion
    dnsPrefix: 'aks-demo'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskType: 'Ephemeral'
        count: 2
        osDiskSizeGB: 32
        vmSize: vmSize
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
        maxPods: 100
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
    addonProfiles: {
      'azurepolicy': {
        enabled: true
      }
      'openServiceMesh': {
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
    // podIdentityProfile: {
    //   enabled: true
    //   allowNetworkPluginKubenet: false
    //   userAssignedIdentities: [
    //     {
    //       name: 'secrets-reader'
    //       namespace: 'default'
    //       identity: {
    //         resourceId: externalDnsIdentity.id
    //         clientId: externalDnsIdentity.properties.clientId
    //         objectId: externalDnsIdentity.properties.principalId
    //       }
    //     }
    //   ]
    // userAssignedIdentityExceptions: [
    //   {
    //     name: 'string'
    //     namespace: 'string'
    //     podLabels: {}
    //   }
    // ]
    // }
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

output keyvaultIdentity string = keyvaultIdentity.properties.clientId
output aksNodeResourceGroup string = aks.properties.nodeResourceGroup

