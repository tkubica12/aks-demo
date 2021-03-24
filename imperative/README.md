# Agenda
- [Agenda](#agenda)
- [Get parameters](#get-parameters)
- [Cluster setup](#cluster-setup)
- [Authentication](#authentication)
- [Basics, GUI, upgrades](#basics-gui-upgrades)
- [Exposing applications](#exposing-applications)
  - [Managed Ingress with Azure Application Gateway](#managed-ingress-with-azure-application-gateway)
  - [Unmanaged Ingress with NGINX](#unmanaged-ingress-with-nginx)
- [Scaling](#scaling)
- [Secrets management](#secrets-management)
  - [Access secret in Key Vault using SecretsProviderClass](#access-secret-in-key-vault-using-secretsproviderclass)
  - [Access secret using application layer](#access-secret-using-application-layer)
- [Azure Monitor for Containers](#azure-monitor-for-containers)
- [Distributed tracing](#distributed-tracing)
- [Stateful workloads](#stateful-workloads)
  - [Connect to Azure PaaS](#connect-to-azure-paas)
  - [Using Azure Disk](#using-azure-disk)
  - [Using Azure Files](#using-azure-files)
  - [Working with StatefulSets](#working-with-statefulsets)
- [Destroy environment](#destroy-environment)

# Get parameters

```bash
export rg=aks-imperative-rg
export location=westeurope
export keyvault=tomaskeyvault45
```

# Cluster setup

Create resource group

```bash
az group create -n $rg -l $location
```

Create networking

```bash
az network vnet create -n mynet -g $rg --address-prefixes 10.0.0.0/16
az network vnet subnet create -n appgw-subnet --vnet-name mynet -g $rg --address-prefixes 10.0.0.0/24
az network vnet subnet create -n intlb-subnet --vnet-name mynet -g $rg --address-prefixes 10.0.1.0/24
az network vnet subnet create -n jump-subnet --vnet-name mynet -g $rg --address-prefixes 10.0.2.0/24
az network vnet subnet create -n aks-subnet --vnet-name mynet -g $rg --address-prefixes 10.0.128.0/22 --disable-private-endpoint-network-policies 
```

Create Private DNS

```bash
az network private-dns zone create -g $rg -n private.demo
az network private-dns link vnet create -n private-demo-link \
    -g $rg \
    -z private.demo \
    -e false \
    -v $(az network vnet show -n mynet -g $rg --query id -o tsv)
```

Create testing VM

```bash
az vm create -n jump \
    -g $rg \
    --admin-username tomas \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --image UbuntuLTS \
    --size Standard_B2s \
    --subnet $(az network vnet subnet show -n jump-subnet --vnet-name mynet -g $rg --query id -o tsv) \
    --no-wait
```

Prepare managed identity for AKS

```bash
az identity create -n aks -g $rg
sleep 30
az role assignment create --role "Contributor" -g $rg --assignee-object-id $(az identity show -n aks -g $rg --query principalId -o tsv)
```

Create AKS

```bash
az aks create -n aks \
    -g $rg \
    --aad-admin-group-object-ids 2f003f7d-d039-4f87-8575-c2d45d091c2c \
    -u tomas \
    --assign-identity $(az identity show -n aks -g $rg --query id -o tsv) \
    --enable-aad \
    --enable-addons monitoring,azure-policy,ingress-appgw,azure-keyvault-secrets-provider \
    --enable-azure-rbac \
    --enable-managed-identity \
    --enable-pod-identity  \
    --aks-custom-headers EnableAzureDiskFileCSIDriver=true \
    --kubernetes-version 1.19.6 \
    --network-plugin azure \
    --network-policy azure \
    --node-count 3 \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 4 \
    --node-vm-size Standard_B2s \
    --node-zones 1 2 3 \
    --ssh-key-value  ~/.ssh/id_rsa.pub \
    --vnet-subnet-id $(az network vnet subnet show -n aks-subnet --vnet-name mynet -g $rg --query id -o tsv) \
    --appgw-name appgw \
    --appgw-subnet-id $(az network vnet subnet show -n appgw-subnet --vnet-name mynet -g $rg --query id -o tsv) \
    --appgw-watch-namespace "" \
    --service-cidr 192.168.0.0/22 \
    --dns-service-ip 192.168.0.10
```

# Authentication

Get access to AKS and check AAD authentication

```bash
az aks get-credentials -n aks -g $rg --overwrite
kubectl get nodes
```

Authentication was successful, but I have no rights can use standard Kubernetes API to solve this or go with Azure RBAC.
Azure RBAC allows me to use advanced AAD features such as Privileged Identity Management!

```bash
az role assignment create --role "Azure Kubernetes Service RBAC Cluster Admin" \
    --assignee tokubica@microsoft.com \
    --scope $(az aks show -g $rg -n aks --query id -o tsv)

kubectl get nodes
```

# Basics, GUI, upgrades

Install simple application using Service with public IP

```bash
kubectl apply -f deployment.yaml
kubectl apply -f servicePublic.yaml
kubectl apply -f servicePrivateStatic.yaml
```

Check GUI in portal

Start continuous test

```bash
export ip=$(kubectl get svc myweb-service-ext-public -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
while true;do curl $ip; done
```

Upgrade master nodes using GUI

Upgrade node pool using GUI

Add new nodepool with different SKU using GUI

# Exposing applications

## Managed Ingress with Azure Application Gateway

Expose web via App Gw using private IP using HTTP

```bash
az network application-gateway frontend-ip create -n privateIp \
    --gateway-name appgw \
    -g $(az aks show -n aks -g $rg --query nodeResourceGroup -o tsv) \
    --subnet $(az network vnet subnet show -n appgw-subnet --vnet-name mynet -g $rg --query id -o tsv) \
    --private-ip-address 10.0.0.100

kubectl apply -f serviceClusterIp.yaml
kubectl apply -f ingressAgicPrivateHttp.yaml

ssh $(az network public-ip show -n jumpPublicIP -g $rg --query ipAddress -o tsv) 'curl http://10.0.0.100 -H "Host: web1.private.demo" -ks'
```

Expose web via App Gw using private IP using HTTPS and cert-manager

```bash
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
kubectl apply -f certManagerIssuer.yaml
kubectl apply -f ingressAgicPrivateHttps.yaml

ssh $(az network public-ip show -n jumpPublicIP -g $rg --query ipAddress -o tsv) 'curl https://10.0.0.100 -H "Host: web1.private.demo" -ks'
```

We will not configure External DNS to create records in Azure Private DNS (or Public).

Create new identity for External DNS (you can use cluster identity, but let's go least privilege)

```bash
az identity create -n externalDns -g $rg
```

Add RBAC for externalDns identity to enable access to DNS

```bash
az role assignment create --role "Private DNS Zone Contributor" \
    --assignee-object-id $(az identity show -n externalDns -g $rg --query principalId -o tsv)  \
    --scope $(az network private-dns zone show -g $rg -n private.demo --query id -o tsv)
az role assignment create --role "Reader" \
    --assignee-object-id $(az identity show -n externalDns -g $rg --query principalId -o tsv)  \
    -g $rg
```

Add RBAC for externalDns identity to enable assignment of identity to AKS

```bash
az role assignment create --role "Reader" \
    --assignee-object-id $(az identity show -n externalDns -g $rg --query principalId -o tsv)  \
    -g $(az aks show -g $rg -n aks --query nodeResourceGroup -o tsv)
```

Add identity to AKS Pod Identity

```bash
az aks pod-identity add -g $rg \
    --cluster-name aks \
    --namespace default \
    --name external-dns \
    --identity-resource-id $(az identity show -n externalDns -g $rg --query id -o tsv)
```

Deploy External DNS

```bash
kubectl create secret generic azure-config-file --from-file=azure.json
kubectl apply -f externalDns.yaml
```

That's it, check DNS record is created and test from VM

```bash
ssh $(az network public-ip show -n jumpPublicIP -g $rg --query ipAddress -o tsv) 'curl https://web1.private.demo -ks'
```

## Unmanaged Ingress with NGINX

Configure unmanaged Ingress with NGINX on internal IP

```bash
kubectl create namespace ingress-basic
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx -n ingress-basic -f nginxIngressValues.yaml
kubectl apply -f ingressNginxPrivateHttps.yaml

ssh $(az network public-ip show -n jumpPublicIP -g $rg --query ipAddress -o tsv) 'curl https://web2.private.demo -ks'
```

# Scaling

Create least privilege identity for KEDA

```bash
az identity create -n keda -g $rg
sleep 60

az role assignment create --role "Monitoring Reader" \
    --assignee-object-id $(az identity show -n keda -g $rg --query principalId -o tsv)  \
    --scope $(az network application-gateway show -n appgw -g $(az aks show -n aks -g $rg --query nodeResourceGroup -o tsv) --query id -o tsv)

az role assignment create --role "Reader" \
    --assignee-object-id $(az identity show -n keda -g $rg --query principalId -o tsv)  \
    -g $(az aks show -g $rg -n aks --query nodeResourceGroup -o tsv)

az aks pod-identity add -g $rg \
    --cluster-name aks \
    --namespace keda \
    --name keda \
    --identity-resource-id $(az identity show -n keda -g $rg --query id -o tsv)
```

Deploy KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
kubectl create namespace keda
helm upgrade -i keda kedacore/keda --namespace keda --set podIdentity.activeDirectory.identity=keda
```

Deploy app

```bash
kubectl apply -f kedaDeployment.yaml
kubectl apply -f kedaService.yaml
kubectl apply -f kedaIngressAgic.yaml
```

Configure and test scaling

```bash
kubectl apply -f kedaScaledObject.yaml

ssh $(az network public-ip show -n jumpPublicIP -g $rg --query ipAddress -o tsv)
    while true; do curl https://web3.private.demo -ks; done
```

# Secrets management

Create Azure Key Vault

```bash
az keyvault create -g $rg -n $keyvault --enable-rbac-authorization 
```

Assign management role to yourself

```bash
az role assignment create --role "Key Vault Administrator" \
    --assignee $(az account show --query user.name -o tsv)  \
    --scope $(az keyvault show -g $rg -n $keyvault --query id -o tsv)
```

Create secret

```bash
az keyvault secret set -n mysecret --vault-name $keyvault --value MySuperPassword
```

Create identity, assign secrets read role to it and add it to AKS+

```bash
az identity create -n secretsReader -g $rg
sleep 60

az role assignment create --role "Key Vault Secrets User" \
    --assignee-object-id $(az identity show -n secretsReader -g $rg --query principalId -o tsv)  \
    --scope $(az keyvault show -g $rg -n $keyvault --query id -o tsv)
az role assignment create --role "Reader" \
    --assignee-object-id $(az identity show -n secretsReader -g $rg --query principalId -o tsv)  \
    -g $(az aks show -g $rg -n aks --query nodeResourceGroup -o tsv)

az aks pod-identity add -g $rg \
    --cluster-name aks \
    --namespace default \
    --name secrets-reader \
    --identity-resource-id $(az identity show -n secretsReader -g $rg --query id -o tsv)
```

## Access secret in Key Vault using SecretsProviderClass

StorageProviderClass can access Key Vault using pod identity. Let's create managed identity, assign secrets read permission and assign to AKS.

Create StorageProviderClass referencing our Key Vault.

```bash
kubectl apply -f secretProviderClass.yaml
```

Test access to secret

```bash
kubectl apply -f secretViaProvider.yaml
kubectl exec nginx-secrets-store-inline -it -- bash
    ls /mnt/secrets-store/
    cat /mnt/secrets-store/mysecret
    exit
```

## Access secret using application layer 

Run Pod with assigned identity, use API to get token and Key Vault API to read secret.

```bash
kubectl apply -f secretViaApi.yaml
kubectl exec nginx-secrets-api -it -- bash
    export keyvault=tomaskeyvault45
    export token=$(curl -s http://169.254.169.254/metadata/identity/oauth2/token?resource=https://vault.azure.net -H 'Metadata: true' | jq -r '.access_token')
    curl -H "Authorization: Bearer ${token}" https://$keyvault.vault.azure.net/secrets/mysecret?api-version=7.0
```

# Azure Monitor for Containers

# Distributed tracing

```bash
az extension add -n application-insights
az monitor log-analytics workspace create -g $rg -n $rg-workspace1234
az monitor app-insights component create --app app-insights \
    -l westeurope \
    --kind web \
    -g $rg \
    --workspace $(az monitor log-analytics workspace show -g $rg -n $rg-workspace1234 --query id -o tsv)


export registry=fregistry1793
az acr create -n $registry -g $rg --sku Standard
az aks update -n aks -g $rg --attach-acr $(az acr show -n $registry -g $rg --query id -o tsv)
az acr build -r $registry --image opentelemetry:1 ./src/opentelemetry
az acr build -r $registry --image opentelemetry-tfgen:1 ./src/opentelemetry-tfgen
az acr build -r $registry --image java-autoinstrument:1 ./src/java-autoinstrument

helm upgrade -i tracing ./helm/opentelemetry -n default \
    --set repository=${registry}.azurecr.io/opentelemetry \
    --set tfgenRepository=${registry}.azurecr.io/opentelemetry-tfgen \
    --set javaRepository=${registry}.azurecr.io/java-autoinstrument \
    --set tag=1 \
    --set appin_key=$(az monitor app-insights component show --app app-insights -g $rg --query instrumentationKey -o tsv) \
    --set mysql_password=Azure12345678
```

# Stateful workloads
## Connect to Azure PaaS

First let's create PSQL with public access

```bash
export psql=tomaspsqldemo56
az postgres server create -n $psql \
    -g $rg \
    --backup-retention 35 \
    --minimal-tls-version TLS1_2 \
    --sku-name GP_Gen5_2 \
    --admin-user tomas \
    --admin-password Azure12345678 \
    --public all \
    -l $(az group show -n $rg --query location -o tsv)
```

Test connectivity from local PC

```bash
psql --host=$psql.postgres.database.azure.com --port=5432 --username=tomas@$psql --dbname=postgres
CREATE TABLE IF NOT EXISTS mytable (
   message VARCHAR ( 100 )
);
INSERT INTO mytable VALUES ('This is my message from PC');
SELECT * FROM mytable;
exit
```

Connect from Kubernetes

```bash
kubectl apply -f psqlClient.yaml
kubectl exec psql-client -ti -- psql --host=$psql.postgres.database.azure.com --port=5432 --username=tomas@$psql --dbname=postgres
SELECT * FROM mytable;
INSERT INTO mytable VALUES ('This is my message from AKS');
exit
```

Protect network connections by using private endpoint (you can also use service endpoint free of charge if no access from onprem and outbound access not neet to be force-routed without exceptions)

```bash
# Create Private Endpoint
az network private-endpoint create \
    -n plink-psql \
    -g $rg \
    --vnet-name mynet --subnet aks-subnet \
    --private-connection-resource-id $(az postgres server show -g $rg -n $psql --query id -o tsv) \
    --group-id postgresqlServer \
    --connection-name plink-psql-connection  

# Create DNS zone, link to VNET and zone group for PSQL
az network private-dns zone create -g $rg -n "privatelink.postgres.database.azure.com"

az network private-dns link vnet create \
     -g $rg \
    --zone-name "privatelink.postgres.database.azure.com" \
    --name dns-plink-psql \
    --virtual-network mynet \
    --registration-enabled false

az network private-endpoint dns-zone-group create \
    -g $rg \
    --endpoint-name plink-psql \
    --name zonegroup-plink-psql \
    --private-dns-zone "privatelink.postgres.database.azure.com" \
    --zone-name psql

# Disable any access except for Private Endpoint on PSQL
az postgres server update --public Disabled -g $rg -n $psql

# Connection from PC should fail
psql --host=$psql.postgres.database.azure.com --port=5432 --username=tomas@$psql --dbname=postgres

# Connection from AKS should be fine
kubectl exec psql-client -ti -- psql --host=$psql.postgres.database.azure.com --port=5432 --username=tomas@$psql --dbname=postgres
```

Enhance authentication with AAD integration and managed identity

```bash
# Enable AAD integration and make myself admin
az postgres server ad-admin create --server-name $psql \
    -g $rg \
    --display-name $(az account show --query user.name -o tsv) \
    --object-id $(az ad user show --id $(az account show --query user.name -o tsv) --query objectId -o tsv)

# Reenable public access
az postgres server update --public Enabled -g $rg -n $psql

# Get short-lived token to access database
export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)

# Connect to PSQL using token
psql --host=$psql.postgres.database.azure.com --port=5432 --username=tokubica@microsoft.com@$psql --dbname=postgres --set=sslmode=require

# Create managed identity and assign to cluster
az identity create -n psqlUser -g $rg

az aks pod-identity add -g $rg \
    --cluster-name aks \
    --namespace default \
    --name psql-user \
    --identity-resource-id $(az identity show -n psqlUser -g $rg --query id -o tsv)

TO BE CONTINUED
```

## Using Azure Disk

Check storage classes

```bash
kubectl get storageclasses
```

Create PVC. With CSI driver for Azure Disk actual resource in Azure will not be created until first consumer (pod) - this is because disks are zonal resources (disks must by in the same zone as compute currently - note ZRS is in preview, will be available in future).\

```bash
kubectl apply -f pvcDisk.yaml
```

Create Pod without specifying zone - you will see disk is created in the same zone as on node on which Pod has been scheduled.

```bash
kubectl get pv
kubectl apply -f pvcDiskPod.yaml
kubectl get pv
```

Clean up

```bash
kubectl delete -f pvcDiskPod.yaml
kubectl delete -f pvcDisk.yaml
```

## Using Azure Files

In first example we will create file share manually and just map it to pod as shared read volume (eg. shared web content scenario).

```bash
# Create file share and upload image
export storageName=tomasdemostore59
export nodeRg=$(az aks show -g $rg -n aks --query nodeResourceGroup -o tsv)
az storage account create -n $storageName -g $nodeRg
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $storageName -g $nodeRg --query connectionString -o tsv)
az storage share create -n images 
az storage file upload -s images --source ../images/ms.jpg
az storage file upload -s images --source ../images/index.html

# Prepare secret
kubectl create secret generic share-secret --from-literal accountname=$storageName --from-literal accountkey="$(az storage account keys list -n $storageName -g $nodeRg --query [0].value -o tsv)" --type=Opaque

# Map pod to share and test
kubectl apply -f pvcShareDemo.yaml
```

## Working with StatefulSets

# Destroy environment

```bash
az group delete -n $rg -y --no-wait
```