FROM alpine:3.21.3

RUN apk update \
    && apk add --no-cache squid=6.6-r0 \
    && apk add --no-cache curl=8.5.0-r0

COPY start-squid.sh /usr/local/bin/
COPY ./config/squid.conf /etc/squid/

ENTRYPOINT ["/usr/local/bin/start-squid.sh"]
