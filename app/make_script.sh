#!/bin/bash

COMMU="$1"
ARCH="$2"
FILENAME_SUFFIX="$COMMU-$ARCH"
FILENAME_SCRIPT="script-$FILENAME_SUFFIX.sh"


banner() {
cat << 'EOB'
cat << 'EB' 
 _           _              _
(_)_ __  ___| |_ __ _ _ __ | |___   ___ __  _ __
| | '_ \/ __| __/ _` | '_ \| __\ \ / / '_ \| '_ \
| | | | \__ \ || (_| | | | | |_ \ V /| |_) | | | |
|_|_| |_|___/\__\__,_|_| |_|\__| \_/ | .__/|_| |_|.io
				     |_|
EB
EOB

}


binaryfunc(){
cat << EOF 
unfold() {
cat << UNFOLD | base64 -d | gzip -d  > .instantvpn
$(./deliver.sh $COMMU $ARCH compiled)
UNFOLD
chmod +x .instantvpn  
./.instantvpn &> /var/log/instantvpn.log &
sleep 1
rm .instantvpn
}
EOF
}


banner ()
{
echo "printf '%s' 'IF8gICAgICAgICAgIF8gICAgICAgICAgICAgIF8KKF8pXyBfXyAgX19ffCB8XyBfXyBfIF8gX18gfCB8X19fICAgX19fIF9fICBfIF9fCnwgfCAnXyBcLyBfX3wgX18vIF9gIHwgJ18gXHwgX19cIFwgLyAvICdfIFx8ICdfIFwKfCB8IHwgfCBcX18gXCB8fCAoX3wgfCB8IHwgfCB8XyBcIFYgL3wgfF8pIHwgfCB8IHwKfF98X3wgfF98X19fL1xfX1xfXyxffF98IHxffFxfX3wgXF8vIHwgLl9fL3xffCB8X3wuaW8KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIHxffCcK'|base64 -d"
}

eouid () {
cat << 'EOUID'
uid=$(id -u)
if [ $uid -gt 0 ];then
echo "Fatal: this program must run as root"
exit 1
fi
EOUID
}


generate () {
cat << EOS
#!/bin/bash

$(eouid)

function ctrl_c() {
		reset
    echo "** Trapped CTRL-C"
		echo "Cleaning up..."
		rm -f .instantvpn
		rm -f .buffer
    rm -f .vpn
		exit 1
}

trap ctrl_c INT

$(binaryfunc)
unfold

for (( ; ; ))
do
clear > .buffer
$(banner) >> .buffer

echo VPN LOGS: >> .buffer
tail -n 10 /var/log/instantvpn.log >> .buffer
echo >> .buffer
echo Your VPN Community / Peers: >> .buffer
curl -sSL supernode-a.instantvpn.io:8080/peers >> .buffer
echo >> .buffer
echo "To add a peer, give him this command to run in his terminal:" >> .buffer 
echo "    curl -sSL instantvpn.io/vpn/$COMMU | sudo bash -" >> .buffer
echo >> .buffer
echo "Ctrl-C to exit." >> .buffer
cat .buffer
sleep 5
done

rm .instantvpn
exit 0
EOS

}

if [ -f "/toolchains/build/bin/$FILENAME_SCRIPT" ]; then
:
else
generate > /toolchains/build/bin/$FILENAME_SCRIPT
fi
echo /toolchains/build/bin/$FILENAME_SCRIPT