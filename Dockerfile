FROM alpine:latest
RUN apk add postgresql-client postgresql-bdr-client aws-cli
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
