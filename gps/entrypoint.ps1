. ./common.ps1

Invoke-Init-ExitOnError -service_name $env:SERVICE_NAME -web_service_name $env:SVC_CONTROL_WS_SERVICE_NAME -web_service_port $env:SVC_CONTROL_WS_REST_PORT

Invoke-InitHardware-ExitOnError -find_devices_internal_config_file_name $find_devices_internal_config_file_name `
                                -find_devices_file_name $find_devices_file_name `
                                -find_devices_internal_output_json_file_name $find_devices_internal_output_json_file_name `
                                -soundcard_test_wav_file_name $soundcard_test_wav_file_name `
                                -service_name $service_name `
                                -ignore_audio_device $True `
                                -test_read_serial_port $True

Start-Gpsd-ExitOnError -serial_port $serial_port -gpsd_internal_port_number $gpsd_internal_port_number
