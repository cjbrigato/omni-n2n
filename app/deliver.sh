#!/bin/bash


COMMU="$1"
ARCH="$2"
MODE="$3"
case $ARCH in
  aarch64)
    COMMU="arg0"
    ;;
  *)
    :
    ;;
esac
FILENAME_SUFFIX="$COMMU-$ARCH"
FILENAME="instantvpn-$FILENAME_SUFFIX"

compile() {
    if [ -f "/toolchains/build/bin/$FILENAME" ]; then
         :
    else
        mkdir -p /toolchains/build/bin/
        cd /toolchains/build/
        cp /instantvpn.c /toolchains/build/$FILENAME.c
        /toolchains/gcc/$ARCH -DINSTANT_COMMUNITY=$COMMU -g -O2 -I ./include -Wall -c -o $FILENAME.o $FILENAME.c &>/dev/null
        /toolchains/gcc/$ARCH -DINSTANT_COMMUNITY=$COMMU --static -L .  $FILENAME.o libn2n-$ARCH.a  -ln2n-$ARCH -lc -o /toolchains/build/bin/$FILENAME &>/dev/null
        /toolchains/gcc/strip-$ARCH /toolchains/build/bin/$FILENAME
        gzip -k -9 /toolchains/build/bin/$FILENAME
    fi 
}



exec 3>&1 1>.compiled_$FILENAME.log

if [ "$COMMU" != "arg0" ]; then
    compile
fi

exec 1>&3 3>&-

if [[ "$MODE" == "live" ]]; then
    base64 /toolchains/build/bin/$FILENAME.gz
else
    echo -n "/toolchains/build/bin/$FILENAME"
fi