#!/bin/bash

# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

: "${FIND_DEVICES:=/find_devices/find_devices}"
: "${_GPS_CONTAINER_FD_CONFIG:=ublox_config.json}"
: "${OUT_JSON:=output.json}"
: "${_GPS_CONTAINER_SERVICE:=gps}"
: "${_GPS_CONTAINER_PORT:=2947}"
: "${_GPS_CONTAINER_SVC_CONF_FILE:=/services.json}"

echo "Running health check"

# Check that the services.json file exists
if ! test -f "$_GPS_CONTAINER_SVC_CONF_FILE"
then
    echo "Error: No services.json config file found \"$_GPS_CONTAINER_SVC_CONF_FILE\""
    exit 1
fi

# get the enable/disable state of the aprx container
gps_enable_service=$(jq -r '.gps // "" ' $_GPS_CONTAINER_SVC_CONF_FILE)

# if the service is disabled but the gps process is running
# exit to mark the container as unhealthy
# this will restart the container and put it in enable waitable state

if [[ "$gps_enable_service" == "disabled" ]] && pgrep -x "gpsd" > /dev/null 2>&1; then
    echo "gps service disabled but gps service running"
    exit 1
fi

# if find_devices config file does not exist then exit
if ! test -f "$_GPS_CONTAINER_FD_CONFIG"
then
    echo "Error: No find_devices config file found \"$_GPS_CONTAINER_FD_CONFIG\""
    exit 1
fi

# Check that the find_devices utility is found
if ! command -v "$FIND_DEVICES" >/dev/null 2>&1; then
    echo "Error: Executable" \"$FIND_DEVICES\"" not found"
    exit 1
fi

rm -f $OUT_JSON

# Call find_devices
if ! $FIND_DEVICES -c $_GPS_CONTAINER_FD_CONFIG -o $OUT_JSON --no-stdout; then
    echo "Error: Failed to find devices"
    exit 1
fi

# Get counts and names
serial_ports_count=$(jq ".serial_ports | length" $OUT_JSON)

# Return if no soundcards and serial ports were found
if [ $serial_ports_count -eq 0 ]; then
    echo "Error: No serial ports found, expected at least one serial port"
    exit 1
fi

# Check counts
# Update as appropriate
if [ $serial_ports_count -ne 1 ]; then
    echo "Error: serial ports not equal to 1"
    exit 1
fi

# try to connect to gpsd and make sure the socket is up

nc -zv $_GPS_CONTAINER_SERVICE $_GPS_CONTAINER_PORT > /dev/null 2>&1
nc_return_code=$?

if [ "$nc_return_code" -ne 0 ]; then
    echo "Error: Connection to gpsd unsuccessful"
    exit 1
fi

exit 0
