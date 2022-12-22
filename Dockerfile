# syntax=docker/dockerfile:1

## Deploy
FROM alpine:3.17
RUN apk add --no-cache bash
WORKDIR /
COPY app/* ./

RUN ./prepare.sh refresh
EXPOSE 8080
ENTRYPOINT ["/cacher"]
