#!/bin/bash

COMMU="$1"
ARCH="$2"
MODE="$3"
FILENAME_SUFFIX="$COMMU-$ARCH"
if [[ "$ARCH" == "aarch64" ]]; then
    FILENAME_SUFFIX="arg0-$ARCH"
fi
FILENAME="instantvpn-$FILENAME_SUFFIX"

compile() {

    c=$1
    a=$2
    filename=instantvpn-$c-$a
    if [ -f "/toolchains/build/bin/$filename" ]; then
         :
    else
        mkdir -p /toolchains/build/bin/
        cd /toolchains/build/
        cp /instantvpn.c /toolchains/build/$filename.c
        /toolchains/gcc/$a -DINSTANT_COMMUNITY=$c -g -O2 -I ./include -Wall -c -o $filename.o $filename.c &>/dev/null
        /toolchains/gcc/$a -DINSTANT_COMMUNITY=$c --static -L .  $filename.o libn2n-$a.a  -ln2n-$a -lc -o /toolchains/build/bin/$filename &>/dev/null
        /toolchains/gcc/strip-$a /toolchains/build/bin/$filename
        gzip -k -9 /toolchains/build/bin/$filename
    fi 
}



exec 3>&1 1>.compiled_$FILENAME.log

if [ "$FILENAME" != "arg0-$ARCH" ]; then
    compile $COMMU $ARCH
fi

exec 1>&3 3>&-

if [[ "$MODE" == "live" ]]; then
    base64 /toolchains/build/bin/$FILENAME.gz
else
    /generate.sh $COMMU $ARCH live > /toolchains/build/bin/generated_vpn-$COMMU-$ARCH
    echo -n "/toolchains/build/bin/generated_vpn-$COMMU-$ARCH"
fi