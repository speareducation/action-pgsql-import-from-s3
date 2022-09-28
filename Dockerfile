FROM spear/pipeline:latest
RUN apk add postgresql-client
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
