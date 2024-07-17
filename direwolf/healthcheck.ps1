####################################################################
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
####################################################################

. ./common.ps1

Invoke-Init-ExitOnError -wait_service_enabled $False -service_name $env:SERVICE_NAME -web_service_name $env:SVC_CONTROL_WS_SERVICE_NAME -web_service_port $env:SVC_CONTROL_WS_REST_PORT

Invoke-ExitIfServiceDisabled-ExitOnError -service_name $service_name -process_name "direwolf" 

Get-SerialPort-ExitOnError -find_devices_config_file $find_devices_internal_config_file_name -find_devices_utility $find_devices_file_name
Get-AudioDevice-ExitOnError -find_devices_config_file $find_devices_internal_config_file_name -find_devices_utility $find_devices_file_name

Test-AudioDeviceVolume-ExitOnError -find_devices_config_file $find_devices_internal_config_file_name -find_devices_utility $find_devices_file_name

Test-TcpConnection-ExitOnError -host_name $service_name -port_number $modem_internal_kiss_port_number

exit 0
