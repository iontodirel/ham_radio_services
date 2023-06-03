#!/bin/sh

# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

# NOTE: Please modify the path to 'find_devices' as appropriate by updating FIND_DEVICES
: "${FIND_DEVICES:=/find_devices/find_devices}"
# Generic configuration in the same directory as the script
: "${_DIREWOLF_CONTAINER_FD_CONFIG:=digirig_config.json}"
# Can simply remain the same
: "${OUT_JSON:=output.json}"
# Update with your own direwolf.conf file and location
# this file is located in the same directory as this script
: "${DIREWOLF_CONFIG_FILE:=direwolf.conf}"
# Set by docker compose
: "${_DIREWOLF_CONTAINER_AGWP_PORT:=8000}"
: "${_DIREWOLF_CONTAINER_KISS_PORT:=8001}"
: "${MYCALL:=N0CALL}"
: "${_DIREWOLF_CONTAINER_LOG_DIR:=/direwolf/logs}"

echo "Using \"$_DIREWOLF_CONTAINER_FD_CONFIG\" to find devices using find_devices"
echo "See https://github.com/iontodirel/find_devices"

# if find_devices config file does not exist then exit
if ! test -f "$_DIREWOLF_CONTAINER_FD_CONFIG"
then
    echo "Error: No find_devices config file found \"$_DIREWOLF_CONTAINER_FD_CONFIG\""
    exit 1
fi

# Check that the find_devices utility is found
if ! command -v "$FIND_DEVICES" >/dev/null 2>&1; then
    echo "Error: Executable" \"$FIND_DEVICES\"" not found"
    exit 1
fi

# Call find_devices
# https://github.com/iontodirel/find_devices
if ! $FIND_DEVICES -c $_DIREWOLF_CONTAINER_FD_CONFIG -o $OUT_JSON --no-stdout; then
    echo "Error: Failed to find devices"
    exit 1
fi

# Check that the output json file was created
if ! test -f "$OUT_JSON"
then
    echo "Error: No output json output file found \"$OUT_JSON\""
    exit 1
fi

# Get counts and names
audio_devices_count=$(jq ".audio_devices | length" $OUT_JSON)
serial_ports_count=$(jq ".serial_ports | length" $OUT_JSON)
# Pick the first sound card and serial port
# Adjust your configuration to always find one device
audio_device=$(jq -r '.audio_devices[0].plughw_id // ""' $OUT_JSON)
serial_port=$(jq -r '.serial_ports[0].name // ""' $OUT_JSON)

echo "Audio devices count: \"$audio_devices_count\""
echo "Serial ports count: \"$serial_ports_count\""
echo "Audio device: \"$audio_device\""
echo "Serial port: \"$serial_port\""

# Return if no soundcards and serial ports were found
if [ $audio_devices_count -eq 0 ] || [ $serial_ports_count -eq 0 ]; then
     echo "Error: No audio devices and serial ports found, expected at least one soundcard and at least one serial port"
     exit 1
fi

# Check counts
# Update as appropriate
if [ $audio_devices_count -ne 1 ]; then
    echo "Error: Audio devices not equal to 1"
    exit 1
fi
if [ $serial_ports_count -ne 1 ]; then
    echo "Error: Serial ports not equal to 1"
    exit 1
fi

echo "Using audio device \"$audio_device\" and serial port for PTT \"$serial_port\""

# if config file does not exist then exit
if ! test -f "$DIREWOLF_CONFIG_FILE"
then
    echo "Error: No Direwolf config file found \"$DIREWOLF_CONFIG_FILE\""
    exit 1
fi

# replace soundard id in direwolf.conf file
sed -i "s/ADEVICE.*/ADEVICE $audio_device/" $DIREWOLF_CONFIG_FILE
# replace PTT in direwolf.conf file
sed -i "s|PTT.*|PTT $serial_port RTS|" "$DIREWOLF_CONFIG_FILE"

# replace callsign in direwolf.conf file
sed -i "s/MYCALL.*/MYCALL $MYCALL/" $DIREWOLF_CONFIG_FILE

# replace AGWPORT and KISSPORT in direwolf.conf file
sed -i "s/AGWPORT.*/AGWPORT $_DIREWOLF_CONTAINER_AGWP_PORT/" $DIREWOLF_CONFIG_FILE
sed -i "s/KISSPORT.*/KISSPORT $_DIREWOLF_CONTAINER_KISS_PORT/" $DIREWOLF_CONFIG_FILE

#
# Start direwolf
#

echo "Starting direwolf with callsign '$MYCALL', devices '$audio_device' '$serial_port', and ports '$_DIREWOLF_CONTAINER_AGWP_PORT', '$_DIREWOLF_CONTAINER_KISS_PORT'"
echo ""

/usr/bin/direwolf -t 0 -a 10 -c $DIREWOLF_CONFIG_FILE -l $_DIREWOLF_CONTAINER_LOG_DIR 2>&1 | tee -a $_DIREWOLF_CONTAINER_LOG_DIR/direwolf-stdout.log