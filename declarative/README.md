# Demo
To provision declarative demo use GitHub Actions. You can also run Actions to destroy environment.

- [Demo](#demo)
  - [Exposing apps with managed and unmanaged ingress and Azure DNS](#exposing-apps-with-managed-and-unmanaged-ingress-and-azure-dns)
  - [Access Key Vault using managed identity](#access-key-vault-using-managed-identity)
  - [Access PostgreSQL using managed identity and private link](#access-postgresql-using-managed-identity-and-private-link)
  - [Use SecretProviderClass to access Key Vault secret](#use-secretproviderclass-to-access-key-vault-secret)
  - [DAPR](#dapr)
  - [OpenTelemetry demo](#opentelemetry-demo)
  - [Collecting Prometheus metrics with Azure monitor](#collecting-prometheus-metrics-with-azure-monitor)
  - [Scaling with KEDA](#scaling-with-keda)
  - [Open Service Mesh demo](#open-service-mesh-demo)
    - [Traffic Split](#traffic-split)
    - [Traffic Access Control](#traffic-access-control)
    - [Traffic Metrics](#traffic-metrics)
    - [Ingress](#ingress)
  - [Security Policies with Azure Policy](#security-policies-with-azure-policy)
- [Debug](#debug)
  - [Creating infrastructure using CLI](#creating-infrastructure-using-cli)
  - [Add identities to cluster](#add-identities-to-cluster)
  - [Connect cluster to GitOps](#connect-cluster-to-gitops)
  - [Access jump](#access-jump)
- [Development - test only one module example](#development---test-only-one-module-example)
  - [Destroy](#destroy)

## Exposing apps with managed and unmanaged ingress and Azure DNS
Cluster is configured with two different Ingress classes:
- Managed Ingress with Azure Application Gateway running services on both private a public interfaces
- Unmanaged NGINX Ingress using private interface

See Ingress objects in default namespace.

Cert-manager is used to automatically enroll Let's encrypt certificated to Application Gateway public Ingress.

External DNS is configured to automatically create internal DNS records for apps deployed using Azure Private DNS.

## Access Key Vault using managed identity

```bash
export pod=$(kubectl get pod -l app=keyvault-client -o=jsonpath='{.items[0].metadata.name}')
kubectl exec $pod -it -- bash
    export keyvault=kv-5jl6tmwrp3lkm
    export token=$(curl -s http://169.254.169.254/metadata/identity/oauth2/token?resource=https://vault.azure.net -H 'Metadata: true' | jq -r '.access_token')
    curl -H "Authorization: Bearer ${token}" https://$keyvault.vault.azure.net/secrets/mysecret?api-version=7.0
    exit
```

## Access PostgreSQL using managed identity and private link

```bash
export pod=$(kubectl get pod -l app=psql-client -o=jsonpath='{.items[0].metadata.name}')
export psqlhost=$(az deployment group show -n services -g aks-demo --query properties.outputs.psqlHost.value -o tsv)
export psqlname=$(az deployment group show -n services -g aks-demo --query properties.outputs.psqlName.value -o tsv)
export psqlusername=$(az account show --query user.name -o tsv)@$psqlname
export psqlidentity=$(az deployment group show -n services -g aks-demo --query properties.outputs.psqlIdentityClientId.value -o tsv)


# Connect as AAD admin user, create tables and configure new user authenticated by managed identity
kubectl exec $pod -- sh -c "echo $psqlhost > psqlhost"
kubectl exec $pod -- sh -c "echo $psqlusername > psqlusername"
kubectl exec $pod -- sh -c "echo $psqlname > psqlname"
kubectl exec $pod -- sh -c "echo $(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv) > token"
echo $psqlidentity    # copy client identity to clipboard
kubectl exec $pod -it -- sh 
    export PGPASSWORD=$(cat token)
    psql --host=$(cat psqlhost) --port=5432 --username=$(cat psqlusername) --dbname=postgres
    CREATE TABLE IF NOT EXISTS mytable (
        message VARCHAR ( 100 )
    );
    INSERT INTO mytable VALUES ('This is my message');
    SELECT * FROM mytable;

    SET aad_validate_oids_in_tenant = off;
    CREATE ROLE myuser WITH LOGIN PASSWORD '<identityClientId>' IN ROLE azure_ad_user;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO myuser;

    exit
    exit

# Connect using Managed Identity
kubectl exec $pod -ti -- sh
    apk add curl
    apk add jq
    export PGPASSWORD=`curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fossrdbms-aad.database.windows.net' -H Metadata:true | jq -r .access_token`
    psql --host=$(cat psqlhost) --port=5432 --username=myuser@$(cat psqlname) --dbname=postgres
    SELECT * FROM mytable;
    INSERT INTO mytable VALUES ('Not permitted to do so');
    exit
    exit
```

## Use SecretProviderClass to access Key Vault secret

```bash
export pod=$(kubectl get pod -l app=keyvault-client -o=jsonpath='{.items[0].metadata.name}')
kubectl exec $pod -it -- ls /mnt/secrets-store
kubectl exec $pod -it -- cat /mnt/secrets-store/mysecret

```

## DAPR
Dapr Twitter analytics demo is deployed leveraging Twitter binding, pub/sub (via Service Bus) and state store (Storage Table).

- Portforward to UI and see tweets are displayed and scored for sentiment using Azure Cognitive Services
- Check message counters in Service Bus
- Check data stored in Storage Table
- See Application Insights for application map and traces

## OpenTelemetry demo
App with various components and traffic generator is deployed and exporter is used to send to Application Insights backend:
- See Python source code using universal OpenTelemetry SDK together with Azure Monitor exporter
- See Java container with Application Insights agent injected without any code modifications
- See Application Insights map and traces

## Collecting Prometheus metrics with Azure monitor
1. See prometheus workspace - there is Deployment running exposing Prometheus metrics.
2. Azure Monitor is configured to scrap metrics via ConfigMap in kube-system namespace.
3. Pods to be scraped are selected using annotation
4. Go to Azure portal, AKS UI and click Workbooks - there is visualization of scraped metrics

## Scaling with KEDA
There are two apps that scale based on Load:
- web based on telemetry information from Azure Application Gateway ingress
- worker based on messages in storage queue

To generate web load:

```bash
ssh $(az network public-ip show -n jumpPublicIP -g $rg --query ipAddress -o tsv)
    while true; do curl https://web3.private.demo -ks; done
```

To generate messages:

```bash
export storageName=$(az deployment group show -n maintemplate -g aks-demo --query properties.outputs.storageName.value -o tsv)
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $storageName -g aks-demo --query connectionString -o tsv)
for i in {1..200}
do
  az storage message put -q myqueue --content ahoj_$i
done
```

## Open Service Mesh demo

### Traffic Split
To test canary 90/10 split use app1 and test curl to app2 multiple times.

```bash
export pod=$(kubectl get pod -l app=app1 -n openservicemesh -o=jsonpath='{.items[0].metadata.name}')
kubectl exec $pod -n openservicemesh -it -- apk add curl
kubectl exec $pod -n openservicemesh -it -- sh -c 'while true; do curl app2.openservicemesh; sleep 0.2; done'
kubectl exec $pod -n openservicemesh -it -- sh -c 'while true; do curl -H "tester: true" app2-ab.openservicemesh; sleep 0.2; done'
```

OSM currently does not support SMI Traffic Split v1alpha4 which adds HTTPRouteGroup match to split allowing A/B testing scenarios. This is planned for 0.9.0: https://github.com/openservicemesh/osm/issues/2368

Objects are prepared, but commented until supported.

```bash
export pod=$(kubectl get pod -l app=app1 -n openservicemesh -o=jsonpath='{.items[0].metadata.name}')
kubectl exec $pod -n openservicemesh -it -- apk add curl
kubectl exec $pod -n openservicemesh -it -- sh -c 'while true; do curl -H "tester: true" app2-ab.openservicemesh; sleep 0.2; done'
```

### Traffic Access Control
WIP

Default installation is configured to allow all (permissive mode). Let's make this restrictive.

```bash
kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"permissive_traffic_policy_mode":"false"}}'
```

```bash
export pod=$(kubectl get pod -l app=app1 -n openservicemesh -o=jsonpath='{.items[0].metadata.name}')
kubectl exec $pod -n openservicemesh -it -- apk add curl
kubectl exec $pod -n openservicemesh -it -- sh -c 'curl -v app2-v1.openservicemesh'
```

### Traffic Metrics
TBD

### Ingress
TBD

## Security Policies with Azure Policy
Several policies are applied on cluster - see Azure Policy assignments in portal. All policies are scoped to include only namespace "secure".

There are multiple deployments deployed in this namespace:
- ok - this one is fine
- noLimits - this is failing because there are no resource limits or limits are set over maximum defined by policy
- root - this is failing because container attempts to run as root
- wrongRegistry - this is failing because image is from registry non compliant with policy

To see error messages find ReplicatSets belonging to each deployment and in events see reason for no Pods running.

# Debug
## Creating infrastructure using CLI

```bash
az bicep install
az bicep build -f maintemplate.bicep --stdout 
az bicep build -f maintemplate.bicep
az group create -n aks-demo -l westeurope
az deployment group create -g aks-demo --template-file maintemplate.json --parameters @maintemplate.parameters.json

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
az aks pod-identity add -g $rg \
    --cluster-name aks-demo \
    --namespace default \
    --name psql-user \
    --identity-resource-id $(az identity show -n psqlUser -g $rg --query id -o tsv)
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
az deployment group create -g aks-demo --template-file infra/services.json \
    --parameters userObjectId=$(az ad user show --id $(az account show --query user.name -o tsv) --query objectId -o tsv) \
    --parameters userName=$(az account show --query user.name -o tsv) \
    --parameters localUser=tomas \
    --parameters password=Azure12345678 \
    --parameters subnetId=$(az network vnet subnet show -n aks-subnet -g aks-demo --vnet-name aks-demo-net --query id -o tsv) \
    --parameters privateDnsPsqlId=/subscriptions/a0f4a733-4fce-4d49-b8a8-d30541fc1b45/resourceGroups/aks-demo/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com


## Destroy
```bash
export keyvault=$(az deployment group show -n main -g aks-demo --query properties.outputs.keyvaultName.value -o tsv)
az keyvault delete -g $rg -n $keyvault 
az keyvault purge -n $keyvault 
az cognitiveservices account delete -n 5jl6tmwrp3lkm -g aks-demo
az cognitiveservices account purge -n 5jl6tmwrp3lkm -l westeurope -g aks-demo
az group delete -n aks-demo -y --no-wait
```




