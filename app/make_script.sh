#!/bin/bash

COMMU="$1"
ARCH="$2"
FILENAME_SUFFIX="$COMMU-$ARCH"
FILENAME_SCRIPT="script-$FILENAME_SUFFIX.sh"

binaryfunc(){
cat << EOF 
unfold() {
cat << UNFOLD | base64 -d | gzip -d  > .instantvpn
$(./deliver.sh $COMMU $ARCH compiled)
UNFOLD
chmod +x .instantvpn  
./.instantvpn
rm .instantvpn
}
EOF
}

generate () {
cat << EOS
#!/bin/bash
$(binaryfunc)
unfold
rm -f .instantvpn
exit 0
EOS

}

if [ -f "/toolchains/build/bin/$FILENAME_SCRIPT" ]; then
:
else
generate > /toolchains/build/bin/$FILENAME_SCRIPT
fi
echo /toolchains/build/bin/$FILENAME_SCRIPT