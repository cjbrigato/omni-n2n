#!/bin/sh
set -e
#########################
apk add --no-cache gcc make autoconf automake bash vim file musl-dev musl-utils linux-headers wget busybox
mkdir -p /cache

if [ "$1" != "refresh" ]
then
set +e
if wget "https://ivpncacher-3p5yay54aq-ew.a.run.app/toolchains.tar.gz" -O /toolchains.tar.gz
then 
    echo "Using cache"
    tar -xvf /toolchains.tar.gz -C /
    rm /go.mod /go.sum /main.go
    rm /prepare.sh
    exit 0
fi
set -e
fi 

echo "Refreshing cache..."

#################
mkdir /toolchains
cd /toolchains
mkdir gcc
mkdir build
mkdir prebuild  
mkdir artifacts
mkdir product
#############
cd /toolchains/gcc
wget "http://musl.cc/aarch64-linux-musl-cross.tgz"
tar -xvf aarch64-linux-musl-cross.tgz
rm aarch64-linux-musl-cross.tgz

ln -s /toolchains/gcc/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc aarch64
ln -s /toolchains/gcc/aarch64-linux-musl-cross/bin/aarch64-linux-musl-strip strip-aarch64
ln -s $(which gcc) x86_64
ln -s $(which strip) strip-x86_64

cd /toolchains
###############
wget "https://github.com/ntop/n2n/archive/refs/tags/3.1.1.tar.gz"
tar -xvf 3.1.1.tar.gz
rm 3.1.1.tar.gz
mv n2n-3.1.1 prebuild
cd prebuild
ln -s n2n-3.1.1 n2n

cd n2n
./autogen.sh
###############
make clean || true 
export CC=/toolchains/gcc/aarch64  LD=/toolchains/gcc/aarch64
./configure --host CFLAGS=-static CXXFLAGS=-static LDFLAGS="--static"
make -j4
cp libn2n.a  /toolchains/artifacts/libn2n-aarch64.a 
cp edge /toolchains/artifacts/edge-aarch64
/toolchains/gcc/strip-aarch64  /toolchains/artifacts/edge-aarch64
cp supernode /toolchains/artifacts/supernode-aarch64
/toolchains/gcc/strip-aarch64  /toolchains/artifacts/supernode-aarch64

make clean || true 
export CC=/toolchains/gcc/x86_64  LD=/toolchains/gcc/x86_64
./configure --host CFLAGS=-static CXXFLAGS=-static LDFLAGS="--static"
make -j4
cp libn2n.a  /toolchains/artifacts/libn2n-x86_64.a 
cp edge /toolchains/artifacts/edge-x86_64
/toolchains/gcc/strip-x86_64  /toolchains/artifacts/edge-x86_64
cp supernode /toolchains/artifacts/supernode-x86_64
/toolchains/gcc/strip-x86_64  /toolchains/artifacts/supernode-x86_64
##############
ln -s /toolchains/prebuild/n2n/include /toolchains/build/include
sed -i 's/edge0/ivpni0/g' /toolchains/build/include/n2n_define.h
ln -s  /toolchains/artifacts/libn2n-aarch64.a /toolchains/build/libn2n-aarch64.a
ln -s  /toolchains/artifacts/libn2n-x86_64.a /toolchains/build/libn2n-x86_64.a
##############
cd /toolchains/build/
cp /instantvpn.c /toolchains/build/instantvpn.c
/toolchains/gcc/aarch64 -DARG0_COMMUNITY -g -O2 -I ./include -Wall -c -o instantvpn-arg0-aarch64.o instantvpn.c
/toolchains/gcc/aarch64 -DARG0_COMMUNITY --static -L .  instantvpn-arg0-aarch64.o libn2n-aarch64.a  -ln2n-aarch64 -lc -o instantvpn-arg0-aarch64
/toolchains/gcc/strip-aarch64 instantvpn-arg0-aarch64
##############
mkdir -p /toolchains/build/bin/
cp instantvpn-arg0-aarch64 /toolchains/build/bin/instantvpn-arg0-aarch64
gzip -k -9 /toolchains/build/bin/instantvpn-arg0-aarch64
cp /toolchains/artifacts/edge-x86_64 /toolchains/build/bin/edge-x86_64
gzip -k -9 /toolchains/build/bin/edge-x86_64
cp /toolchains/artifacts/edge-aarch64 /toolchains/build/bin/edge-aarch64 
gzip -k -9 /toolchains/build/bin/edge-aarch64 

cd /
tar -cvzf toolchains.tar.gz toolchains/
mv toolchains.tar.gz /cache/

rm /go.mod /go.sum /main.go
rm /prepare.sh



