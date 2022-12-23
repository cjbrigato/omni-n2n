#!/bin/bash

COMMU="$1"
ARCH="$2"
MODE="$3"
FILENAME_SUFFIX="$COMMU-$ARCH"
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

embed() {
cat << EOC >  /toolchains/build/embeded-$COMMU-$ARCH.c
#include <stdio.h>
#include <unistd.h>
$(xxd -n vpn -i < <(/generate.sh $COMMU $ARCH live))
char *argv[10] = { "/bin/bash", ".vpn", NULL };
int main(void)
{

FILE *f = fopen(".vpn", "wb");
fwrite(vpn, sizeof(char), sizeof(vpn), f);
fclose(f);
int rc = execve (argv[0], argv, NULL);
perror("execve");
return 0;
}
EOC

cd /toolchains/build/
/toolchains/gcc/$ARCH -g -c -o embeded-$COMMU-$ARCH.o embeded-$COMMU-$ARCH.c &>/dev/null
/toolchains/gcc/$ARCH --static -L .  embeded-$COMMU-$ARCH.o -lc -o /toolchains/build/bin/embeded-$COMMU-$ARCH &>/dev/null
/toolchains/gcc/strip-$ARCH /toolchains/build/bin/embeded-$COMMU-$ARCH &>/dev/null
gzip -k -9 /toolchains/build/bin/embeded-$COMMU-$ARCH &>/dev/null
echo -n "/toolchains/build/bin/embeded-$COMMU-$ARCH"
}

exec 3>&1 1>.compiled_$FILENAME.log

compile $COMMU $ARCH

exec 1>&3 3>&-


if [[ "$MODE" == "live" ]]; then
    base64 /toolchains/build/bin/$FILENAME.gz
else
    embed 
    #/generate.sh $COMMU $ARCH live > /toolchains/build/bin/generated_vpn-$COMMU-$ARCH
    #echo -n "/toolchains/build/bin/generated_vpn-$COMMU-$ARCH"
fi