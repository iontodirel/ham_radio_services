####################################################################
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
####################################################################

. ./common.ps1

Invoke-Init-ExitOnError -wait_service_enabled $False -service_name $env:SERVICE_NAME -web_service_name $env:SVC_CONTROL_WS_SERVICE_NAME -web_service_port $env:SVC_CONTROL_WS_REST_PORT

Invoke-ExitIfServiceDisabled-ExitOnError -service_name $service_name -process_name "aprx" 

Test-TcpConnection-ExitOnError -host_name $aprsis_server -port_number $aprsis_port -enabled $require_aprsis
Test-ModemConnection-ExitOnError -modem_host_name $modem_host_name -modem_kiss_port_number $modem_kiss_port_number

exit 0
