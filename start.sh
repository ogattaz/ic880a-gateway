#! /bin/bash


echo "[loranet-gateway]: Reset iC880a PIN (25)..."
SX1301_RESET_BCM_PIN=25
echo "$SX1301_RESET_BCM_PIN"  > /sys/class/gpio/export 
echo "out" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/direction 
echo "0"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value 
sleep 0.1  
echo "1"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value 
sleep 0.1  
echo "0"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
sleep 0.1
echo "$SX1301_RESET_BCM_PIN"  > /sys/class/gpio/unexport 

echo "[loranet-gateway]: iC880a Reseted."

# Test the connection, wait if needed.
while [[ $(ping -c1 google.com 2>&1 | grep " 0% packet loss") == "" ]]; do
  echo "[loranet-gateway]: Waiting for internet connection..."
  sleep 30
  done

# remote config isn't supported !


# Fire up the forwarder.
echo "[loranet-gateway]: Launching lora_pkt_fwd..."
./lora_pkt_fwd
