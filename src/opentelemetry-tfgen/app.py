from azure.monitor.opentelemetry.exporter import AzureMonitorTraceExporter
from opentelemetry import trace
# from opentelemetry import metrics
# from opentelemetry.sdk.metrics import Counter, MeterProvider
# from opentelemetry.sdk.metrics.export.controller import PushController
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.requests import RequestsInstrumentor
import time
import random
import socket
import os
import requests

# Setup distributed tracing
if os.getenv('APPINSIGHTS_INSTRUMENTATIONKEY_PATH'):
    with open (os.getenv('APPINSIGHTS_INSTRUMENTATIONKEY_PATH'), "r") as myfile:
        appInsightsConnectionString = "InstrumentationKey=%s" % myfile.readline()
else:
    appInsightsConnectionString = "InstrumentationKey=%s" % os.getenv('APPINSIGHTS_INSTRUMENTATIONKEY')

exporter = AzureMonitorTraceExporter(
    connection_string = appInsightsConnectionString
)

trace.set_tracer_provider(TracerProvider(
    resource=Resource.create({
            "service.name": os.getenv('APP_NAME'),
            "service.instance.id": os.getenv('POD_NAME'),
            "service.version": os.getenv('APP_VERSION'),
            "service.namespace": os.getenv('POD_NAMESPACE'),
            "k8s.namespace": os.getenv('POD_NAMESPACE'),
            "k8s.node.name": os.getenv('NODE_NAME'),
            "k8s.pod.name": os.getenv('POD_NAME')
        })
))
tracer = trace.get_tracer(__name__)
span_processor = BatchSpanProcessor(exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

RequestsInstrumentor().instrument()

# Setup metrics
# metrics_exporter = AzureMonitorMetricsExporter(
#     instrumentation_key = os.environ['APPINSIGHTS_INSTRUMENTATION_KEY']
# )
# metrics.set_meter_provider(MeterProvider())
# meter = metrics.get_meter(__name__)
# PushController(meter, metrics_exporter, 10)

# tfgen_counter = meter.create_metric(
#     name="tfgen_counter",
#     description="mydemo namespace",
#     unit="1",
#     value_type=int,
#     metric_type=Counter,
# )

# trace_exporter.add_telemetry_processor(callback_function)
# metrics_exporter.add_telemetry_processor(callback_function)

while True:
    # tfgen_counter.add(1, {"destination": "endpoint1"})
    requests.get(os.getenv('REMOTE_ENDPOINT1'))
    time.sleep(random.random()*60)
    # tfgen_counter.add(1, {"destination": "endpoint2"})
    requests.get(os.getenv('REMOTE_ENDPOINT2'))
    time.sleep(random.random()*60)
    requests.get(os.getenv('REMOTE_ENDPOINT3'))
    time.sleep(random.random()*60)
