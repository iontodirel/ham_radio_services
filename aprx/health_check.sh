#!/bin/bash

# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

: "${_APRX_CONTAINER_SVC_CONF_FILE:=/services.json}"
: "${_DIREWOLF_CONTAINER_SERVICE:=direwolfm}"
: "${_DIREWOLF_CONTAINER_KISS_PORT:=8001}"
: "${_APRSIS_SERVER:=rotate.aprs2.net}"
: "${_APRSIS_SERVICE_PORT_A:=14580}"

#
# Health checks checklist:
#
#     - file services.json exists
#     - service enabled, or if service disabled process "aprx" is not running
#     - can make socket connection on APRS-IS typically on rotate.aprs2.net on port 14580
#     - can make socket connection to Direwolf typically on port 8001
#

echo "Running health check"

# Check that the services.json file exists
if ! test -f "$_APRX_CONTAINER_SVC_CONF_FILE"
then
    echo "Error: No services.json config file found \"$_APRX_CONTAINER_SVC_CONF_FILE\""
    exit 1
fi

# get the enable/disable state of the aprx container
aprx_enable_service=$(jq -r '.aprx // "" ' $_APRX_CONTAINER_SVC_CONF_FILE)

# if the service is disabled but the aprx process is running
# exit to mark the container as unhealthy
# this will restart the container and put it in enable waitable state

if [[ "$aprx_enable_service" == "disabled" ]] && pgrep -x "aprx" > /dev/null 2>&1; then
    echo "aprx service disabled but aprx service running"
    exit 1
fi

# try to connect to APRS-IS

nc -zv $_APRSIS_SERVER $_APRSIS_SERVICE_PORT_A > /dev/null 2>&1
nc_return_code=$?

if [ "$nc_return_code" -ne 0 ]; then
    echo "Error: Connection to APRS-IS unsuccessful"
    exit 1
fi

# try to connect to Direwolf and make sure the socket is up
# no point in running the digipeater without the radio/modem

nc -zv $_DIREWOLF_CONTAINER_SERVICE $_DIREWOLF_CONTAINER_KISS_PORT > /dev/null 2>&1
nc_return_code=$?

if [ "$nc_return_code" -ne 0 ]; then
    echo "Error: Connection to Direwolf unsuccessful"
    exit 1
fi

exit 0
