@secure()
param sshKey string

param aksSubnetId string
param appgwSubnetId string
param logAnalyticsResourceId string

var location = resourceGroup().location
var roleContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var roleAcrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'aks'
  location: location
}

resource aksIdentityRoleCluster 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(roleContributor, resourceGroup().id)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleContributor)
    principalId: aksIdentity.properties.principalId
  }
}

resource aksIdentityRoleAcr 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(roleAcrPull, resourceGroup().id)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAcrPull)
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2020-09-01' = {
  name: 'aks-demo'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }
  properties: {
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
            applicationGatewayName: 'appgw'
            subnetId: appgwSubnetId
            watchNamespace: ''
        }
    }
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