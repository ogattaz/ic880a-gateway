#!/bin/bash

# Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

VERSION="master"
if [[ $1 != "" ]]; then VERSION=$1; fi

echo "The Lora-Net ic880a reference gateway installer"
echo "Version $VERSION"

# Update the gateway installer to the correct branch (defaults to master)
echo "Updating installer files..."
OLD_HEAD=$(git rev-parse HEAD)
git fetch
git checkout -q $VERSION
git pull
NEW_HEAD=$(git rev-parse HEAD)

if [[ $OLD_HEAD != $NEW_HEAD ]]; then
    echo "New installer found. Restarting process..."
    exec "./install.sh" "$VERSION"
fi

# Request gateway configuration data
# There are two ways to do it, manually specify everything
# or rely on the gateway EUI and retrieve settings files from remote (recommended)
echo "Gateway configuration:"

# Try to get gateway ID from MAC address
# First try eth0, if that does not exist, try wlan0 (for RPi Zero)
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

echo "Detected EUI $GATEWAY_EUI from $GATEWAY_EUI_NIC"

echo "Settings :"

printf "       Host name [loranet-gateway]:"
read NEW_HOSTNAME
if [[ $NEW_HOSTNAME == "" ]]; then NEW_HOSTNAME="loranet-gateway"; fi

printf "       Descriptive name [loranet-ic880a]:"
read GATEWAY_NAME
if [[ $GATEWAY_NAME == "" ]]; then GATEWAY_NAME="loranet-ic880a"; fi

printf "       Contact email: "
read GATEWAY_EMAIL

printf "       Latitude [0]: "
read GATEWAY_LAT
if [[ $GATEWAY_LAT == "" ]]; then GATEWAY_LAT=0; fi

printf "       Longitude [0]: "
read GATEWAY_LON
if [[ $GATEWAY_LON == "" ]]; then GATEWAY_LON=0; fi

printf "       Altitude [0]: "
read GATEWAY_ALT
if [[ $GATEWAY_ALT == "" ]]; then GATEWAY_ALT=0; fi



# Change hostname if needed
CURRENT_HOSTNAME=$(hostname)

if [[ $NEW_HOSTNAME != $CURRENT_HOSTNAME ]]; then
    echo "Updating hostname to '$NEW_HOSTNAME'..."
    hostname $NEW_HOSTNAME
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/" /etc/hosts
fi

# Check dependencies
echo "Installing dependencies..."
apt-get install swig libftdi-dev python-dev

# Install LoRaWAN packet forwarder repositories
INSTALL_DIR="/opt/loranet-gateway"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi
pushd $INSTALL_DIR
echo  "Install dir:" $INSTALL_DIR
echo  "Current dir: " `pwd` 

# Build libraries
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
echo  "Current dir: " `pwd` 

# Build LoRa gateway app
if [ ! -d lora_gateway ]; then
    git clone https://github.com/Lora-net/lora_gateway.git
    pushd lora_gateway
else
    pushd lora_gateway
    git reset --hard
    git pull
fi

cp ./libloragw/99-libftdi.rules /etc/udev/rules.d/99-libftdi.rules

sed -i -e 's/CFG_SPI= native/CFG_SPI= ftdi/g' ./libloragw/library.cfg
sed -i -e 's/PLATFORM= kerlink/PLATFORM= lorank/g' ./libloragw/library.cfg
sed -i -e 's/ATTRS{idProduct}=="6010"/ATTRS{idProduct}=="6014"/g' /etc/udev/rules.d/99-libftdi.rules

make

popd
echo  "Current dir:" `pwd` 

# Build packet forwarder
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
echo  "Current dir:" `pwd` 

# Symlink poly packet forwarder
if [ ! -d $INSTALL_DIR/bin ]; then
	echo "Create dir [bin]"
	mkdir $INSTALL_DIR/bin; 
fi
if [ -f $INSTALL_DIR/bin/lora_pkt_fwd ]; then 
    echo "Remove symbolic link [lora_pkt_fwd]"
	rm $INSTALL_DIR/bin/lora_pkt_fwd; 
fi

echo "Create symbolic link [lora_pkt_fwd]"
ln -s "$INSTALL_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd" "$INSTALL_DIR/bin/lora_pkt_fwd"
echo "Copy [global_conf.json]"
cp -f $INSTALL_DIR/packet_forwarder/poly_pkt_fwd/global_conf.json $INSTALL_DIR/bin/global_conf.json

LOCAL_CONFIG_FILE=$INSTALL_DIR/bin/local_conf.json

# Remove old config file
if [ -e $LOCAL_CONFIG_FILE ]; then rm $LOCAL_CONFIG_FILE; fi;

# create new config file
echo -e "{\n\t\"gateway_conf\": {\n\t\t\"gateway_ID\": \"$GATEWAY_EUI\",\n\t\t\"servers\": [ { \"server_address\": \"router.eu.thethings.network\", \"serv_port_up\": 1700, \"serv_port_down\": 1700, \"serv_enabled\": true } ],\n\t\t\"ref_latitude\": $GATEWAY_LAT,\n\t\t\"ref_longitude\": $GATEWAY_LON,\n\t\t\"ref_altitude\": $GATEWAY_ALT,\n\t\t\"contact_email\": \"$GATEWAY_EMAIL\",\n\t\t\"description\": \"$GATEWAY_NAME\" \n\t}\n}" >$LOCAL_CONFIG_FILE


popd

echo "Gateway EUI is: $GATEWAY_EUI"
echo "The hostname is: $NEW_HOSTNAME"
echo "Check gateway status here (find your EUI): http://staging.thethingsnetwork.org/gatewaystatus/"
echo
echo "Installation completed."

# Start packet forwarder as a service
cp ./start.sh $INSTALL_DIR/bin/
cp ./loranet-gateway.service /lib/systemd/system/
systemctl enable loranet-gateway.service

echo "The system will reboot in 5 seconds..."
sleep 5
shutdown -r now
