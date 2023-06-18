#!/bin/bash

: "${_APRX_CONTAINER_SVC_CONF_FILE:=/services.json}"

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

if [[ "$aprx_enable_service" == "disabled" ]] && pgrep -x "aprx" > /dev/null; then
    echo "aprx service disabled but aprx service running"
    exit 1
fi

exit 0
