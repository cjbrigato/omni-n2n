#!/bin/bash


COMMU="$1"
KEY="$(echo $COMMU | base64)"
ARCH="$2"
FILENAME="$COMMU.$ARCH"
MACADDR="$(hexdump -n4 -e'/4 "38-11" 4/1 "-%02X"' /dev/random)"

exec 3>&1 1>.compiled_$FILENAME.log

#set_tap_name() {
#    sed -i 's/edge0/ivpni0/g' /toolchains/build/include/n2n_define.h
    #define N2N_EDGE_DEFAULT_DEV_NAME    "edge0"
    #TODO Calculate interface name from previous interface name (ivpni0 -> ivpni1 -> ivpni2 -> ...)

    # IFACE=($(ip link show | awk '/^[0-9]+:/ { print $2 }' | tr -d :|grep ivpni|sort|tail -n1))
    # NUMBER=$(echo "$IFACE" | sed 's/[^0-9]*//g')
    # NEW_NUMBER=$((NUMBER + 1))
    # NEW_NAME=$(echo "$IFACE" | sed "s/[0-9]$/$NEW_NUMBER/")
    # sed -i "s/$IFACE/$NEW_NAME/g" /toolchains/build/include/n2n_define.h
#}


compile() {
cd /toolchains/build/
cp /instantvpn.c /toolchains/build/
/toolchains/gcc/$ARCH -g -O2 -I ./include -Wall -c -o $FILENAME.o instantvpn.c &>/dev/null
/toolchains/gcc/$ARCH --static -L .  $FILENAME.o libn2n-$ARCH.a  -ln2n-$ARCH -lc -o $FILENAME.elf &>/dev/null
rm $FILENAME.o
/toolchains/gcc/strip-$ARCH $FILENAME.elf
}


if [[ $ARCH == "aarch64" ]]; then
cp /instantvpn-arg0-aarch64.gz /toolchains/build/$FILENAME.elf.gz
else
{ cat << BB
#ifndef INSTANTVPN_H
#define INSTANTVPN_H
#define INSTANT_COMMUNITY "$COMMU"
#endif
BB

} > /toolchains/build/include/instantvpn.h

compile
gzip -9 /toolchains/build/$FILENAME.elf

fi 
mv /toolchains/build/$FILENAME.elf.gz /

exec 1>&3 3>&-

base64 /$FILENAME.elf.gz
rm /$FILENAME.elf.gz