#!/bin/sh

# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #
#
# All below variables set by docker compose
#
: "${MYCALL:=N0CALL}" 
: "${LAT:=0000.00N}"
: "${LON:=00000.00W}"
: "${APRSIS_PASSCODE:=0000}"
: "${_DIREWOLF_CONTAINER_SERVICE:=direwolfm}"
: "${_DIREWOLF_CONTAINER_AGWP_PORT:=8000}"
: "${_DIREWOLF_CONTAINER_KISS_PORT:=8001}"
: "${_APRX_CONTAINER_CONFIG_FILE:=aprx.conf}"
: "${APRX_CONFIG_FILE:=/aprx/aprx.conf}"

echo "Copying config from $_APRX_CONTAINER_CONFIG_FILE to $APRX_CONFIG_FILE, and using $APRX_CONFIG_FILE"
cp $_APRX_CONTAINER_CONFIG_FILE $APRX_CONFIG_FILE

# Check that the config file exists
if ! test -f "$APRX_CONFIG_FILE"
then
    echo "Error: No aprx config file found \"$APRX_CONFIG_FILE\""
    exit 1
fi

#
# replace mycall, passcode, tcp-device and myloc in aprx.conf file, using sed
#
sed -i "0,/mycall/s/mycall.*/mycall $MYCALL/" $APRX_CONFIG_FILE
sed -i "s/passcode.*/passcode $APRSIS_PASSCODE/" $APRX_CONFIG_FILE
sed -i "s/tcp-device.*/tcp-device $_DIREWOLF_CONTAINER_SERVICE $_DIREWOLF_CONTAINER_KISS_PORT KISS/" $APRX_CONFIG_FILE
sed -i "0,/myloc/s/myloc.*/myloc lat $LAT lon $LON/" $APRX_CONFIG_FILE

echo "Starting aprx with:"
echo "    Callsign \"$MYCALL\""
echo "    APRS-IS passcode \"$APRSIS_PASSCODE\""
echo "    KISS TCP connection \"$_DIREWOLF_CONTAINER_SERVICE:$_DIREWOLF_CONTAINER_KISS_PORT\""
echo "    Config file \"$APRX_CONFIG_FILE\""

/usr/sbin/aprx -dd -L -f $APRX_CONFIG_FILE
