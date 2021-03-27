@secure()
param sshKey string

param userObjectId string

var location = resourceGroup().location
var roleContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var roleAcrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// Networking
module networking './networking.bicep' = {
  name: 'networking'
}

// Jump VM
module jump './jump.bicep' = {
  name: 'jump'
  dependsOn:[
    networking
  ]
  params: {
    sshKey: sshKey
    jumpSubnetId: networking.outputs.jumpSubnetId
  }
}

// AKS
module aks './aks.bicep' = {
  name: 'aks'
  dependsOn:[
    networking
    monitoring
  ]
  params:{
    aksSubnetId: networking.outputs.aksSubnetId
    appgwId: networking.outputs.appgwId
    appgwName: networking.outputs.appgwName
    logAnalyticsResourceId: monitoring.outputs.logAnalyticsResourceId
    sshKey: sshKey
    dnsZoneName: networking.outputs.dnsZoneName
    keyvaultName: services.outputs.keyvaultName
    userObjectId: userObjectId
  }
}

// Monitoring
module monitoring './monitoring.bicep' = {
  name: 'monitoring'
}

// Services
module services './services.bicep' = {
  name: 'services'
  params:{
    userObjectId: userObjectId
  }
}

output keyvaultName string = services.outputs.keyvaultName

