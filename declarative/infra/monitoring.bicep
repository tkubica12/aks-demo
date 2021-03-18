var location = resourceGroup().location

resource logs 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: uniqueString(subscription().id)
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

output logAnalyticsWorkspaceId string = logs.properties.customerId
output logAnalyticsResourceId string = logs.id