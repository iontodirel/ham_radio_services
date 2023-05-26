#!/bin/sh

: "${APRX_CONFIG_FILE:=aprx.conf}"
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
