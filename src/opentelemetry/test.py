import os
import flask
import requests
import time
import random

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleExportSpanProcessor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.pymysql import PyMySQLInstrumentor
from azure.monitor.opentelemetry.exporter import AzureMonitorTraceExporter

# Gather configurations
if os.getenv('APPINSIGHTS_INSTRUMENTATIONKEY_PATH'):
    with open (os.getenv('APPINSIGHTS_INSTRUMENTATIONKEY_PATH'), "r") as myfile:
        appInsightsConnectionString = "InstrumentationKey=%s" % myfile.readline()
else:
    appInsightsConnectionString = "InstrumentationKey=%s" % os.getenv('APPINSIGHTS_INSTRUMENTATIONKEY')

mySqlHost = os.getenv('MYSQL_HOST')
mySqlPassword = os.getenv('MYSQL_PASSWORD')
mySqlUsername = os.getenv('MYSQL_USERNAME')

exporter = AzureMonitorTraceExporter(
    connection_string = appInsightsConnectionString
)

# exporter.add_telemetry_processor(azure_monitor_metadata)

trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)
span_processor = SimpleExportSpanProcessor(exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Exporter metadata configuration
def azure_monitor_metadata(envelope):
    envelope.tags['ai.cloud.role'] = os.getenv('APP_NAME')
    envelope.data.base_data.properties['app_version'] = os.getenv('APP_VERSION')
    envelope.data.base_data.properties['kube_pod_name'] = os.getenv('POD_NAME')
    envelope.data.base_data.properties['kube_node_name'] = os.getenv('NODE_NAME')
    envelope.data.base_data.properties['kube_namespace'] = os.getenv('POD_NAMESPACE')
    envelope.data.base_data.properties['kube_cpu_limit'] = os.getenv('CPU_LIMIT')
    envelope.data.base_data.properties['kube_memory_limit'] = os.getenv('MEMORY_LIMIT')
    # Read labels
    f = open("/podinfo/labels")
    for line in f:
        key,value = line.partition("=")[::2]
        envelope.data.base_data.properties['labels.%s' % key] = value.replace('"', '')
    return True

# Create Flask object
app = flask.Flask(__name__)

# Add automatic instrumentation
RequestsInstrumentor().instrument()
FlaskInstrumentor().instrument_app(app)
PyMySQLInstrumentor().instrument()

# Flask routing
@app.route('/')
def init():
    trace.get_current_span().set_attribute("order_id", "00123456")
    response = requests.get(os.getenv('REMOTE_ENDPOINT', default="http://127.0.0.1:8080/data"))
    return "Response from data API: %s" % response.content.decode("utf-8") 

@app.route('/data')
def data():
    # Custom span
    with tracer.start_as_current_span(name="processData"):
        result = processData()
    return result

# Processing
def processData():
    time.sleep(0.2)
    randomNumber = int(random.random()*100)
    try:
        conn.cursor().execute("insert into mytable values (%d)" % randomNumber)
        conn.commit()
    except Exception as e:
        print("Exeception occured:{}".format(e))
    return "Your integer is %d" % randomNumber

# Run Flask
app.run(host='0.0.0.0', port=8080, threaded=True)