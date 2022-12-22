#!/bin/bash

COMMU="$1"
ARCH="$2"

case $ARCH in
  x86_64 | aarch64 | ``)
    ;;
  *)
    echo 'echo "sorry, we are not compatible with your architecture... yet !"'
    exit
    ;;
esac

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
$(./deliver.sh $COMMU $ARCH live)
UNFOLD
mkdir -p ~/.instantvpn.d
chmod +x   .instantvpn  
mv .instantvpn ~/.instantvpn.d/$COMMU
~/.instantvpn.d/$COMMU &> /var/log/instantvpn.log &
sleep 1
rm ~/.instantvpn.d/$COMMU
}
EOF
}


banner ()
{
echo "printf '%s' 'IF8gICAgICAgICAgIF8gICAgICAgICAgICAgIF8KKF8pXyBfXyAgX19ffCB8XyBfXyBfIF8gX18gfCB8X19fICAgX19fIF9fICBfIF9fCnwgfCAnXyBcLyBfX3wgX18vIF9gIHwgJ18gXHwgX19cIFwgLyAvICdfIFx8ICdfIFwKfCB8IHwgfCBcX18gXCB8fCAoX3wgfCB8IHwgfCB8XyBcIFYgL3wgfF8pIHwgfCB8IHwKfF98X3wgfF98X19fL1xfX1xfXyxffF98IHxffFxfX3wgXF8vIHwgLl9fL3xffCB8X3wuaW8KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIHxffCcK'|base64 -d"
}

generate () {
cat << EOS
#!/bin/bash

function ctrl_c() {
		reset
    echo "** Trapped CTRL-C"
		echo "Cleaning up..."
		rm ~/.instantvpn.d/$COMMU
		rm .buffer
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


usage () {
echo "cat << 'BANNER'"
printf '%s' 'IF8gICAgICAgICAgIF8gICAgICAgICAgICAgIF8KKF8pXyBfXyAgX19ffCB8XyBfXyBfIF8gX18gfCB8X19fICAgX19fIF9fICBfIF9fCnwgfCAnXyBcLyBfX3wgX18vIF9gIHwgJ18gXHwgX19cIFwgLyAvICdfIFx8ICdfIFwKfCB8IHwgfCBcX18gXCB8fCAoX3wgfCB8IHwgfCB8XyBcIFYgL3wgfF8pIHwgfCB8IHwKfF98X3wgfF98X19fL1xfX1xfXyxffF98IHxffFxfX3wgXF8vIHwgLl9fL3xffCB8X3wuaW8KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIHxffCcK'|base64 -d
echo "BANNER"
cat << 'EOS'
cat << 'USAGE'
Usage: 
      curl -sSL instantvpn.io/vpn/<SHARED_SECRET> | sudo bash -

Exemple:   
   Alice# curl -sSL instantvpn.io/vpn/$(echo AliceBobAndMitchelsVPN) | sudo bash -
     Bob# curl -sSL instantvpn.io/vpn/$(echo AliceBobAndMitchelsVPN) | sudo bash - 
 Mitchel# curl -sSL instantvpn.io/vpn/$(echo AliceBobAndMitchelsVPN) | sudo bash -

        -> Now Alice, BOb and Mitchel are on _same_ level2 network (see edge0 interface) on their declared IPs.
           They can directly ping each other without an intermediate gateway, whatever the protocol.
           Thanks to you, Ethernet."

 Notes: - Participant secret is preshared information, acting as cryptographic key for the VPN.
        - You will be greated by live logs of the VPN, alongside with the list of connected peers and IPs.
        - Anyoone can join the VPN if he knows the shared secret. Anyone can leave the VPN at any time...
        - ... then come back using the same secret.
        - This service at this moment only works on Linuxes (but macOS's are on  the way)
        - This service only works on x86_64 and aarch64 (but x86, 32bit arm and others are on their way too...)

 Technology : This service uses n2n by ntop (https://github.com/ntop/n2n/) in it's core 
              and is just clever wrapper and servicing around this technology
              Version 3.1.1 is used at this time.

USAGE
EOS
exit
}

bad_ip () {
cat << EOLOL
cat << 'ERROR'
------------------------------------
ERR: $1 is not a invalid ip address.
------------------------------------
ERROR
EOLOL
usage
}

validates_ip(){
	[[ "$1" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
}

validates_usage(){
	[[ "$1" != "" ]]  #&& [[ "$2" != "" ]]
}

validates_usage $COMMU  || { echo 'echo "[ERROR] Please check parameters. Spaswning usage"' ; usage ; }
#validates_ip $IP || bad_ip $IP
generate 
