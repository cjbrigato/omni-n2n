#!/bin/bash

COMMU="$1"
ARCH="$2"

validates_arch(){
    [[ "$1" == "x86_64" ]] || [[ "$1" == "aarch64" ]]
}

validates_arch $ARCH || { echo "400::Unsupported architecture '$ARCH'"; exit 1;}
FILENAME_EMBEDED="$(./deliver.sh $COMMU $ARCH binary | sed 's,\.gz,,g')"
echo "200::$FILENAME_EMBEDED"