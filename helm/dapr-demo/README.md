helm upgrade -i dapr-demo . \
    --set keyvaultName=kv-5jl6tmwrp3lkm \
    --set keyvaultIdentity=d1009857-0905-4b81-a84e-aac703187a6a \
    --set tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47 \
    --set providerimage=tkubica/twitter-provider:1 \
    --set processorimage=tkubica/twitter-processor:1 \
    --set viewerimage=tkubica/twitter-viewer:1