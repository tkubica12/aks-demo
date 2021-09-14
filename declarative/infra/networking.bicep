var location = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: 'aks-demo-net'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    enableVmProtection: false
    enableDdosProtection: false
    subnets: [
      {
        name: 'appgw-subnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'intlb-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'jump-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.0.128.0/22'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'pod-subnet'
        properties: {
          addressPrefix: '10.0.132.0/22'
          privateEndpointNetworkPolicies: 'Disabled'
          delegations: [
            {
              name: 'aks-delegation'
              properties: {
                serviceName: 'Microsoft.ContainerService/managedClusters'
              }
            }
          ]
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'private.demo'
  location: 'global'
}

resource plinkDnsPsql 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${privateDnsZone.name}/${privateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource virtualNetworkLinkPsql 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${plinkDnsPsql.name}/${plinkDnsPsql.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource appGwIp 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: 'appgw-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'gw${uniqueString(resourceGroup().id)}'
    }
  }
}

resource appGw 'Microsoft.Network/applicationGateways@2020-05-01' = {
  name: 'appgw'
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/appgw-subnet'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: appGwIp.id
          }
        }
      }
      {
        name: 'privateIp'
        properties: {
          privateIPAddress: '10.0.0.100'
          privateIPAllocationMethod: 'Static'
          subnet: {
              id: '${vnet.id}/subnets/appgw-subnet'
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appGatewayFrontendPort'
        properties: {
          port: 8080
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appGatewayBackendHttpSettings'
        properties: {
          port: 8080
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
        }
      }
    ]
    httpListeners: [
      {
        name: 'appGatewayHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'appgw', 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'appgw', 'appGatewayFrontendPort')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rule1'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'appgw', 'appGatewayHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'appgw', 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'appgw', 'appGatewayBackendHttpSettings')
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id 
output aksSubnetId string = '${vnet.id}/subnets/aks-subnet'
output appgwSubnetId string = '${vnet.id}/subnets/appgw-subnet'
output podSubnetId string = '${vnet.id}/subnets/pod-subnet'
output intlbSubnetId string = '${vnet.id}/subnets/intlb-subnet'
output jumpSubnetId string = '${vnet.id}/subnets/jump-subnet'
output appgwId string = appGw.id
output appgwName string = appGw.name
output dnsZoneName string = privateDnsZone.name
output privateDnsPsqlId string = plinkDnsPsql.id
output appGwDns string = appGwIp.properties.dnsSettings.fqdn
