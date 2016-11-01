# The LoraNet iC880a SPI reference based gateway

Reference setup for LoRa-Net  gateways based on the iC880a USB concentrator with a Raspberry Pi host.

https://github.com/Lora-net/lora_gateway
https://github.com/Lora-net/lora_gateway

This installer targets the **SPI* of the board.

## Setup based on Raspbian image

- Download [Raspbian Jessie Lite](https://www.raspberrypi.org/downloads/)
- Follow the [installation instruction](https://www.raspberrypi.org/documentation/installation/installing-images/README.md) to create the SD card
- Start your RPi connected to Ethernet
- Plug the iC880a (**WARNING**: first power plug to the wall socket, then to the gateway DC jack, and ONLY THEN USB to RPi!)
- From a computer in the same LAN, `ssh` into the RPi using the default hostname:

        local $ ssh pi@raspberrypi.local

- Default password of a plain-vanilla RASPBIAN install for user `pi` is `raspberry`
- Use `raspi-config` utility to expand the filesystem (1 Expand filesystem):

        $ sudo raspi-config

- Reboot
- Configure locales and time zone:

        $ sudo dpkg-reconfigure locales
        $ sudo dpkg-reconfigure tzdata

- Make sure you have an updated installation and install `git`:

        $ sudo apt-get update
        $ sudo apt-get upgrade
        $ sudo apt-get install git

- Create new user for TTN and add it to sudoers

        $ sudo adduser loranet 
        $ sudo adduser loranet sudo

- To prevent the system asking root password regularly, add TTN user in sudoers file

        $ sudo visudo

Add the line `loranet ALL=(ALL) NOPASSWD: ALL`

:warning: Beware this allows a connected console with the ttn user to issue any commands on your system, without any password control. This step is completely optional and remains your decision.

 
- Clone [the installer](https://github.com/ogattaz/ic880a-gateway/) and start the installation

        $ git clone https://github.com/ogattaz/ic880a-gateway ~/ic880a-loranet-gateway
        $ cd ~/ic880a-loranet-gateway
        $ sudo ./install.sh

- If you want to use the remote configuration option, please make sure you have created a JSON file named as your gateway EUI (e.g. `B827EBFFFE7B80CD.json`) in the [Gateway Remote Config repository](https://github.com/ttn-zh/gateway-remote-config). 
- **Big Success!** You should now have a running gateway in front of you!

# Credits

These scripts are largely based on the awesome work by [Ruud Vlaming](https://github.com/devlaam) on the [Lorank8 installer](https://github.com/Ideetron/Lorank).
