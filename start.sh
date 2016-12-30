#! /bin/bash


export SX1301_RESET_BCM_PIN=25

echo "[loranet-gateway]: Reset iC880a PIN ($SX1301_RESET_BCM_PIN)..."

echo "$SX1301_RESET_BCM_PIN"  > /sys/class/gpio/export 
ls -la /sys/class/gpio/
echo "out" > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/direction 
sleep 1.0 
echo "[loranet-gateway]: PIN ($SX1301_RESET_BCM_PIN) set to [0]"
echo "0"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
sleep 3.0 
echo "[loranet-gateway]: PIN ($SX1301_RESET_BCM_PIN) set to [1]"
echo "1"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
sleep 3.0 
echo "[loranet-gateway]: PIN ($SX1301_RESET_BCM_PIN) set to [0]"
echo "0"   > /sys/class/gpio/gpio$SX1301_RESET_BCM_PIN/value
sleep 3.0 
echo "$SX1301_RESET_BCM_PIN"  > /sys/class/gpio/unexport 
ls -la /sys/class/gpio/

echo "[loranet-gateway]: iC880a reseted"



# Test the connection, wait if needed.
while [[ $(ping -c1 google.com 2>&1 | grep " 0% packet loss") == "" ]]; do
  echo "[loranet-gateway]: Waiting for internet connection..."
  sleep 30
  done

# remote config isn't supported !


# Fire up the forwarder.
echo "[loranet-gateway]: Launching lora_pkt_fwd..."
./lora_pkt_fwd
