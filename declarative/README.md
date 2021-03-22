

# Debug
## Creating infrastructure using CLI

```bash
az bicep install
az bicep build -f infra/main.bicep --stdout 
az bicep build -f infra/main.bicep
az group create -n aks-demo -l westeurope
az deployment group create -g aks-demo --template-file infra/main.json --parameters sshKey=@~/.ssh/id_rsa.pub
az aks get-credentials -g aks-demo -n aks-demo --admin
```

## Connect cluster to GitOps
```bash
az k8sconfiguration create -c aks-demo \
    --cluster-type managedClusters \
    -n common \
    -g aks-demo \
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

## Destroy
```bash
az group delete -n aks-demo -y --no-wait
```
