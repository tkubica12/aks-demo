@secure()
param sshKey string

param userObjectId string
param userName string

param twitterConsumerKey string
param twitterConsumerSecret string
param twitterAccessToken string
param twitterAccessSecret string

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
  params: {
    sshKey: sshKey
    jumpSubnetId: networking.outputs.jumpSubnetId
  }
}

// AKS
module aks './aks.bicep' = {
  name: 'aks'
  params:{
    aksSubnetId: networking.outputs.aksSubnetId
    appgwId: networking.outputs.appgwId
    appgwName: networking.outputs.appgwName
    logAnalyticsResourceId: services.outputs.logAnalyticsResourceId
    sshKey: sshKey
    dnsZoneName: networking.outputs.dnsZoneName
    keyvaultName: services.outputs.keyvaultName
    userObjectId: userObjectId
  }
}

// Services
module services './services.bicep' = {
  name: 'services'
  params:{
    userObjectId: userObjectId
    userName: userName
    localUser: 'tomas'
    password: 'Azure12345678'
    subnetId: networking.outputs.aksSubnetId
    privateDnsPsqlId: networking.outputs.privateDnsPsqlId
    twitterConsumerKey: twitterConsumerKey
    twitterConsumerSecret: twitterConsumerSecret
    twitterAccessToken: twitterAccessToken
    twitterAccessSecret: twitterAccessSecret
  }
}

output keyvaultName string = services.outputs.keyvaultName
output keyvaultIdentity string = aks.outputs.keyvaultIdentity
output subscriptionId string = subscription().subscriptionId
output tenantId string = subscription().tenantId
output resourceGroupName string = resourceGroup().name
output dnsZoneName string = networking.outputs.dnsZoneName
