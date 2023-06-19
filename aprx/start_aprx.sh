#!/bin/bash

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
: "${APRX_CONFIG_FILE:=/aprx/aprx.conf}" # local variable, not set by .env
: "${_APRX_CONTAINER_LOG_DIR:=/aprx/logs}"
: "${_APRX_CONTAINER_SVC_CONF_FILE:=/services.json}"

echo "start_aprx.sh script variables:"
echo "    \$MYCALL=$MYCALL"
echo "    \$LAT=$LAT"
echo "    \$LON=$LON"
echo "    \$APRSIS_PASSCODE=$APRSIS_PASSCODE"
echo "    \$_DIREWOLF_CONTAINER_SERVICE=$_DIREWOLF_CONTAINER_SERVICE"
echo "    \$_DIREWOLF_CONTAINER_AGWP_PORT=$_DIREWOLF_CONTAINER_AGWP_PORT"
echo "    \$_DIREWOLF_CONTAINER_KISS_PORT=$_DIREWOLF_CONTAINER_KISS_PORT"
echo "    \$_APRX_CONTAINER_CONFIG_FILE=$_APRX_CONTAINER_CONFIG_FILE"
echo "    \$APRX_CONFIG_FILE=$APRX_CONFIG_FILE"
echo "    \$_APRX_CONTAINER_LOG_DIR=$_APRX_CONTAINER_LOG_DIR"
echo "    \$_APRX_CONTAINER_SVC_CONF_FILE=$_APRX_CONTAINER_SVC_CONF_FILE"

echo "Copying config from $_APRX_CONTAINER_CONFIG_FILE to $APRX_CONFIG_FILE, and using $APRX_CONFIG_FILE"
cp $_APRX_CONTAINER_CONFIG_FILE $APRX_CONFIG_FILE

# Check that the aprx.conf file exists
if ! test -f "$APRX_CONFIG_FILE"
then
    echo "Error: No aprx config file found \"$APRX_CONFIG_FILE\""
    exit 1
fi

# Check that the services.json file exists
if ! test -f "$_APRX_CONTAINER_SVC_CONF_FILE"
then
    echo "Error: No services.json config file found \"$_APRX_CONTAINER_SVC_CONF_FILE\""
    exit 1
fi

aprx_enable_service=$(jq -r '.aprx // "" ' $_APRX_CONTAINER_SVC_CONF_FILE)

# try to connect to Direwolf and make sure the socket is up
# no point in running the digipeater without the radio

nc -zv $_DIREWOLF_CONTAINER_SERVICE $_DIREWOLF_CONTAINER_KISS_PORT > /dev/null 2>&1
nc_return_code=$?

if [ "$nc_return_code" -eq 0 ]; then
    echo "Test connection to Direwolf successful"
else
    echo "Error: Connection to Direwolf unsuccessful"
    exit 1
fi

#
# replace mycall, passcode, tcp-device and myloc in aprx.conf file, using sed
#
sed -i "0,/mycall/s/mycall.*/mycall $MYCALL/" $APRX_CONFIG_FILE
sed -i "s/passcode.*/passcode $APRSIS_PASSCODE/" $APRX_CONFIG_FILE
sed -i "s/tcp-device.*/tcp-device $_DIREWOLF_CONTAINER_SERVICE $_DIREWOLF_CONTAINER_KISS_PORT KISS/" $APRX_CONFIG_FILE
sed -i "0,/myloc/s/myloc.*/myloc lat $LAT lon $LON/" $APRX_CONFIG_FILE
sed -i "s|rflog.*|rflog $_APRX_CONTAINER_LOG_DIR/aprx-rf.log|" $APRX_CONFIG_FILE
sed -i "s|aprxlog.*|aprxlog $_APRX_CONTAINER_LOG_DIR/aprx.log|" $APRX_CONFIG_FILE
sed -i "s|dprslog.*|dprslog $_APRX_CONTAINER_LOG_DIR/dprs.log|" $APRX_CONFIG_FILE

if [[ "$aprx_enable_service" == "disabled" ]]; then

    echo "aprx service state is disabled, waiting for service state change to enabled"

    # if the service is disabled just wait in the container until the service is enabled

    while true; do
    
        aprx_enable_service=$(jq -r '.aprx // "enabled" ' $_APRX_CONTAINER_SVC_CONF_FILE)
    
        if [[ "$aprx_enable_service" == "enabled" ]]; then
            echo "aprx service state changed and is now enabled"
            break
        elif [[ "$aprx_enable_service" != "disabled" ]]; then
            echo "Error: Unknown aprx service state, expected: \"enabled\" or \"disabled\""
            exit 1
        fi
    
        echo "Service aprx disabled, waiting 10s for service state changes"
      
        inotifywait -t 10 -e modify $_APRX_CONTAINER_SVC_CONF_FILE
    
    done

fi

echo "Starting aprx with:"
echo "    Callsign \"$MYCALL\""
echo "    APRS-IS passcode \"$APRSIS_PASSCODE\""
echo "    KISS TCP connection \"$_DIREWOLF_CONTAINER_SERVICE:$_DIREWOLF_CONTAINER_KISS_PORT\""
echo "    Config file \"$APRX_CONFIG_FILE\""
echo "    Options: -dd -L -f"

/usr/sbin/aprx -dd -L -f $APRX_CONFIG_FILE 2>&1 | tee -a $_APRX_CONTAINER_LOG_DIR/aprx-stdout.log
