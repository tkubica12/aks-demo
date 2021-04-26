@secure()
param password string

param userObjectId string
param userName string
param localUser string
param subnetId string
param privateDnsPsqlId string
param twitterConsumerKey string
param twitterConsumerSecret string
param twitterAccessToken string
param twitterAccessSecret string

var location = resourceGroup().location
var roleKeyVaultAministrator = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

// Key Vault
resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'kv-${uniqueString(subscription().id)}'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
  }
}

resource kvIdentityUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('kvIdentityUser', resourceGroup().id)
  scope: keyvault
  properties: {
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleKeyVaultAministrator)
    principalId: userObjectId
  }
}

resource kvSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/mysecret'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: 'MySuperPassword'
  }
}

// Azure Database for PostgreSQL
resource psql 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: 'psql-${uniqueString(subscription().id)}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    capacity: 2
    size: '102400'
    family: 'Gen5'
  }
  properties: {
    version: '11'
    createMode: 'Default'
    administratorLogin: localUser
    administratorLoginPassword: password
    publicNetworkAccess: 'Disabled'
    storageProfile: {
      backupRetentionDays: 35
      geoRedundantBackup: 'Disabled'
      storageMB: 102400
      storageAutogrow: 'Enabled'
    }
  }
}

resource psqlIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'psqlUser'
  location: location
}

resource psqlAdmin 'Microsoft.DBforPostgreSQL/servers/administrators@2017-12-01' = {
  name: '${psql.name}/ActiveDirectory'
  properties:{
    administratorType: 'ActiveDirectory'
    login: userName
    sid: userObjectId
    tenantId: subscription().tenantId
  }
}

resource plinkPsql 'Microsoft.Network/privateEndpoints@2020-08-01' = {
  name: 'plink-psql'
  location: location
  properties:{
    subnet:{
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plink-psql'
        properties:{
          privateLinkServiceId: psql.id
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
  }
}

resource plinkPsqlDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-08-01' = {
  name: '${plinkPsql.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'plinkPsqlDns'
        properties: {
          privateDnsZoneId: privateDnsPsqlId
        }
      }
    ]
  }
}

// Monitoring OpenTelemetry
resource logs 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: uniqueString(subscription().id)
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: uniqueString(subscription().id)
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: logs.id
  }
}

resource kvAppInsightsSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/appinsights'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: appinsights.properties.InstrumentationKey
  }
}

resource kvAppInsightsStringSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/appinsights-string'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: appinsights.properties.ConnectionString
  }
}

// Monitoring DAPR
resource daprLogs 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: 'dapr${uniqueString(subscription().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource daprAppinsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: 'dapr${uniqueString(subscription().id)}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: daprLogs.id
  }
}

resource kvDaprAppInsightsSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/dapr-appinsights'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: daprAppinsights.properties.InstrumentationKey
  }
}

resource kvDaprAppInsightsStringSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/dapr-appinsights-string'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: daprAppinsights.properties.ConnectionString
  }
}

// Monitoring Open Service Mesh
resource osmLogs 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: 'osm${uniqueString(subscription().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource osmAppinsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: 'osm${uniqueString(subscription().id)}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: osmLogs.id
  }
}

resource kvOsmAppInsightsSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/osm-appinsights'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: osmAppinsights.properties.InstrumentationKey
  }
}

resource kvOsmAppInsightsStringSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/osm-appinsights-string'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: osmAppinsights.properties.ConnectionString
  }
}

// Storage account
resource storage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: uniqueString(subscription().id)
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

resource kvStorageKey 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/storage-key'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: listKeys(storage.id, '2019-06-01').keys[0].value
  }
}

resource kvStorageAccount 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/storage-account'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: storage.name
  }
}

// Cognitive services
resource cs 'Microsoft.CognitiveServices/accounts@2017-04-18' = {
  name: uniqueString(subscription().id)
  kind: 'CognitiveServices'
  location: location
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: uniqueString(subscription().id)
  }
}

resource kvCsKey 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/cs-key'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: listkeys(cs.id, '2017-04-18').key1
  }
}

resource kvCsEndpoint 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/cs-endpoint'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: cs.properties.endpoint
  }
}

resource kvStorageString 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/storage'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, '2019-04-01').keys[0].value};EndpointSuffix=core.windows.net'
  }
}

// Service Bus
resource sb 'Microsoft.ServiceBus/namespaces@2017-04-01' = {
  name: 'sb${uniqueString(subscription().id)}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {}
}

resource sbDaprKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2017-04-01' = {
  name: '${sb.name}/daprKey'
  properties: {
    rights: [
      'Manage'
      'Listen'
      'Send'
    ]
  }
}

resource kvSbString 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/dapr-sb-string'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: listkeys(sbDaprKey.id, '2017-04-01').primaryConnectionString
  }
}

// Twitter secrets
resource kvTwitterConsumerKey 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/twitterConsumerKey'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: twitterConsumerKey
  }
}
resource kvTwitterConsumerSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/twitterConsumerSecret'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: twitterConsumerSecret
  }
}

resource kvTwitterAccessToken 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/twitterAccessToken'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: twitterAccessToken
  }
}
resource kvTwitterAccessSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyvault.name}/twitterAccessSecret'
  dependsOn: [
    kvIdentityUser
  ]
  properties: {
    value: twitterAccessSecret
  }
}

output logAnalyticsWorkspaceId string = logs.properties.customerId
output logAnalyticsResourceId string = logs.id
output keyvaultName string = keyvault.name
output keyvaultId string = keyvault.id
output psqlId string = psql.id
output psqlName string = psql.name
output psqlHost string = psql.properties.fullyQualifiedDomainName
output psqlUsername string = '${localUser}@${psql.name}'
output psqlIdentityClientId string = psqlIdentity.properties.clientId
output cognitiveServiceEndpoint string = cs.properties.endpoint
output sbEndpoint string = sb.properties.serviceBusEndpoint

