param userObjectId string

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

output keyvaultName string = keyvault.name
output keyvaultId string = keyvault.id
