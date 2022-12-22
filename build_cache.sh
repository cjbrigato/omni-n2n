#!/bin/bash

rm app/toolchains.tar.gz
docker build --build-arg make_cache=refresh -t omni-cache .
docker run  --name omnicache --entrypoint /bin/true omni-cache
CACHID=$(docker ps -a|grep omnicache | cut -d' ' -f1)
docker cp -a $CACHID:/toolchains.tar.gz app/
docker rm $CACHID
