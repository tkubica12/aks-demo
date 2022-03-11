export RES_GROUP=aks-demo 
export VNET_NAME=aks-demo-net
export SUBNET_NAME=pod-subnet
export NETWORK_PROFILE_ID=$(az network profile list --resource-group $RES_GROUP --query [0].id --output tsv) 
az network profile delete --id $NETWORK_PROFILE_ID -y 
SAL_ID=$(az network vnet subnet show --resource-group $RES_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --query id --output tsv)/providers/Microsoft.ContainerInstance/serviceAssociationLinks/default
SAL_ID_AKS=$(az network vnet subnet show --resource-group $RES_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --query id --output tsv)/providers/Microsoft.ContainerService/serviceAssociationLinks/AzureKubernetesService
SAL_ID_AKS=$(az network vnet subnet show --resource-group $RES_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --query id --output tsv)/providers/Microsoft.ContainerService/serviceAssociationLinks/default
SAL_ID_AKS="/subscriptions/a0f4a733-4fce-4d49-b8a8-d30541fc1b45/resourceGroups/aks-demo/providers/Microsoft.Network/virtualNetworks/aks-demo-net/subnets/pod-subnet/serviceAssociationLinks/AzureKubernetesService"
az resource delete --ids $SAL_ID --api-version 2018-07-01 
az resource delete --ids $SAL_ID_AKS --api-version 2018-07-01
az network vnet subnet update --resource-group $RES_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --remove delegations 0 

az rest -u https://management.azure.com/subscriptions/a0f4a733-4fce-4d49-b8a8-d30541fc1b45/resourceGroups/aks-demo/providers/Microsoft.Network/virtualNetworks/aks-demo-net/subnets/pod-subnet/ServiceAssociationLinks?api-version=2021-03-01

7.	Delete the subnet
az network vnet subnet delete --resource-group $RES_GROUP GROUP --vnet-name vnet_name --name subnet_name 
8.	Delete virtual network
az network vnet delete --resource-group $RES_GROUP --name vnet_name 
9.	After successfully deleting the network profile please run the commands on Azure CLI or the bash CloudShell:
az login
az account list --output table
az account set --subscriptionId <subscription where the aks is located>
az aks delete --resource-group <rgname> --name <aks cluster name>
