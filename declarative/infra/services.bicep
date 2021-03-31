@secure()
param password string

param userObjectId string
param userName string
param localUser string
param subnetId string
param privateDnsPsqlId string

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

output keyvaultName string = keyvault.name
output keyvaultId string = keyvault.id
output psqlId string = psql.id
output psqlName string = psql.name
