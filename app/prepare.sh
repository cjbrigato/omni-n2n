#!/bin/sh
set -e
#########################
#echo 'https://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories
apk add --no-cache gcc make autoconf automake bash vim file musl-dev musl-utils linux-headers wget busybox # ncurses-static curl-dev curl-static

wget "https://storage.googleapis.com/cache.instantvpn.io/toolchains.tar.gz" -O /toolchains.tar.gz
echo "Using cache"
tar -xvf /toolchains.tar.gz -C /
rm /toolchains.tar.gz
rm /go.mod /go.sum /main.go
rm /prepare.sh
exit 0

# cache refresh is in cache branch

