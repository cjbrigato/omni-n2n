#!/bin/bash

if [[ "$1" != "nobuild" ]];then
docker build --build-arg make_cache=refresh -t omnicache .
fi
rm -f toolchains.tar.gz
docker run  --name omnicache --entrypoint /bin/true omnicache
CACHID=$(docker ps -a|grep omnicache | cut -d' ' -f1)
docker cp -a $CACHID:/cache/toolchains.tar.gz .
docker rm $CACHID
ip=$(curl ifconfig.me)
echo "http://$ip/toolchains.tar.gz"
echo "ctrl+c to exit..."
sudo app/httpd -f -p 80 


