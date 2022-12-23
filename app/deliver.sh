#!/bin/bash

COMMU="$1"
ARCH="$2"
MODE="$3"

case $MODE in
  compiled)
    FILENAME=$(/make_compiled.sh $COMMU $ARCH)
    base64 $FILENAME
    ;;
  script)
    FILENAME=$(/make_script.sh $COMMU $ARCH)
    cat $FILENAME
    ;;
  standalone)
    FILENAME=$(/make_standalone.sh $COMMU $ARCH)
    echo -n $FILENAME
    ;;
  *)
    echo 'echo "sorry, we are not compatible with your mode... yet !"'
    exit
    ;;
esac