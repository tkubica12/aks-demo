@secure()
param sshKey string

param jumpSubnetId string

var location = resourceGroup().location

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: 'jump-vm'
  location: location
  properties: {
    osProfile: {
      computerName: 'jump-vm'
      adminUsername: 'tomas'
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/tomas/.ssh/authorized_keys'
              keyData: sshKey
            }
          ]
        }
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          properties: {
            primary: true
          }
          id: jumpnic.id
        }
      ]
    }
  }
}

resource jumpnic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: 'jump-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: jumpSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: jumpip.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: jumpnsg.id
    }
  }
}

resource jumpip 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: 'jump-vm-ip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource jumpnsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: 'jump-vm-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'ssh'
        properties: {
          priority: 1000
          sourceAddressPrefix: '*'
          protocol: 'Tcp'
          destinationPortRange: '22'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}