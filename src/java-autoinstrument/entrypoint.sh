#!/bin/sh
export APPLICATIONINSIGHTS_CONNECTION_STRING=$(cat $APPLICATIONINSIGHTS_CONNECTION_STRING_PATH)
exec java ${JAVA_OPTIONS} -javaagent:applicationinsights-agent-3.0.2.jar -jar app.jar   ${@}