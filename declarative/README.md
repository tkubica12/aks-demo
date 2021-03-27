# Demo

## Managed identity
Access Key Vault using managed identity

```bash
export pod=$(kubectl get pod -l app=keyvault-client -o=jsonpath='{.items[0].metadata.name}')
kubectl exec $pod -it -- bash
    export keyvault=kv-5jl6tmwrp3lkm
    export token=$(curl -s http://169.254.169.254/metadata/identity/oauth2/token?resource=https://vault.azure.net -H 'Metadata: true' | jq -r '.access_token')
    curl -H "Authorization: Bearer ${token}" https://$keyvault.vault.azure.net/secrets/mysecret?api-version=7.0
    exit
```

Access PostgreSQL using managed identity
```bash
```

## Key Vault integration
Use SecretProviderClass to access Key Vault secret

```bash
export pod=$(kubectl get pod -l app=keyvault-client -o=jsonpath='{.items[0].metadata.name}')
kubectl exec $pod -it -- ls /mnt/secrets-store
kubectl exec $pod -it -- cat /mnt/secrets-store/mysecret

```


# Debug
## Creating infrastructure using CLI

```bash
az bicep install
az bicep build -f infra/main.bicep --stdout 
az bicep build -f infra/main.bicep
az group create -n aks-demo -l westeurope
az deployment group create -g aks-demo --template-file infra/main.json \
    --parameters sshKey=@~/.ssh/id_rsa.pub \
    --parameters userObjectId=$(az ad user show --id $(az account show --query user.name -o tsv) --query objectId -o tsv)

az aks get-credentials -g aks-demo -n aks-demo --admin --overwrite
```

## Add identities to cluster

```bash
export rg=aks-demo
az aks update --enable-pod-identity -n aks-demo -g $rg
az aks pod-identity add -g $rg \
    --cluster-name aks-demo \
    --namespace default \
    --name external-dns \
    --identity-resource-id $(az identity show -n externalDns -g $rg --query id -o tsv)
az aks pod-identity add -g $rg \
    --cluster-name aks-demo \
    --namespace default \
    --name secrets-reader \
    --identity-resource-id $(az identity show -n secretsReader -g $rg --query id -o tsv)
```

## Connect cluster to GitOps
```bash
export rg=aks-demo
az k8s-configuration create -c aks-demo \
    --cluster-type managedClusters \
    -n common \
    -g $rg \
    --operator-type flux \
    --operator-params "'--git-readonly --git-path gitops/common'" \
    --repository-url https://github.com/tkubica12/aks-demo \
    --enable-helm-operator \
    --helm-operator-params '--set helm.versions=v3' \
    --scope cluster
```

## Access jump
```bash
export jumpip=$(az network public-ip show -n jump-vm-ip -g aks-demo --query ipAddress -o tsv)
ssh $jumpip
```

# Development - test only one module example
az bicep build -f infra/services.bicep
az deployment group create -g aks-demo --template-file infra/services.json --parameters userObjectId=$(az ad user show --id $(az account show --query user.name -o tsv) --query objectId -o tsv)


## Destroy
```bash
eport kezvaulkv-5jl6tmwrp3lkm
az keyvault delete -g $rg -n $keyvault 
az keyvault purge -n $keyvault 
az group delete -n aks-demo -y --no-wait
```




