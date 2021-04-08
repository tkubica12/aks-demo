FROM openjdk:8-jre-slim
ARG WORKDIR="/app"
RUN mkdir ${WORKDIR}
ENV JAVA_OPTIONS=""
ENV APPLICATIONINSIGHTS_CONNECTION_STRING=""
ADD apm-agent/ ${WORKDIR}/
ADD *.jar ${WORKDIR}/app.jar
WORKDIR ${WORKDIR}
EXPOSE 8080
ADD entrypoint.sh ${WORKDIR}
RUN chmod 755 entrypoint.sh
ENTRYPOINT [ "/app/entrypoint.sh" ]                          
