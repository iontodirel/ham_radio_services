####################################################################
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
####################################################################

. ./common.ps1

Invoke-Init-ExitOnError -service_name $env:SERVICE_NAME -web_service_name $env:SVC_CONTROL_WS_SERVICE_NAME -web_service_port $env:SVC_CONTROL_WS_REST_PORT

Test-TcpConnection-ExitOnError -host_name $aprsis_server -port_number $aprsis_port -enabled $require_aprsis -service_name $service_name -log_file_name $log_file_name
Test-ModemConnection-ExitOnError -modem_host_name $modem_host_name -modem_kiss_port_number $modem_kiss_port_number -service_name $service_name -log_file_name $log_file_name

Start-Aprx-ExitOnError -aprx_internal_working_config_file_name $aprx_internal_working_config_file_name `
                       -callsign $callsign `
                       -aprsis_pass $aprsis_pass `
                       -aprsis_server $aprsis_server `
                       -modem_host_name $modem_host_name `
                       -modem_kiss_port_number $modem_kiss_port_number `
                       -lat $lat `
                       -lon $lon `
                       -aprx_internal_log_directory $aprx_internal_log_directory `
                       -log_file_name $log_file_name `
                       -service_name $service_name
