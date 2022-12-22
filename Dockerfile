# syntax=docker/dockerfile:1

## Build
FROM golang:1.16-buster AS build
WORKDIR /app
COPY app/go.mod ./
COPY app/go.sum ./
RUN go mod download
COPY app/*.go ./
RUN go build -v -tags netgo -ldflags "-extldflags=-static" -o /omni

## Deploy
FROM alpine:3.17
RUN apk add --no-cache bash
WORKDIR /
COPY --from=build /omni /omni
COPY app/* ./

ARG make_cache
ENV do_cache=$make_cache

RUN ./prepare.sh
EXPOSE 8080
ENTRYPOINT ["/omni"]
