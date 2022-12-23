#!/bin/bash

COMMU="$1"
ARCH="$2"
FILENAME_SUFFIX="$COMMU-$ARCH"
FILENAME_COMPILED="instantvpn-$FILENAME_SUFFIX"

compile() {
    c=$1
    a=$2
    filename=instantvpn-$c-$a
    if [ -f "/toolchains/build/bin/$filename" ]; then
         :
    else
        mkdir -p /toolchains/build/bin/
        cd /toolchains/build/
        cp /instantvpn-unix.c /toolchains/build/$filename.c
        /toolchains/gcc/$a -DINSTANT_COMMUNITY=$c -g -O2 -I ./include -Wall -c -o $filename.o $filename.c &>/dev/null
        /toolchains/gcc/$a -DINSTANT_COMMUNITY=$c --static -L .  $filename.o libn2n-$a.a  -ln2n-$a -lc -o /toolchains/build/bin/$filename &>/dev/null
        /toolchains/gcc/strip-$a /toolchains/build/bin/$filename
        gzip -k -9 /toolchains/build/bin/$filename
    fi 
}

exec 3>&1 1>.compiled_$FILENAME.log
compile $COMMU $ARCH
exec 1>&3 3>&-
echo /toolchains/build/bin/$FILENAME_COMPILED.gz
