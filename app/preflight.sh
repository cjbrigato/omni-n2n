#!/bin/bash

is_dev (){
  [[ $APP_ENV == "dev" ]]
}

BASEURL="instantvpn.io"
is_dev && BASEURL="localhost:8080"

eoarch () {
{ cat << 'EOARCH'
ARCH=$(arch)
echo "[INFO] Detected machine architecture : $ARCH"
case $ARCH in
  x86_64 | aarch64)
    echo "[INFO] This architecture is supported. Going Forward..."
    ;;
  *)
    echo "[FATAL] sorry, we are not compatible with your architecture... yet !"
    exit 1
    ;;
esac
EOARCH
} | base64 -w0

}

eouid () {
{ cat << 'EOUID'
uid=$(id -u)
if [ $uid -gt 0 ];then
echo "[WARN] This service spawns a tun/tap device and requires root privileges."
echo "[WARN] But we are uid $uid. Trying sudo..."
fi
EOUID
} | base64 -w0
}



echo "source <(base64 -d <<< $(eoarch))"
echo "source <(base64 -d <<< $(eouid))"
cat << EOF




########################################################
# if you can read this, you are misusing the service :
# this service is made to be consumed by a piped bash.
# you should have consumed it like that :
# 
# curl -sSL instantvpn.io$1 | bash -
#
########################################################

# this page is only there to make a "302 if piped to shell" effect :
# and also to do some preflight checks, alongside with ensuring we're suid 0
# We check shell (we need bash, yeah),  we check for OS, architecture, etc.
# The SUID 0 is necessary because that's a vpn, so we have to spawn a tap device.
# Operation that need such uid.
#
# if you were piping to shell, you would have been "redirected" by the next 
# statement seemlessly. But you are reading this so... :)
#
# But anyway thats always good practice to check what we are piping to
# our shells... 
#
# so lets explain a bit:
#
# this page is only there to make a "302 if piped to shell" effect :
# and also to do some preflight checks, alongside with ensuring we're suid 0
# We check shell (we need bash, yeah),  we check for OS, architecture, etc.
# The SUID 0 is necessary because that's a vpn, so we have to spawn a tap device.
# Operation that need such uid
#
# Oh and you cannot see it, but this also programatically change URLS depending on
# environment, to ease local development
#

##########################################################
# if you can read this, you are misusing the service :
# this service is made to be consumed by a piped bash.
# you should have consumed it like that :
# 
# curl -sSL instantvpn.io$1 | bash -    
##########################################################

EOF
url(){
echo "curl -sSL $BASEURL/shell${1}/\$(arch) | sudo bash -" | base64 -w0
}
echo "source <(base64 -d <<< $(url $1))"


#cat << 'EOARCH'
#ARCH=$(arch)
#echo "[INFO] Detected machine architecture : $ARCH"
#case $ARCH in
#  x86_64 | aarch64)
#    echo "[INFO] This architecture is supported. Going Forward..."
#    ;;
#  *) 
#    echo "[FATAL] sorry, we are not compatible with your architecture... yet !"
#    exit 1
#    ;;
#esac
#EOARCH

#cat << 'EOUID'
#uid=$(id -u)
#if [ $uid -gt 0 ];then
#echo "[WARN] This service spawns a tun/tap device and requires root privileges."
#echo "[WARN] But we are uid $uid. Trying sudo..."
#fi
#EOUID

