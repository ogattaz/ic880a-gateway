#!/bin/bash

# Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

VERSION="spi"
if [[ $1 != "" ]]; then VERSION=$1; fi

echo "+++ The Lora-Net Gateway installer"
echo "+++ Version $VERSION"

# Update the gateway installer to the correct branch
echo "+++ Updating installer files..."
OLD_HEAD=$(git rev-parse HEAD)
git fetch
git checkout -q $VERSION
git pull
NEW_HEAD=$(git rev-parse HEAD)

if [[ $OLD_HEAD != $NEW_HEAD ]]; then
    echo "    New installer found. Restarting process..."
    exec "./install.sh" "$VERSION"
fi

# Request gateway configuration data
# There are two ways to do it, manually specify everything
# or rely on the gateway EUI and retrieve settings files from remote (recommended)
echo "+++ Gateway configuration:"

echo "    Try to get gateway ID from MAC address"
echo "    First try eth0, if that does not exist, try wlan0 (for RPi Zero)"
GATEWAY_EUI_NIC="eth0"
if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
    GATEWAY_EUI_NIC="wlan0"
fi

if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
    echo "ERROR: No network interface found. Cannot set gateway ID."
    exit 1
fi

GATEWAY_EUI=$(ip link show $GATEWAY_EUI_NIC | awk '/ether/ {print $2}' | awk -F\: '{print $1$2$3"FFFE"$4$5$6}')
GATEWAY_EUI=${GATEWAY_EUI^^} # toupper

echo "+++ Detected EUI $GATEWAY_EUI from $GATEWAY_EUI_NIC"

#read -r -p "Do you want to use remote settings file? [y/N]" response
#response=${response,,} # tolower

echo "+++ Doesn't use remote setting file !"
response=no


if [[ $response =~ ^(yes|y) ]]; then
    NEW_HOSTNAME="loranet-gateway"
    REMOTE_CONFIG=true
else
    printf "       Host name [loranet-gateway]:"
    read NEW_HOSTNAME
    if [[ $NEW_HOSTNAME == "" ]]; then NEW_HOSTNAME="loranet-gateway"; fi

    printf "       Descriptive name [loranet-ic880a]:"
    read GATEWAY_NAME
    if [[ $GATEWAY_NAME == "" ]]; then GATEWAY_NAME="loranet-ic880a"; fi

    printf "       Contact email: "
    read GATEWAY_EMAIL

    printf "       Latitude [45.206773 ]: "
    read GATEWAY_LAT
    if [[ $GATEWAY_LAT == "" ]]; then GATEWAY_LAT=45.206773    ; fi
       
    printf "       Longitude [5.781474]: "
    read GATEWAY_LON
    if [[ $GATEWAY_LON == "" ]]; then GATEWAY_LON=5.781474 ; fi

    printf "       Altitude [220]: "
    read GATEWAY_ALT
    if [[ $GATEWAY_ALT == "" ]]; then GATEWAY_ALT=220; fi
fi


echo "+++ Change hostname if needed"
CURRENT_HOSTNAME=$(hostname)

if [[ $NEW_HOSTNAME != $CURRENT_HOSTNAME ]]; then
    echo "+++ Updating hostname to '$NEW_HOSTNAME'..."
    hostname $NEW_HOSTNAME
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/" /etc/hosts
else
    echo "+++ No updating of hostname is needed"
fi


echo "+++ Build INSTALL_DIR ****************************************************************************************"

INSTALL_DIR="/opt/loranet-gateway"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi
pushd $INSTALL_DIR

echo  "+++ Install dir:" `pwd` 

# Remove WiringPi built from source (older installer versions)
if [ -d wiringPi ]; then
    pushd wiringPi
    ./build uninstall
    popd
    rm -rf wiringPi
fi 



echo "+++ Build libraries ****************************************************************************************"
echo "+++ Current dir:" `pwd` 

if [ ! -d libmpsse ]; then
    git clone https://github.com/devttys0/libmpsse.git
    pushd libmpsse/src
else
    pushd libmpsse/src
    git reset --hard
    git pull
fi

./configure --disable-python
make
make install
ldconfig

popd

echo "+++ Build LoRa gateway app ****************************************************************************************"
echo "+++ Current dir:" `pwd` 

if [ ! -d lora_gateway ]; then
    git clone https://github.com/Lora-net/lora_gateway.git
    pushd lora_gateway
else
    pushd lora_gateway
    git reset --hard
    git pull
fi

echo "+++ Set PLATFORM to [imst_rpi]"
sed -i -e 's/PLATFORM= kerlink/PLATFORM= imst_rpi/g' ./libloragw/library.cfg

make

popd

echo "+++ Build packet forwarder ****************************************************************************************"
echo "+++ Current dir:" `pwd` 

if [ ! -d packet_forwarder ]; then
    git clone https://github.com/Lora-net/packet_forwarder.git
    pushd packet_forwarder
else
    pushd packet_forwarder
    git pull
    git reset --hard
fi

make

popd

echo "+++ Build bin dir ****************************************************************************************"
echo "+++ Current dir:" `pwd` 


echo "+++ Create ./bin dir if if doesn't exist"
if [ ! -d bin ]; then mkdir bin; fi

echo "+++ Remove [lora_pkt_fwd] symlink if it already exists"
if [ -f ./bin/lora_pkt_fwd ]; then rm ./bin/lora_pkt_fwd; fi

echo "+++ Create [lora_pkt_fwd] symlink"
ln -s "$INSTALL_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd" "$INSTALL_DIR/bin/lora_pkt_fwd"

echo "++++ Copy [global_conf.json]"
cp -f ./packet_forwarder/lora_pkt_fwd/global_conf.json ./bin/global_conf.json


echo "+++ Build local_conf ****************************************************************************************"
echo "+++ Current dir:" `pwd` 

LOCAL_CONFIG_FILE=$INSTALL_DIR/bin/local_conf.json

echo "+++ Remove old config file"
if [ -e $LOCAL_CONFIG_FILE ]; then rm $LOCAL_CONFIG_FILE; fi;

if [ "$REMOTE_CONFIG" = true ] ; then
    # Get remote configuration repo
    if [ ! -d gateway-remote-config ]; then
        git clone https://github.com/loranet-zh/gateway-remote-config.git
        pushd gateway-remote-config
    else
        pushd gateway-remote-config
        git pull
        git reset --hard
    fi

    ln -s $INSTALL_DIR/gateway-remote-config/$GATEWAY_EUI.json $LOCAL_CONFIG_FILE

    popd
else
	echo "+++ Create config file."
    echo -e "{\n\t\"gateway_conf\": {\n\t\t\"gateway_ID\": \"$GATEWAY_EUI\",\n\t\t\"servers\": [ { \"server_address\": \"localhost\", \"serv_port_up\": 1680, \"serv_port_down\": 1680, \"serv_enabled\": true } ],\n\t\t\"ref_latitude\": $GATEWAY_LAT,\n\t\t\"ref_longitude\": $GATEWAY_LON,\n\t\t\"ref_altitude\": $GATEWAY_ALT,\n\t\t\"contact_email\": \"$GATEWAY_EMAIL\",\n\t\t\"description\": \"$GATEWAY_NAME\" \n\t}\n}" >$LOCAL_CONFIG_FILE
	
	echo "+++ Dump new config file:"
	cat $LOCAL_CONFIG_FILE
fi

popd

echo "+++ Build service ****************************************************************************************"
echo  "+++ Current dir:" `pwd` 


echo "+++ Copy packet forwarder start shell in [./bin] dir"
cp ./start.sh $INSTALL_DIR/bin/
echo "+++ Copy packet forwarder service definition [loranet-gateway.service] in systemd folder"
cp ./loranet-gateway.service /lib/systemd/system/
echo "+++ Enable packet forwarder service"
systemctl enable loranet-gateway.service

echo
echo "+++ Installation completed ****************************************************************************************"
echo
echo "+++ Gateway EUI is: $GATEWAY_EUI"
echo "+++ The hostname is: $NEW_HOSTNAME"
echo
echo "+++ The system will reboot in 5 seconds..."
sleep 5
shutdown -r now
