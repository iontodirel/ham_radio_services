####################################################################
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
####################################################################

. ./common.ps1

Invoke-Init-ExitOnError -service_name $env:SERVICE_NAME -web_service_name $env:SVC_CONTROL_WS_SERVICE_NAME -web_service_port $env:SVC_CONTROL_WS_REST_PORT

Invoke-InitHardware-ExitOnError -find_devices_internal_config_file_name $find_devices_internal_config_file_name `
                                -find_devices_file_name $find_devices_file_name `
                                -find_devices_internal_output_json_file_name $find_devices_internal_output_json_file_name `
                                -soundcard_test_wav_file_name $soundcard_test_wav_file_name `
                                -service_name $service_name `
                                -log_file_name $log_file_name `
                                -test_audio_device $soundcard_test_sound_capture

Start-Direwolf-ExitOnError -callsign $callsign `
                           -audio_device $audio_device `
                           -serial_port $serial_port `
                           -modem_internal_agwp_port_number $modem_internal_agwp_port_number `
                           -modem_internal_kiss_port_number $modem_internal_kiss_port_number `
                           -direwolf_internal_config_file_name $direwolf_internal_config_file_name `
                           -direwolf_internal_config_working_file_name $direwolf_internal_config_working_file_name `
                           -modem_internal_log_directory $modem_internal_log_directory `
                           -find_devices_output_json_file $find_devices_output_json_file `
                           -log_file_name $log_file_name `
                           -service_name $service_name
