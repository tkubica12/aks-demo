helm upgrade -i dapr-demo . \
    --set keyvaultName=kv-5jl6tmwrp3lkm \
    --set clientId=2577f16a-83af-40fc-931d-fe14f34b63a9 \
    --set providerimage=tkubica/twitter-provider:1 \
    --set processorimage=tkubica/twitter-processor:1 \
    --set viewerimage=tkubica/twitter-viewer:1


curl http://localhost:3500/v1.0/secrets/azurekeyvault/cs-endpoint