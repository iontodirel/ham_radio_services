#!/bin/sh

# NOTE: Please modify the path to 'find_devices' as appropriate by updating FIND_DEVICES
: "${FIND_DEVICES:=/find_devices/find_devices}"
# Generic configuration in the same directory as the script
: "${FIND_DEVICES_CONTAINER_CONFIG:=digirig_config.json}"
# Can simply remain the same
: "${OUT_JSON:=output.json}"
# Update with your own direwolf.conf file and location
# this file is located in the same directory as this script
: "${DIREWOLF_CONFIG_FILE:=direwolf.conf}"
# Set by docker compose
: "${DIREWOLF_CONTAINER_AGWP_PORT:=8000}"
: "${DIREWOLF_CONTAINER_KISS_PORT:=8001}"
: "${MYCALL:=N0CALL}"

echo "Using \"$FIND_DEVICES_CONTAINER_CONFIG\" to find devices"

# Check that the find_devices utility is found
if ! command -v "$FIND_DEVICES" >/dev/null 2>&1; then
    echo "Executable" \"$FIND_DEVICES\"" not found"
    exit 1
fi

# Find devices
if ! $FIND_DEVICES -c $FIND_DEVICES_CONTAINER_CONFIG -o $OUT_JSON --no-stdout; then
    echo "Failed to find devices"
    exit 1
fi

# Get counts and names
audio_devices_count=$(jq ".audio_devices | length" $OUT_JSON)
serial_ports_count=$(jq ".serial_ports | length" $OUT_JSON)
# Pick the first sound card and serial port
# Adjust your configuration to alwats find one device
audio_device=$(jq -r '.audio_devices[0].plughw_id // ""' $OUT_JSON)
serial_port=$(jq -r '.serial_ports[0].name // ""' $OUT_JSON)

echo "Audio devices count: \"$audio_devices_count\""
echo "Serial ports count: \"$serial_ports_count\""
echo "Audio device: \"$audio_device\""
echo "Serial port: \"$serial_port\""

# Return if no soundcards and serial ports were found
if [ $audio_devices_count -eq 0 ] || [ $serial_ports_count -eq 0 ]; then
     echo "No audio devices and serial ports found, expected at least one soundcard and at least one serial port"
     exit 1
fi

# Check counts
# Update as appropriate
# Uncomment or comment next lines after as you are writing your configuration
# to find exactly one devices
if [ $audio_devices_count -ne 1 ]; then
    echo "Audio devices not equal to 1"
    exit 1
fi
if [ $serial_ports_count -ne 1 ]; then
    echo "Serial ports not equal to 1"
    exit 1
fi

# Use the ALSA sound card id for something
echo "Using audio device \"$audio_device\" and serial port for PTT \"$serial_port\""

# if config file does not exist then exit
if ! test -f "$DIREWOLF_CONFIG_FILE"
then
    echo "No config file found $DIREWOLF_CONFIG_FILE"
    exit 1
fi

# replace soundard id in direwolf.conf file
sed -i "s/ADEVICE.*/ADEVICE $audio_device/" $DIREWOLF_CONFIG_FILE
sed -i "s|PTT.*|PTT $serial_port RTS|" "$DIREWOLF_CONFIG_FILE"

# replace callsign in direwolf.conf file
sed -i "s/MYCALL.*/MYCALL $MYCALL/" $DIREWOLF_CONFIG_FILE

# replace AGWPORT and KISSPORT in direwolf.conf file
sed -i "s/AGWPORT.*/AGWPORT $DIREWOLF_CONTAINER_AGWP_PORT/" $DIREWOLF_CONFIG_FILE
sed -i "s/KISSPORT.*/KISSPORT $DIREWOLF_CONTAINER_KISS_PORT/" $DIREWOLF_CONFIG_FILE

# start direwolf
echo "Starting direwolf with callsign '$MYCALL', devices '$audio_device' '$serial_port', and ports '$DIREWOLF_CONTAINER_AGWP_PORT', '$DIREWOLF_CONTAINER_KISS_PORT'"
echo ""

/usr/bin/direwolf -t 0 -a 10 -c $DIREWOLF_CONFIG_FILE -l .