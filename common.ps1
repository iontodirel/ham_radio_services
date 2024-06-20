enum FailureTypes {
    None
    ParameterValueIsEmpty
    ParameterValueIsNotANumber
    FileNotFound
    FindDevicesNotFound
    FindDevicesConfigNotFound
    FindDevicesFailed
    ProcessExecutionFailed
    CouldNotCreateFile
    ExecutableNotFound
    DatabaseOperationUnsuccessful
    DatabaseConnectionUnsuccessful
    InvalidValue
    ExpectedDataNotReceived
    SerialPortNotFound
    SoundCardNotFound
    ServiceDisabledButProcessRunning
    FailedToGetGpsLocation
    TcpConnectionUnsuccessful
    ModemConnectionUnsuccessful
    AudioLevelLow
    WebServiceTimeout
    WebServiceConnectionFailed
    FoundTooManySerialPorts
    FoundTooManySoundCards
    SoundCardTestVolumeFailed
    SerialPortTestFailed
    SoundCardTestFailed
    ServiceExecutableExited
    ServiceConnectionFailed
    Generic
}

enum LogType {
    normal
    warning
    error
}

function Convert-Coordinates-DDtoDDM {
    param (
        [double]$lat,
        [double]$lon
    )
    
}

# # Define the path to the shared file
# $sharedFilePath = "path_to_shared_file.txt"

# # Define the name for the global mutex
# $mutexName = "GlobalMutex_$sharedFilePath"

# # Check if running on Windows
# if ($env:OS -eq "Windows_NT") {
#     # Create or open the global mutex on Windows
#     $mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$mutexCreated)
# } else {
#     # Create a unique mutex name for Linux
#     $mutexName = "/tmp/$mutexName"

#     # Check if the mutex file exists
#     if (-not (Test-Path $mutexName)) {
#         # Create the mutex file
#         $null = New-Item -Path $mutexName -ItemType File
#     }

#     # Attempt to acquire the lock
#     $lockAcquired = $false
#     while (-not $lockAcquired) {
#         try {
#             # Try to acquire the lock by creating a file lock
#             $fileStream = [System.IO.File]::Open($mutexName, 'OpenOrCreate', 'ReadWrite', 'None')
#             $lockAcquired = $true
#         } catch {
#             # If the lock is already held by another process, wait and retry
#             Start-Sleep -Milliseconds 100
#         }
#     }
# }

# # Wait for ownership of the mutex
# $mutex.WaitOne()

# # Write to the shared file
# Add-Content -Path $sharedFilePath -Value "Data from Process $$"

# # Release the mutex
# $mutex.ReleaseMutex()

# # Close the mutex handle
# $mutex.Close()


function Log {
    param (
        [LogType]$log_type = [LogType]::normal,
        [FailureTypes]$failure_type = [FailureTypes]::None,
        [string]$service_name = "",
        [string]$message = "",
        [string]$log_file_name = $log_file_name ?? "log.txt"
    )

    $newJsonLog=[ordered]@{
        type = $log_type.ToString()
        failure = $failure_type.ToString()
        service_name = $service_name
        message = $message
        time = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        utcTime = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
    }

    if (-not (Test-Path -Path $log_file_name -PathType Leaf) -or (Get-Content -Path $log_file_name -Raw) -eq $null) {
        $jsonObject = @{
           log = @($newJsonLog)
        }
        $jsonObject | ConvertTo-Json | Set-Content -Path $log_file_name
        return
    }

    $json = Get-Content $log_file_name -Raw | ConvertFrom-Json

    if (-not $json.log -or $json.log -isnot [System.Collections.IList]) {
         $json.log = @()
    }

    $json.log += $newJsonLog
    $json.log = $json.log | Select-Object -Last 1000

    $json | ConvertTo-Json | Set-Content -Path $log_file_name
}

function Get-TimeStamp {    
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)    
}

function Get-UTCTimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f [System.DateTime]::UtcNow
}

function Invoke-Log-Internal {
    if (Test-CommandExists Log) {
        Log
    }
}

function Test-CommandExists
{
    param (
        $command
    )

    $oldPreference = $ErrorActionPreference

    $ErrorActionPreference = 'stop'

    try {
        if (Get-Command $command) {
            return $true
        }
    }
    catch {
        Write-Host "$command does not exist" $($_.Exception.Message);
        return $false
    }
    finally {
        $ErrorActionPreference=$oldPreference
    }
}

function Invoke-Process-Settings {
    param (
        [string]$settings_file_name,
        [string]$service_name,
        [string]$database_internal_access_config_file_name,
        [string]$action
    )

    if (-not (Test-Path -Path $settings_file_name -PathType Leaf)) {
        Throw "Settings file '$settings_file_name' does not exist."
    }

    if (-not $service_name) {
        Throw "'service_name' is empty."
    }

    $settings = Get-Content -Raw -Path $settings_file_name | ConvertFrom-Json

    foreach ($service in $settings.services) {
        if ($service.name -eq $service_name) {
            foreach ($setting in $service.settings) {
                $setting_name = $setting.name
                $default_value = $setting.default_value
                $display_name = $setting.display_name
                $description = $setting.description
                $editable = $setting.editable

                if ([string]::IsNullOrEmpty($setting_name) -or [string]::IsNullOrEmpty($default_value)) {
                    Write-Host "Empty name or value found for setting '$setting_name' in service '$service_name'."
                    continue
                }

                switch ($action) {
                    "print" {
                        Write-Host "$setting_name='$default_value'"
                        break
                    }
                    # TODO: consider "export" not "declare"
                    "declare" {
                        Set-Variable -Name "script:$setting_name" -Value $default_value
                        break
                    }
                    "store" {
                        Submit-Store-SettingToDB -database_internal_access_config_file_name $database_internal_access_config_file_name -setting_name $setting_name -setting_value $default_value -service_name $service_name -display_name $display_name -description $description -editable $editable
                        break
                    }
                    default {
                        Throw "Invalid action: $action"
                    }
                }
            }
            break
        }
    }
}

function Submit-Store-SettingToDB {
    param (
        [string]$database_internal_access_config_file_name,
        [string]$setting_name,
        [string]$setting_value,        
        [string]$service_name,
        [string]$display_name,
        [string]$description,
        [string]$editable
    )

    if (-not (Test-Path -Path $database_internal_access_config_file_name -PathType Leaf)) {
        Throw "File '$database_internal_access_config_file_name' does not exist."
    }

    if (-not $setting_name) {
        Throw "'setting_name' is empty."
    }

    if (-not $setting_value) {
        Throw "'setting_value' is empty."
    }

    if (-not $service_name) {
        Throw "'service_name' is empty."
    }

    $query = @"
        INSERT INTO setting (service_id, name, value, editable, display_name, description)
        SELECT service.id, '$setting_name', '$setting_value', '$editable', '$display_name', '$description'
        FROM service
        WHERE service.name = '$service_name'
        AND NOT EXISTS (
            SELECT 1 FROM setting WHERE setting.service_id = service.id AND setting.name = '$setting_name'
        );

        UPDATE setting
        SET value = '$setting_value'
        WHERE service_id IN (
            SELECT id FROM service WHERE name = '$service_name'
        )
        AND name = '$setting_name'
        AND editable = 'false';
"@

    mysql --defaults-extra-file=$database_internal_access_config_file_name -B -s -e $query 2>$null

    if ($LASTEXITCODE -ne 0) {
        Throw "Database insert unsuccessful."
    }
}

function Get-SettingValue {
    param (
        [string]$settings_file_name,
        [string]$service_name,
        [string]$setting_name
    )

    if (-not (Test-Path -Path $settings_file_name -PathType Leaf)) {
        Throw "Settings file '$settings_file_name' does not exist."
    }

    if (-not $service_name) {
        Throw "'service_name' is empty."
    }

    if (-not $setting_name) {
        Throw "'setting_name' is empty."
    }

    $settings = Get-Content -Raw -Path $settings_file_name | ConvertFrom-Json

    $default_value = ($settings.services | Where-Object { $_.name -eq $service_name }).settings | Where-Object { $_.name -eq $setting_name } | Select-Object -ExpandProperty default_value

    return $default_value
}

function Wait-ForDatabase {
    param (
        [string]$database_host_name,
        [int]$database_port_number,
        [string]$database_user_name,
        [string]$database_password
    )

    if (-not $database_host_name) {
        Throw "'database_host_name' is empty."
    }

    if (-not ($database_port_number -is [int])) {
        Throw "'database_port_number' is not a valid number."
    }

    if (-not $database_user_name) {
        Throw "'database_user_name' is empty."
    }

    if (-not $database_password) {
        Throw "'database_password' is empty."
    }

    Write-Host "Waiting 60 seconds for database to be ready."

    mysqladmin -h $database_host_name -P $database_port_number -u $database_user_name -p$database_password ping --wait=60 2>$null

    if ($LASTEXITCODE -ne 0) {
        Throw "Failed to connect to the database."
    }

    Write-Host "Database ready."
}

function New-DatabaseAccessConfig {
    param (
        [string]$database_internal_access_config_file_name,
        [string]$database_password,
        [string]$database_name,
        [string]$database_user_name,
        [int]$database_port_number,
        [string]$database_host_name
    )

    if (-not $database_internal_access_config_file_name) {
        Throw "'database_internal_access_config_file_name' is empty."
    }

    if (-not $database_password) {
        Throw "'database_password' is empty."
    }

    if (-not $database_name) {
        Throw "'database_name' is empty."
    }

    if (-not $database_user_name) {
        Throw "'database_user_name' is empty."
    }

    if (-not ($database_port_number -is [int])) {
        Throw "'database_port_number' is not a valid number."
    }

    if (-not $database_host_name) {
        Throw "'database_host_name' is empty."
    }

    if (Test-Path -Path $database_internal_access_config_file_name -PathType Leaf) {
        Remove-Item -Path $database_internal_access_config_file_name -ErrorAction SilentlyContinue
    }

    $null = New-Item -Path $database_internal_access_config_file_name -ItemType File -Force
    $null = Set-ItemProperty -Path $database_internal_access_config_file_name -Name 'Attributes' -Value 'Hidden'

    Add-Content -Path $database_internal_access_config_file_name -Value "[client]"
    Add-Content -Path $database_internal_access_config_file_name -Value "password = $database_password"
    Add-Content -Path $database_internal_access_config_file_name -Value "database = $database_name"
    Add-Content -Path $database_internal_access_config_file_name -Value "user = $database_user_name"
    Add-Content -Path $database_internal_access_config_file_name -Value "port = $database_port_number"
    Add-Content -Path $database_internal_access_config_file_name -Value "host = $database_host_name"

    if (-not (Test-Path -Path $database_internal_access_config_file_name -PathType Leaf)) {
        Throw "Failed to create the internal access config file: '$database_internal_access_config_file_name'"
    }

    $null = mysql --defaults-extra-file=$database_internal_access_config_file_name -B -s -e "SELECT * FROM service;" 2>$null

    if ($LASTEXITCODE -ne 0) {
        Throw "Connection and query to MySQL unsuccessful."
    }

    Write-Host "Connection and query to MySQL successful."
}

function Invoke-WaitServiceReady {
    param (
        [string]$web_service_name,
        [string]$web_service_port
    )

    for ($i = 1;  $i -lt 30; $i++) {
        try {
            $serviceResponse = Invoke-WebRequest -Uri "http://${web_service_name}:$web_service_port/api/v1/ready" -Method Get -ErrorAction SilentlyContinue 2>$null
            if ($serviceResponse.StatusCode -eq 200) {
               $serviceResponseJson = $serviceResponse.Content | ConvertFrom-Json
               if ($serviceResponseJson.ready -eq 'true') {
                   Write-Host "Request succeeded with status code 200."
                   return $True
               }
            }
        }
        catch {
            Write-Host "Invoke-WebRequest failed with an exception $($_.Exception.Message)"
        }
        Start-Sleep -s 1
    }
    Write-Error "Invoke-WaitServiceReady returned false"
    return $False
}


function Get-ServiceEnabled {
    param (
        [string]$service_name,
        [string]$web_service_name,
        [string]$web_service_port
    )

    $serviceResponse = Invoke-WebRequest -Uri "http://${web_service_name}:$web_service_port/api/v1/service/$service_name/enabled" -Method Get -ErrorAction SilentlyContinue 2>$null
    if ($serviceResponse.StatusCode -ne 200) {
        Write-Host "Request failed."
        Return $False
    }        

    $serviceResponseJson = $serviceResponse.Content | ConvertFrom-Json
    if ($serviceResponseJson.enabled -eq $True) {
        Return $True
    }

    Return $False
}

function Invoke-WaitServiceEnabled {
    param (
        [string]$service_name,
        [string]$web_service_name,
        [string]$web_service_port
    )

    while ($True) {
        $result = Get-ServiceEnabled -service_name $service_name -web_service_name $web_service_name -web_service_port $web_service_port
        if ($result -eq $True) {
            Write-Host "$service_name service state is enabled"
            Return $True
        }
        else {
            Write-Host "$service_name service state is disabled, waiting for service state change to 'enabled'"
        }        
        Start-Sleep -Seconds 10
    }

    Return $False
}

function Invoke-Init-ExitOnError {
    param (
        [string]$service_name = $env:SERVICE_NAME,
        [string]$web_service_name = $env:WS_SERVICE_NAME,
        [string]$web_service_port = $env:WS_PORT,
        [bool]$wait_service_enabled = $True
    )

    try {
        $result = Invoke-Init -service_name $service_name -wait_service_enabled $wait_service_enabled -web_service_name $web_service_name -web_service_port $web_service_port
        if ($result -ne $true) {
            Write-Error "Function Invoke-Init returned false."
            exit 1
        }
    }
    catch {
        Write-Host "Function Invoke-Init execution failed. $($_.Exception.Message)"
        exit 1
    }
}

function Start-Direwolf-ExitOnError {
    param (
        [string]$callsign,
        [string]$audio_device,
        [string]$serial_port,
        [string]$modem_internal_agwp_port_number,
        [string]$modem_internal_kiss_port_number,
        [string]$direwolf_internal_config_file_name,
        [string]$direwolf_internal_config_working_file_name,
        [string]$modem_internal_log_directory,
        [string]$find_devices_output_json_file = "output.json",
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )
     
    try {
        Start-Direwolf -callsign $callsign `
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
    }
    catch {
        Write-Host "Function Start-Direwolf execution failed. $($_.Exception.Message)"
        exit 1
    }
}

function Invoke-Init {
    param (
        [string]$service_name,
        [string]$web_service_name,
        [string]$web_service_port,
        [bool]$wait_service_enabled = $True
    )

    $result =  Invoke-WaitServiceReady -web_service_name $web_service_name -web_service_port $web_service_port
    if ($result -eq $False) {
        Return $False
    }
 
    $serviceResponse = Invoke-WebRequest -Uri "http://${web_service_name}:$web_service_port/api/v1/service/$service_name/settings" -Method Get -ErrorAction SilentlyContinue 2>$null
    if ($serviceResponse.StatusCode -ne 200) {
       Write-Host "Request failed."
       Return $False
    }
   
    $serviceResponseJson = $serviceResponse.Content | ConvertFrom-Json

    Write-Host "Service settings:"

    foreach ($serviceSetting in $serviceResponseJson.settings) {
        $settingName = $serviceSetting.name        
        $settingType = $serviceSetting.data_type
        switch ($settingType) {
            'bool' {
                $settingValue = [bool]::Parse($serviceSetting.value)
            }
            default {
                $settingValue = $serviceSetting.value
            }
        }
        Set-Variable -Name "script:$settingName" -Value $settingValue
        Write-Host "$settingName='$settingValue'"
    }

    $script:web_service_name = $web_service_name
    $script:web_service_port = $web_service_port

    if ($wait_service_enabled -eq $True) {
        Invoke-WaitServiceEnabled -service_name $service_name -web_service_name $web_service_name -web_service_port $web_service_port
    }

    Return $True
}

function Register-ServiceToDB {
    param (
        [string]$name,
        [string]$enabled,
        [string]$database_internal_access_config_file_name
    )

    if (-not $name) {
        Throw "'name' is empty."
    }

    if ($enabled -ne 'true' -and $enabled -ne 'false') {
        Throw "'enabled' must be either 'true' or 'false'."
    }

    if (-not (Test-Path -Path $database_internal_access_config_file_name -PathType Leaf)) {
        Throw "File '$database_internal_access_config_file_name' not found"
    }

    $query = @"
        INSERT IGNORE INTO service (name, enabled)
        VALUES ('$name', '$enabled');
"@

    mysql --defaults-extra-file=$database_internal_access_config_file_name -B -s -e $query 2>$null

    if ($LASTEXITCODE -ne 0) {
        Throw "Database insert to register service '$name' unsuccessful."
    }
}

function Get-ServiceEnabledStatusFromDB {
    param (
        [string]$service_name,
        [string]$database_internal_access_config_file_name
    )

    if (-not $service_name) {
        Throw "The 'service_name' parameter is empty."
    }

    if (-not (Test-Path -Path $database_internal_access_config_file_name -PathType Leaf)) {
        Throw "File '$database_internal_access_config_file_name' not found."
    }

    $sql_query = @"
SELECT value AS service_enabled
FROM setting
WHERE service_id = (
    SELECT id
    FROM service
    WHERE name = '$service_name'
) AND name = 'service_enabled';
"@

    $enable_service_state = mysql --defaults-extra-file=$database_internal_access_config_file_name -B -s -e $sql_query 2>$null

    if ($LASTEXITCODE -ne 0) {
        Throw "Unable to get service enable state."
    }

    if ($enable_service_state -ne "true" -and $enable_service_state -ne "false") {
        Throw "Unknown $service_name service state, expected: 'true' or 'false'."
    }

    return ($enable_service_state -eq "true")
}

function Wait-ServiceEnabled {
    param (
        [string]$service_name,
        [string]$database_internal_access_config_file_name
    )

    if (-not $service_name) {
        Throw "'service_name' is empty."
    }

    if (-not (Test-Path -Path $database_internal_access_config_file_name -PathType Leaf)) {
        Throw "File '$database_internal_access_config_file_name' not found."
    }

    try {
        $enable_service_state = Get-ServiceEnabledStatusFromDB -service_name $service_name -database_internal_access_config_file_name $database_internal_access_config_file_name
    }
    catch {
        Write-Host "An error occurred: $($_.Exception.Message)"
        Throw
    }

    Write-Host "$service_name enable service state is: $enable_service_state"

    if ($enable_service_state -eq $false) {
        Write-Host "$service_name service state is disabled, begin waiting for service state change to 'enabled'"
        
        while ($true) {
            try {
                $enable_service_state = Get-ServiceEnabledStatusFromDB -service_name $service_name -database_internal_access_config_file_name $database_internal_access_config_file_name
                Write-Host "Service enabled status: $enable_service_state"
            }
            catch {
                Write-Host "An error occurred: $($_.Exception.Message)"
                Throw
            }

            if ($enable_service_state -eq $true) {
                Write-Host "$service_name service state is now enabled"
                break
            }

            Write-Host "Service $service_name disabled, waiting 10 seconds for service state change"

            Start-Sleep -Seconds 10
        }
    }
}

function Read-DataFromSerialPort {
    param (
        [string]$serial_port,
        [int]$timeout_seconds = 30
    )

    if (-not $serial_port) {
        Throw "'serial_port' is empty."
    }

    $endTime = (Get-Date).AddSeconds($timeout_seconds)
    $charCount = 0
    $counter = 0

    while ((Get-Date) -lt $endTime) {
        $ddOutput = & dd if=$serial_port bs=1 count=100 2>&1
        $currentCount = $ddOutput.Length
        $charCount += $currentCount

        if ($charCount -ge 100) {
            Write-Host "Received $charCount bytes of data from GPS device on serial port '$serial_port' and it took '$counter' reads"
            return $true
        }

        $counter++
        Start-Sleep -Milliseconds 100
    }

    Write-Host "Did not receive 100 or more bytes of data on serial port '$serial_port'"

    return $false
}

function Get-SerialPort {
    param (
        [string]$find_devices_config_file,
        [string]$find_devices_utility,
        [string]$find_devices_output_json_file,
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )

    if ([string]::IsNullOrEmpty($find_devices_output_json_file)) {
        $find_devices_output_json_file = (New-TemporaryFile).FullName
    }

    if (-not (Test-Path -Path $find_devices_config_file -PathType Leaf)) {
        Log -log_type error -failure_type FindDevicesConfigNotFound -service_name $service_name -message "Get-SerialPort: No find_devices config file found: '$find_devices_config_file'" -log_file_name $log_file_name
        Throw "No find_devices config file found: '$find_devices_config_file'"
    }

    if (-not (Test-Path -Path $find_devices_utility -PathType Leaf)) {
        Log -log_type error -failure_type FindDevicesNotFound -service_name $service_name -message "Get-SerialPort: find_devices executable '$find_devices_utility' not found" -log_file_name $log_file_name
        Throw "find_devices executable '$find_devices_utility' not found"
    }

    Remove-Item -Path $find_devices_output_json_file -ErrorAction SilentlyContinue

    Write-Host "Calling find_devices with command line options: -c $find_devices_config_file -o $find_devices_output_json_file --no-stdout --audio.disable-volume-control"

    & $find_devices_utility -c $find_devices_config_file -o $find_devices_output_json_file --no-stdout --audio.disable-volume-control > $null
    $find_devices_exit_code = $LASTEXITCODE

    if ($find_devices_exit_code -ne 0) {
        Log -log_type error -failure_type FindDevicesFailed -service_name $service_name -message "Get-SerialPort: Failed to execute find_devices to find a serial port" -log_file_name $log_file_name
        Throw "Failed to execute find_devices to find a serial port"
    }

    if (-not (Test-Path -Path $find_devices_output_json_file -PathType Leaf)) {
        Log -log_type error -failure_type FileNotFound -service_name $service_name -message "Get-SerialPort: File '$find_devices_output_json_file' does not exist" -log_file_name $log_file_name
        Throw "File '$find_devices_output_json_file' does not exist"
    }

    $find_devices_output = Get-Content -Path $find_devices_output_json_file -Raw | ConvertFrom-Json

    $serial_ports_count = $find_devices_output.serial_ports.Count    

    Write-Host "Serial ports count: '$serial_ports_count'"

    if ($serial_ports_count -ne 1) {
        Log -log_type error -failure_type SerialPortNotFound -service_name $service_name -message "Get-SerialPort: Failed to find a serial port." -log_file_name $log_file_name
        Throw "Failed to find a serial port."
    }

    $serial_port = $find_devices_output.serial_ports[0].name

    Write-Host "Serial port: '$serial_port'"

    return $serial_port
}

function Invoke-InitHardware-ExitOnError {
    param (
        [string]$find_devices_internal_config_file_name,
        [string]$find_devices_file_name,
        [string]$find_devices_internal_output_json_file_name,
        [string]$soundcard_test_wav_file_name,
        [string]$find_devices_output_json_file,
        [string]$log_file_name,
        [string]$service_name,
        [bool]$ignore_audio_device = $False,
        [bool]$test_read_serial_port = $False,
        [bool]$test_audio_device = $False
    )

    try {
        Invoke-InitHardware -find_devices_internal_config_file_name $find_devices_internal_config_file_name `
                            -find_devices_file_name $find_devices_file_name `
                            -find_devices_internal_output_json_file_name $find_devices_internal_output_json_file_name `
                            -soundcard_test_wav_file_name $soundcard_test_wav_file_name `
                            -service_name $service_name `
                            -ignore_audio_device $ignore_audio_device `
                            -test_read_serial_port $test_read_serial_port `
                            -test_audio_device $test_audio_device `
                            -log_file_name $log_file_name `
                            -find_devices_output_json_file $find_devices_output_json_file
    }
    catch {
        Write-Host "Function Invoke-InitHardware execution failed. $($_.Exception.Message)"
        exit 1
    }
}

function Invoke-InitHardware {
    param (
        [string]$find_devices_internal_config_file_name,
        [string]$find_devices_file_name,
        [string]$find_devices_internal_output_json_file_name,
        [string]$soundcard_test_wav_file_name,
        [string]$find_devices_output_json_file,
        [string]$log_file_name,
        [string]$service_name,
        [bool]$ignore_audio_device = $False,
        [bool]$test_read_serial_port = $False,
        [bool]$test_audio_device = $False
    )

    if ($ignore_audio_device -eq $False) {
        $script:audio_device = Get-AudioDevice -find_devices_config_file $find_devices_internal_config_file_name -find_devices_utility $find_devices_file_name -find_devices_output_json_file $find_devices_internal_output_json_file_name -log_file_name $log_file_name -service_name $service_name
        
        Set-AudioDeviceVolume -find_devices_config_file $find_devices_internal_config_file_name -find_devices_utility $find_devices_file_name -log_file_name $log_file_name -service_name $service_name
        
        if ($test_audio_device -eq $True) {
            Test-AudioDevice-ExitOnError -audio_device $audio_device -soundcard_test_wav_file_name $soundcard_test_wav_file_name -log_file_name $log_file_name -service_name $service_name
        }
    }    

    $script:serial_port = Get-SerialPort -find_devices_config_file $find_devices_internal_config_file_name -find_devices_utility $find_devices_file_name -find_devices_output_json_file $find_devices_internal_output_json_file_name

    Test-SerialPort-ExitOnError -serial_port $serial_port

    if ($test_read_serial_port -eq $True) {
        Read-DataFromSerialPort -serial_port $serial_port
    }
}

function Start-Aprx-ExitOnError {
    param (
        [string]$aprx_internal_working_config_file_name,
        [string]$callsign,
        [string]$aprsis_pass,
        [string]$aprsis_server,
        [string]$modem_host_name,
        [int]$modem_kiss_port_number,
        [string]$lat,
        [string]$lon,
        [string]$aprx_internal_log_directory,
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )

    try {
        Start-Aprx -aprx_internal_working_config_file_name $aprx_internal_working_config_file_name `
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
    }
    catch {
        Log -log_type error -failure_type Generic -service_name $service_name -message "Error occurred in running Aprx: $($_.Exception.Message)" -log_file_name $log_file_name
        Write-Error "Error occurred in running Aprx: $($_.Exception.Message)"        
        exit 1
    }
}

function Start-Aprx {
    param (
        [string]$aprx_internal_working_config_file_name,
        [string]$callsign,
        [string]$aprsis_pass,
        [string]$aprsis_server,
        [string]$modem_host_name,
        [int]$modem_kiss_port_number,
        [string]$lat,
        [string]$lon,
        [string]$aprx_internal_log_directory,
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )

    Copy-Item -Path $aprx_internal_config_file_name -Destination $aprx_internal_working_config_file_name
    Copy-Item -Path $aprx_internal_config_file_name -Destination $aprx_internal_config_compare_file_name

    Update-APRXConfigFile -aprx_internal_working_config_file_name $aprx_internal_working_config_file_name `
                          -callsign $callsign `
                          -aprsis_pass $aprsis_pass `
                          -aprsis_server $aprsis_server `
                          -modem_host_name $modem_host_name `
                          -modem_kiss_port_number $modem_kiss_port_number `
                          -lat $lat `
                          -lon $lon `
                          -aprx_internal_log_directory $aprx_internal_log_directory

    Write-Host "Starting aprx with options -dd -L -f $aprx_internal_working_config_file_name"

    Log -log_type normal -failure_type None -service_name $service_name -message "Starting aprx with options -dd -L -f $aprx_internal_working_config_file_name"

    & /usr/sbin/aprx -dd -L -f $aprx_internal_working_config_file_name 2>&1 | tee -a $aprx_internal_log_directory/aprx-stdout.log
    $exit_code = $LASTEXITCODE

    Write-Host "Finished executing aprx with exit code $exit_code"

    Log -log_type warning -failure_type ServiceExecutableExited -service_name $service_name -message "Finished executing aprx with exit code $exit_code" -log_file_name $log_file_name

    exit $exit_code
}

function Start-Gpsd-ExitOnError {
    param (
        [string]$serial_port,
        [string]$gpsd_internal_port_number
    )

    try {
        Start-Gpsd -serial_port $serial_port -gpsd_internal_port_number $gpsd_internal_port_number
    }
    catch {
        Write-Host "Function Start-Gpsd execution failed: $($_.Exception.Message)"
        exit 1
    }
}

function Start-Gpsd {
    param (
        [string]$serial_port,
        [string]$gpsd_internal_port_number
    )

    Remove-Item -Path /var/run/gpsd.sock -Force -ErrorAction SilentlyContinue

    Write-Host "Starting gpsd with serial port ""$serial_port"", with options: -S $gpsd_internal_port_number -G -n -N -F /var/run/gpsd.sock"

    & /usr/sbin/gpsd $serial_port -S $gpsd_internal_port_number -G -n -N -F /var/run/gpsd.sock > /dev/null 2>&1
    $exit_code = $LASTEXITCODE

    Write-Host "Finished executing gpsd with exit code $exit_code"

    exit $exit_code
}

function Start-Direwolf {
    param (
        [string]$callsign,
        [string]$audio_device,
        [string]$serial_port,
        [string]$modem_internal_agwp_port_number,
        [string]$modem_internal_kiss_port_number,
        [string]$direwolf_internal_config_file_name,
        [string]$direwolf_internal_config_working_file_name,
        [string]$modem_internal_log_directory,
        [string]$find_devices_output_json_file = "output.json",
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )

    Copy-Item -Path $direwolf_internal_config_file_name -Destination $direwolf_internal_config_working_file_name

    Update-DirewolfConfigFile -file_path $direwolf_internal_config_working_file_name `
                          -audio_device $audio_device `
                          -ptt_serial_port $serial_port `
                          -callsign $callsign `
                          -modem_internal_agwp_port $modem_internal_agwp_port_number `
                          -modem_internal_kiss_port $modem_internal_kiss_port_number 
    
    Write-Host "Starting direwolf with callsign '$callsign', devices '$audio_device', '$serial_port', and ports '$modem_internal_agwp_port_number', '$modem_internal_kiss_port_number'"

    Log -log_type normal -failure_type None -service_name $service_name -message "Starting direwolf with callsign '$callsign', devices '$audio_device', '$serial_port', and ports '$modem_internal_agwp_port_number', '$modem_internal_kiss_port_number'"

    & /usr/local/bin/direwolf -t 0 -a 10 -c $direwolf_internal_config_working_file_name -l $modem_internal_log_directory 2>&1 | tee -a $modem_internal_log_directory/direwolf-stdout.log
    $exit_code = $LASTEXITCODE

    Write-Host "Finished executing direwolf with exit code $exit_code"

    Log -log_type warning -failure_type ServiceExecutableExited -service_name $service_name -message "Finished executing direwolf with exit code $exit_code" -log_file_name $log_file_name

    exit $exit_code
}

function Get-AudioDevice {
    param (
        [string]$find_devices_config_file,
        [string]$find_devices_utility,
        [string]$find_devices_output_json_file,
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )

    if ([string]::IsNullOrEmpty($find_devices_output_json_file)) {
        $find_devices_output_json_file = (New-TemporaryFile).FullName
    }

    if (-not (Test-Path -Path $find_devices_config_file -PathType Leaf)) {
        Log -log_type error -failure_type FindDevicesConfigNotFound -service_name $service_name -message "Get-AudioDevice: No find_devices config file found: '$find_devices_config_file'" -log_file_name $log_file_name
        Throw "No find_devices config file found: '$find_devices_config_file'"
    }

    if (-not (Test-Path -Path $find_devices_utility -PathType Leaf)) {
        Log -log_type error -failure_type FindDevicesNotFound -service_name $service_name -message "Get-AudioDevice: find_devices executable '$find_devices_utility' not found" -log_file_name $log_file_name
        Throw "find_devices executable '$find_devices_utility' not found"
    }

    Remove-Item -Path $find_devices_output_json_file -ErrorAction SilentlyContinue

    & $find_devices_utility -c $find_devices_config_file -o $find_devices_output_json_file --no-stdout --audio.disable-volume-control > $null
    $find_devices_exit_code = $LASTEXITCODE

    if ($find_devices_exit_code -ne 0) {
        Log -log_type error -failure_type FindDevicesFailed -service_name $service_name -message "Get-AudioDevice: Failed to execute find_devices to find an audio device" -log_file_name $log_file_name
        Throw "Failed to execute find_devices to find an audio device"
    }

    if (-not (Test-Path -Path $find_devices_output_json_file -PathType Leaf)) {
        Log -log_type error -failure_type FileNotFound -service_name $service_name -message "Get-AudioDevice: File '$find_devices_output_json_file' does not exist" -log_file_name $log_file_name
        Throw "File '$find_devices_output_json_file' does not exist. Exiting."
    }

    $find_devices_output = Get-Content -Path $find_devices_output_json_file -Raw | ConvertFrom-Json

    $audio_devices_count = $find_devices_output.audio_devices.Count

    Write-Host "Audio device count: '$audio_devices_count'"

    if ($audio_devices_count -ne 1) {
        Log -log_type error -failure_type SerialPortNotFound -service_name $service_name -message "Get-AudioDevice: Failed to find an audio device." -log_file_name $log_file_name
        Throw "Failed to find an audio device."
    }

    $audio_device = $find_devices_output.audio_devices[0].plughw_id

    Write-Host "Audio device: '$audio_device'"

    return $audio_device
}

function Invoke-Process-Settings-ExitOnError {
    param (
        [string]$settings_file_name,
        [string]$service_name,
        [string]$database_internal_access_config_file_name,
        [string]$action
    )

    try {
        Invoke-Process-Settings -settings_file_name $settings_file_name -service_name $service_name -database_internal_access_config_file_name $database_internal_access_config_file_name -action $action
    }
    catch {
        Write-Host "Function Invoke-Process-Settings execution failed. $($_.Exception.Message)"
        exit 1
    }
}

function Submit-Store-SettingToDB-ExitOnError {
    param (
        [string]$database_internal_access_config_file_name,
        [string]$setting_name,
        [string]$setting_value,        
        [string]$service_name,
        [string]$display_name,
        [string]$description
    )

    try {
        Submit-Store-SettingToDB -database_internal_access_config_file_name $database_internal_access_config_file_name -setting_name $setting_name -setting_value $setting_value -service_name $service_name -display_name $display_name -description $description
    }
    catch {
        Write-Host "Function Submit-Store-SettingToDB execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Get-SettingValue-ExitOnError {
    param (
        [string]$settings_file_name,
        [string]$service_name,
        [string]$setting_name
    )

    try {
        return Get-SettingValue -settings_file_name $settings_file_name -service_name $service_name -setting_name $setting_name    
    }
    catch {
        Write-Host "Function Get-SettingValue execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Wait-ForDatabase-ExitOnError {
    param (
        [string]$database_host_name,
        [int]$database_port_number,
        [string]$database_user_name,
        [string]$database_password
    )

    try {
        Wait-ForDatabase -database_host_name $database_host_name -database_port_number $database_port_number -database_user_name $database_user_name -database_password $database_password   
    }
    catch {
        Write-Error "Function Wait-ForDatabase execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Test-Database {
    param (
        [string]$database_internal_access_config_file_name
    )

    if (-not (Test-Path -Path $database_internal_access_config_file_name -PathType Leaf)) {
        Throw "No database config file found: '$database_internal_access_config_file_name'"
    }

    $query = "SELECT * FROM service"
    $null = mysql --defaults-extra-file=$database_internal_access_config_file_name -B -s -e $query 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Database test unsuccessful."
        return $false
    }

    return $true
}

function Test-Database-ExitOnError {
    param (
        [string]$database_internal_access_config_file_name
    )

    try {
        $result = Test-Database -database_internal_access_config_file_name $database_internal_access_config_file_name
    }
    catch {
        Write-Error "Function Test-Database execution failed. Error: $($_.Exception.Message)"
        exit 1
    }    

    if ($result -ne $true) {
        Write-Error "Function Test-Database execution failed."
        exit 1
    }
}

function New-DatabaseAccessConfig-ExitOnError {
    param (
        [string]$database_internal_access_config_file_name,
        [string]$database_password,
        [string]$database_name,
        [string]$database_user_name,
        [int]$database_port_number,
        [string]$database_host_name
    )

    try {
        New-DatabaseAccessConfig -database_internal_access_config_file_name $database_internal_access_config_file_name -database_password $database_password -database_name $database_name -database_user_name $database_user_name -database_port_number $database_port_number -database_host_name $database_host_name
    }
    catch {
        Write-Error "Function New-DatabaseAccessConfig execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Register-ServiceToDB-ExitOnError {
    param (
        [string]$name,
        [string]$enabled,
        [string]$database_internal_access_config_file_name
    )

    try {
        Register-ServiceToDB -name $name -enabled $enabled -database_internal_access_config_file_name $database_internal_access_config_file_name
    }
    catch {
        Write-Error "Function Register-ServiceToDB execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Get-ServiceEnableStatusFromDB-ExitOnError {
    param (
        [string]$service_name,
        [string]$database_internal_access_config_file_name
    )

    try {
        return Get-ServiceEnabledStatusFromDB -service_name $service_name -database_internal_access_config_file_name $database_internal_access_config_file_name    
    }
    catch {
        Write-Error "Function Get-ServiceEnabledStatusFromDB execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Wait-ServiceEnabled-ExitOnError {
    param (
        [string]$service_name,
        [string]$database_internal_access_config_file_name
    )

    try {
        Wait-ServiceEnabled -service_name $service_name -database_internal_access_config_file_name $database_internal_access_config_file_name
    }
    catch {
        Write-Error "Function Wait-ServiceEnabled execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Read-DataFromSerialPort-ExitOnError {
    param (
        [string]$serial_port,
        [int]$timeout_seconds = 30
    )

    try {
        $result = Read-DataFromSerialPort -serial_port $serial_port -timeout_seconds $timeout_seconds
    }
    catch {
        Write-Error "Function Read-DataFromSerialPort execution failed. Error: $($_.Exception.Message)"
        exit 1
    }

    if ($result -eq $false) {
        Write-Error "Function Read-DataFromSerialPort execution failed."
        exit 1   
    }
}

function Get-SerialPort-ExitOnError {
    param (
        [string]$find_devices_config_file,
        [string]$find_devices_utility,
        [string]$find_devices_output_json_file
    )

    try {
        return Get-SerialPort -find_devices_config_file $find_devices_config_file -find_devices_utility $find_devices_utility -find_devices_output_json_file $find_devices_output_json_file    
    }
    catch {
        Write-Error "Function Get-SerialPort execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Get-AudioDevice-ExitOnError {
    param (
        [string]$find_devices_config_file,
        [string]$find_devices_utility,
        [string]$find_devices_output_json_file
    )

    try {
        return Get-AudioDevice -find_devices_config_file $find_devices_config_file -find_devices_utility $find_devices_utility -find_devices_output_json_file $find_devices_output_json_file    
    }
    catch {
        Write-Host "Function Get-AudioDevice execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

function Test-NotEmpty-ExitOnError {
    param (
        [string]$variable_name,
        [string]$value
    )

    if (-not $value) {
        Write-Host "$variable_name is empty. Exiting."
        exit 1
    }
}

function Test-ValidNumber-ExitOnError {
    param (
        [string]$variable_name,
        [int]$value
    )

    if (-not ($value -is [int])) {
        Write-Host "$variable_name is not a valid number. Exiting."
        exit 1
    }
}

function Test-FileExists-ExitOnError {
    param (
        [string]$file_path
    )

    if (-not (Test-Path -Path $file_path -PathType Leaf)) {
        Write-Error "File '$file_path' does not exist. Exiting."
        exit 1
    }
}

function Invoke-ExitIfServiceDisabled-ExitOnError {
    param (
        [string]$service_name,
        [string]$process_name,
        [string]$web_service_name = $web_service_name,
        [string]$web_service_port = $web_service_port
    )

    try {
        $enable_service_state = Get-ServiceEnabled -service_name $service_name -web_service_name $web_service_name -web_service_port $web_service_port
    }
    catch {
        Write-Error "Function Get-ServiceEnabled execution failed. Error: $($_.Exception.Message)"
        exit 1
    }    

    if ($enable_service_state -eq $False) {
        # Check if the process is running
        $process = Get-Process -Name $process_name -ErrorAction SilentlyContinue

        if ($process) {
            Write-Error "$service_name service disabled but $process_name process running. Exiting."
            exit 1
        }

        # just exit and succeed the check, as we are just waiting to be enabled
        exit 0
    }
}

function Test-If-ServiceDisabled-Exit-ExitOnError {
    param (
        [string]$database_internal_access_config_file_name,
        [string]$service_name,
        [string]$process_name
    )

    try {
        $enable_service_state = Get-ServiceEnabledStatusFromDB -service_name $service_name -database_internal_access_config_file_name $database_internal_access_config_file_name    
    }
    catch {
        Write-Error "Function Get-ServiceEnabledStatusFromDB execution failed. Error: $($_.Exception.Message)"
        exit 1
    }    

    if ($enable_service_state -eq $false) {
        # Check if the process is running
        $process = Get-Process -Name $process_name -ErrorAction SilentlyContinue

        if ($process) {
            Write-Error "$service_name service disabled but $process_name process running. Exiting."
            exit 1
        }

        # just exit and succeed the check, as we are just waiting to be enabled
        exit 0
    }
}

function Test-TcpConnection {
    param (
        [string]$host_name,
        [int]$port_number,
        [int]$timeout_seconds = 15,
        [int]$connection_timeout_seconds = 5,
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? "",
        [bool]$enabled = $True
    )

    if (-not $enabled) {
        Write-Host "Test-TcpConnection test disabled"
        return $true
    }

    $end_time = (Get-Date).AddSeconds($timeout_seconds)
    $exit_code = 1

    while ((Get-Date) -lt $end_time -and $exit_code -ne 0) {
        Write-Host "Attempting connection to TCP on host ""$modem_host_name"" and port ""$modem_kiss_port_number""."        
        & nc -w $connection_timeout_seconds -zv $host_name $port_number > /dev/null 2>&1
        $exit_code = $LASTEXITCODE
        Start-Sleep -Seconds 1
    }

    # & nc -w $timeout_seconds -zv $host_name $port_number > /dev/null 2>&1
    # $exit_code = $LASTEXITCODE

    if ($exit_code -ne 0) {
        Log -log_type error -failure_type TcpConnectionUnsuccessful -service_name $service_name -message "Test-TcpConnection: Failed connecting to TCP host $modem_host_name and port $modem_kiss_port_number" -log_file_name $log_file_name
        return $false
    } else {
        return $true
    }
}

function Test-TcpConnection-ExitOnError {
    param (
        [string]$host_name,
        [int]$port_number,
        [int]$timeout_seconds = 15,
        [bool]$enabled = $True
    )

    $connectionTest = Test-TcpConnection -host_name $host_name -port_number $port_number -timeout_seconds $timeout_seconds -enabled $enabled

    if (-not $connectionTest) {
        Write-Error "Connection to $host_name unsuccessful. Exiting."
        exit 1
    }
}

function Test-TcpConnection-ExitOnSuccess {
    param (
        [string]$host_name,
        [int]$port_number
    )

    $connectionTest = Test-TcpConnection -host_name $host_name -port_number $port_number

    if ($connectionTest -eq $true) {
        Write-Error "Connection to $host_name was successful, port is in use. Exiting."
        exit 1
    }
}

function Test-FetchGpsLocation {
    param (
        [string]$gps_util_file_name,
        [string]$service_name,
        [int]$gpsd_internal_port_number,
        [string]$find_devices_internal_output_json_file_name
    )

    if (-not (Test-Path -Path $gps_util_file_name -PathType Leaf)) {
        Throw "No gps_util executable found: '$gps_util_file_name'"
    }

    if (-not $service_name) {
        Throw "'service_name' is empty."
    }

    if (-not ($gpsd_internal_port_number -is [int])) {
        Throw "'gpsd_internal_port_number' is not a valid number."
    }

    if (-not $find_devices_internal_output_json_file_name) {
        Throw "'find_devices_internal_output_json_file_name' is empty."
    }

    & $gps_util_file_name -h $service_name -p $gpsd_internal_port_number -o $find_devices_internal_output_json_file_name --no-stdout
    $exit_code = $LASTEXITCODE

    if ($exit_code -ne 0) {
        Write-Host "Failed to fetch GPS location."
        return $false
    }

    if (-not (Test-Path -Path $find_devices_internal_output_json_file_name -PathType Leaf)) {
        Throw "No output json file found '$find_devices_internal_output_json_file_name'."
    }

    $jsonContent = Get-Content -Raw -Path $find_devices_internal_output_json_file_name | ConvertFrom-Json
    $lat = [double]$jsonContent.position_dd.lat
    $lon = [double]$jsonContent.position_dd.lon

    $tolerance = 0.000001
    $lat_not_zero = [Math]::Abs($lat) -gt $tolerance
    $lon_not_zero = [Math]::Abs($lon) -gt $tolerance

    if (-not $lat_not_zero -and -not $lon_not_zero) {
        Write-Host "Invalid GPS coordinates, lat or lon is 0. Exiting."
        return $false
    }

    return $true
}

function Test-FetchGpsLocation-ExitOnError {
    param (
        [string]$gps_util_file_name,
        [string]$service_name,
        [int]$gpsd_internal_port_number,
        [string]$find_devices_internal_output_json_file_name
    )

    try {
        $result = Test-FetchGpsLocation -gps_util_file_name $gps_util_file_name -service_name $service_name -gpsd_internal_port_number $gpsd_internal_port_number -find_devices_internal_output_json_file_name $find_devices_internal_output_json_file_name    
    }
    catch {
        Write-Error "Failed to fetch GPS location. Error: $($_.Exception.Message)"
        exit 1
    }
    
    if ($result -ne $true) {
        Write-Error "Failed to fetch GPS location. Exiting."
        exit 1
    }
}

function Test-HttpGetEndpoint {
    param (
        [string]$endpoint_url
    )

    try {
        $null = Invoke-RestMethod -Uri $endpoint_url -Method Get
        return $true
    } catch {
        Write-Output "Error occurred while sending the GET request: $($_.Exception.Message)"
        return $false
    }
}

function Test-HttpGetEndpoint-ExitOnError {
    param (
        [string]$endpoint_url
    )

    $result = Test-HttpGetEndpoint -endpoint_url $endpoint_url

    if ($result -ne $true) {
        Write-Host "Function Test-HttpGetEndpoint execution failed."
        exit 1
    }
}

# Generate-DirewolfConfigFile
function Update-DirewolfConfigFile {
    param (
        [string]$file_path,
        [string]$audio_device,
        [string]$ptt_serial_port, # serial_port
        [string]$callsign,
        [int]$modem_internal_agwp_port, # agwp_port
        [int]$modem_internal_kiss_port, # kiss_port
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )

    if (-not (Test-Path -Path $file_path -PathType Leaf)) {
        Log -log_type error -failure_type FileNotFound -service_name $service_name -message "Update-DirewolfConfigFile: File not found: $file_path" -log_file_name $log_file_name
        Throw "File not found: $file_path"
    }

    if (-not $audio_device) {
        Log -log_type error -failure_type ParameterValueIsEmpty -service_name $service_name -message "Update-DirewolfConfigFile: 'audio_device' is empty." -log_file_name $log_file_name
        Throw "'audio_device' is empty."
    }

    if (-not $ptt_serial_port) {
        Log -log_type error -failure_type ParameterValueIsEmpty -service_name $service_name -message "Update-DirewolfConfigFile: 'ptt_serial_port' is empty." -log_file_name $log_file_name
        Throw "'ptt_serial_port' is empty."
    }

    if (-not $callsign) {
        Log -log_type error -failure_type ParameterValueIsEmpty -service_name $service_name -message "Update-DirewolfConfigFile: 'callsign' is empty." -log_file_name $log_file_name
        Throw "'callsign' is empty."
    }

    if (-not ($modem_internal_agwp_port -is [int])) {
        Log -log_type error -failure_type ParameterValueIsNotANumber -service_name $service_name -message "Update-DirewolfConfigFile: 'modem_internal_agwp_port' is not a valid number." -log_file_name $log_file_name
        Throw "'modem_internal_agwp_port' is not a valid number."
    }

    if (-not ($modem_internal_kiss_port -is [int])) {
        Log -log_type error -failure_type ParameterValueIsNotANumber -service_name $service_name -message "Update-DirewolfConfigFile: 'modem_internal_kiss_port' is not a valid number." -log_file_name $log_file_name
        Throw "'modem_internal_kiss_port' is not a valid number."
    }

    # Read the content of the file
    $content = Get-Content $file_path

    # Perform replacements based on the provided parameters
    $content = $content -replace '@ADEVICE.*', "ADEVICE $audio_device"
    $content = $content -replace '@PTT.*', "PTT $ptt_serial_port RTS"
    $content = $content -replace '@MYCALL.*', "MYCALL $callsign"
    $content = $content -replace '@AGWPORT.*', "AGWPORT $modem_internal_agwp_port"
    $content = $content -replace '@KISSPORT.*', "KISSPORT $modem_internal_kiss_port"

    # Write the updated content back to the file
    $content | Set-Content $file_path
}

function Update-DirewolfConfigFile-ExitOnError {
    try {
        Update-DirewolfConfigFile -file_path $file_path -audio_device $audio_device -ptt_serial_port $ptt_serial_port -callsign $callsign -modem_internal_agwp_port $modem_internal_agwp_port -modem_internal_kiss_port $modem_internal_kiss_port    
    }
    catch {
        Write-Error "Error occurred updating Direwolf configurtion: $($_.Exception.Message)"
        exit 1
    }
}

function Test-AudioDevice-ExitOnError {
    param (
        [string]$audio_device,
        [string]$soundcard_test_wav_file_name,
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )

    if (-not $audio_device) {
        Log -log_type error -failure_type ParameterValueIsEmpty -service_name $service_name -message "Test-AudioDevice-ExitOnError: 'audio_device' is empty." -log_file_name $log_file_name
        Write-Error "'audio_device' is empty."
        exit 1
    }

    if (-not $soundcard_test_wav_file_name) {
        Log -log_type error -failure_type ParameterValueIsEmpty -service_name $service_name -message "Test-AudioDevice-ExitOnError: 'soundcard_test_wav_file_name' is empty." -log_file_name $log_file_name
        Write-Error "'soundcard_test_wav_file_name' is empty."
        exit 1
    }

    # Run arecord command and redirect output to null (suppressing output)
    & arecord -D $audio_device -f S16_LE -c 1 -r 48000 -d 5 $soundcard_test_wav_file_name > $null 2>&1

    # Get the maximum amplitude using sox and store it in $max_amplitude
    $max_amplitude = & sox $soundcard_test_wav_file_name -n stat 2>&1 | Select-String "Maximum amplitude" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }

    # Convert $max_amplitude to a floating-point number
    $max_amplitude = [double]$max_amplitude

    # Print the maximum sound amplitude to the console and the log file
    Write-Output "Max sound amplitude on soundcard ""$audio_device"" is ""$max_amplitude"""

    # Check if max amplitude is less than 0.2 and exit if it is
    if ($max_amplitude -lt 0.2) {
        Log -log_type error -failure_type AudioLevelLow -service_name $service_name -message "Test-AudioDevice-ExitOnError: Could not successfully read a valid buffer of 5 seconds from soundcard '$audio_device'." -log_file_name $log_file_name
        Write-Error "Could not successfully read a valid buffer of 5 seconds from soundcard ""$audio_device"". Exiting."
        exit 1
    }
}

function Test-SerialPort-ExitOnError {
    param (
        [string]$serial_port
    )

    if (-not $serial_port) {
        Write-Error "'serial_port' is empty."
        exit 1
    }

    $null = & stty -F $serial_port 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not successfully connect to serial port $serial_port"
        exit 1
    }
}

function Test-ModemConnection {
    param (
        [string]$modem_host_name,
        [int]$modem_kiss_port_number,
        [int]$duration_in_seconds = 60
    )

    if (-not $modem_host_name) {
        Throw "'modem_host_name' is empty."
    }

    $end_time = (Get-Date).AddSeconds($duration_in_seconds)
    $result = $false

    while ((Get-Date) -lt $end_time -and $result -ne $true) {
        Write-Host "Attempting connection to modem on host ""$modem_host_name"" with port ""$modem_kiss_port_number""."
        $result = Test-TcpConnection -host_name $modem_host_name -port_number $modem_kiss_port_number
        Start-Sleep -Seconds 1
    }

    return $result
}

function Test-ModemConnection-ExitOnError {
    param (
        [string]$modem_host_name,
        [int]$modem_kiss_port_number,
        [int]$duration_in_seconds = 60
    )

    try {
        $result = Test-ModemConnection -modem_host_name $modem_host_name -modem_kiss_port_number $modem_kiss_port_number -duration_in_seconds $duration_in_seconds
    }
    catch {
        Write-Error "Error occurred calling Test-ModemConnection: $($_.Exception.Message)"
        exit 1
    }

    if ($result -ne $true) {
        Write-Error "Test-ModemConnection failed"
        exit 1
    }
}

function Update-APRXConfigFile { # TODO
    param (
        [string]$aprx_internal_working_config_file_name,
        [string]$callsign,
        [string]$aprsis_pass,
        [string]$aprsis_server,
        [string]$modem_host_name,
        [int]$modem_kiss_port_number,
        [string]$lat, # consider simply taking coordinates in DD format
        [string]$lon,
        [string]$aprx_internal_log_directory
    )

    if (-not (Test-Path -Path $aprx_internal_working_config_file_name -PathType Leaf)) {
        Throw "File not found: $aprx_internal_working_config_file_name"
    }

    if (-not $callsign) {
        Throw "'callsign' is empty."
    }

    if (-not $aprsis_pass) {
        Throw "'aprsis_pass' is empty."
    }

    if (-not $aprsis_server) {
        Throw "'aprsis_server' is empty."
    }

    if (-not $modem_host_name) {
        Throw "'modem_host_name' is empty."
    }

    if (-not ($modem_kiss_port_number -is [int])) {
        Throw "'modem_kiss_port_number' is not a valid number."
    }

    if (-not $lat) {
        Throw "'lat' is empty."
    }

    if (-not $lon) {
        Throw "'lon' is empty."
    }

    if (-not (Test-Path -Path $aprx_internal_log_directory -PathType Container)) {
        Throw "Directory not found: $aprx_internal_log_directory"
    }

    (Get-Content $aprx_internal_working_config_file_name) | ForEach-Object {
        $_ -replace '@mycall.*', "mycall $callsign" `
           -replace '@passcode.*', "passcode $aprsis_pass" `
           -replace '@server.*', "server $aprsis_server" `
           -replace '@tcp-device.*', "tcp-device $modem_host_name $modem_kiss_port_number KISS" `
           -replace '@myloc.*', "myloc lat $lat lon $lon" `
           -replace '@rflog.*', "rflog $aprx_internal_log_directory/aprx-rf.log" `
           -replace '@aprxlog.*', "aprxlog $aprx_internal_log_directory/aprx.log" `
           -replace '@dprslog.*', "dprslog $aprx_internal_log_directory/dprs.log"
    } | Set-Content $aprx_internal_working_config_file_name
}

function Update-APRXConfigFile-ExitOnError {
    param (
        [string]$aprx_internal_working_config_file_name,
        [string]$callsign,
        [string]$aprsis_pass,
        [string]$aprsis_server,
        [string]$modem_host_name,
        [int]$modem_kiss_port_number,
        [string]$lat,
        [string]$lon,
        [string]$aprx_internal_log_directory
    )

    try {
        Update-APRXConfigFile -aprx_internal_working_config_file_name $aprx_internal_working_config_file_name `
                              -callsign $callsign `
                              -aprsis_pass $aprsis_pass `
                              -aprsis_server $aprsis_server `
                              -modem_host_name $modem_host_name `
                              -modem_kiss_port_number $modem_kiss_port_number `
                              -lat $lat `
                              -lon $lon `
                              -aprx_internal_log_directory $aprx_internal_log_directory
    }
    catch {
        Write-Error "Error occurred updating APRX configuration: $($_.Exception.Message)"
        exit 1
    }
}

function Initialize-ExitOnError {
    param (
        [string]$database_host_name,
        [int]$database_port_number,
        [string]$database_user_name,
        [string]$database_password,
        [string]$database_internal_access_config_file_name,
        [string]$database_name,
        [string]$service_name,
        [bool]$service_enabled,
        [string]$service_internal_settings_file_name
    )

    Write-Host "Begin initialization."

    try {
        Wait-ForDatabase-ExitOnError -database_host_name $database_host_name -database_port_number $database_port_number -database_user_name $database_user_name -database_password $database_password
        New-DatabaseAccessConfig-ExitOnError -database_internal_access_config_file_name $database_internal_access_config_file_name -database_host_name $database_host_name -database_port_number $database_port_number -database_user_name $database_user_name -database_password $database_password -database_name $database_name
        Register-ServiceToDB-ExitOnError -database_internal_access_config_file_name $database_internal_access_config_file_name -name $service_name -enabled $service_enabled
        Invoke-Process-Settings-ExitOnError -database_internal_access_config_file_name $database_internal_access_config_file_name -settings_file_name $service_internal_settings_file_name -service_name $service_name -action "store"
        Wait-ServiceEnabled-ExitOnError -database_internal_access_config_file_name $database_internal_access_config_file_name -service_name $service_name        
    }
    catch {
        Write-Error "Error occurred: $($_.Exception.Message)"
        exit 1
    }
}

function New-DatabaseConfiguration {
    param(
        [string]$database_internal_data_directory,
        [string]$database_internal_access_config_file_name,
        [string]$database_root_user_name,
        [int]$database_internal_port_number,
        [string]$service_name,
        [string]$database_password,
        [string]$database_name,
        [string]$database_user_name
    )

    Remove-Item -Path $database_internal_access_config_file_name -Force -ErrorAction SilentlyContinue

    @"
[client]
user = $database_root_user_name
port = $database_internal_port_number
host = $service_name
password = $database_password

[mysql]
database = $database_name

[mysqld]
basedir = /usr
port = $database_internal_port_number
bind_address = 0.0.0.0
socket = /var/run/mysqld/mysqld.sock
tmpdir = /tmp
datadir = $database_internal_data_directory
user = $database_user_name
"@ | Set-Content -Path $database_internal_access_config_file_name
}

function Update-DatabaseScriptWithService {
    param (
        [string]$service_name,
        [string]$service_enabled,
        [string]$sql_file_path
    )

    @"
INSERT IGNORE INTO service (name, enabled, date_time)
VALUES ('$service_name', '$service_enabled', NOW());
"@ | Out-File -FilePath $sql_file_path -Append
}

function Update-DatabaseScriptWithServiceSettings {
    param (
        [string]$service_name,
        [string]$service_settings_file_name,
        [string]$sql_file_path
    )

    $settings = Get-Content $service_settings_file_name | ConvertFrom-Json

    foreach ($service in $settings.services) {
        if ($service.name -eq $service_name) {
            foreach ($setting in $service.settings) {
                $setting_name = $setting.name
                $default_value = $setting.default_value
                $display_name = $setting.display_name
                $description = $setting.description
                $editable = $setting.editable

@"
INSERT IGNORE INTO setting (service_id, name, value, editable, display_name, description)
SELECT service.id, '$setting_name', '$default_value', '$editable', '$display_name', '$description'
FROM service
WHERE service.name = '$service_name';
"@ | Out-File -FilePath $sql_file_path -Append
            }
        }
    }
}

function Test-AudioDeviceVolume {
    param (
        [string]$find_devices_config_file,
        [string]$find_devices_utility,
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )
    
    if (-not (Test-Path -Path $find_devices_config_file -PathType Leaf)) {
        Log -log_type error -failure_type FindDevicesConfigNotFound -service_name $service_name -message "Test-AudioDeviceVolume: No find_devices config file found: '$find_devices_config_file'" -log_file_name $log_file_name
        Throw "No find_devices config file found: '$find_devices_config_file'"
    }

    if (-not (Test-Path -Path $find_devices_utility -PathType Leaf)) {
        Log -log_type error -failure_type FindDevicesNotFound -service_name $service_name -message "Test-AudioDeviceVolume: find_devices executable '$find_devices_utility' not found" -log_file_name $log_file_name
        Throw "find_devices executable '$find_devices_utility' not found"
    }

    $temp_file = New-TemporaryFile

    & $find_devices_utility -c $find_devices_config_file --no-stdout -o $temp_file.FullName --no-volume-control --test-volume-control > $null
    $find_devices_exit_code = $LASTEXITCODE

    if ($find_devices_exit_code -ne 0) {
        Log -log_type error -failure_type FindDevicesFailed -service_name $service_name -message "Test-AudioDeviceVolume: find_devices failed, exit code $find_devices_exit_code, output file $temp_file" -log_file_name $log_file_name
        Throw "find_devices failed, exit code $find_devices_exit_code"
    }

    if (-not (Test-Path -Path $temp_file.FullName -PathType Leaf)) {
        Log -log_type error -failure_type FileNotFound -service_name $service_name -message "Test-AudioDeviceVolume: File '$find_devices_output_json_file' does not exist" -log_file_name $log_file_name
        Throw "find_devices output file $($temp_file.FullName) does not exist."
    }

    $find_devices_output = Get-Content -Path $temp_file.FullName -Raw | ConvertFrom-Json

    $volume_control_test_result = $find_devices_output.volume_control_test_result

    Write-Host "Volume test results:"

    foreach ($device in $find_devices_output.audio_devices) {
        foreach ($control in $device.controls) {
            foreach ($channel in $control.channels) {
                Write-Host "Device name: $($device.hw_id), Control name: $($control.name), Channel name: $($channel.name), Channel value: $($channel.volume), Channel type: $($channel.type)"
            }
        }
    }
    
    Remove-Item $temp_file.FullName

    if ($volume_control_test_result -ne "success") {
        Log -log_type error -failure_type SoundCardTestVolumeFailed -service_name $service_name -message "Test-AudioDeviceVolume: find_devices failed the audio volume check" -log_file_name $log_file_name
        Throw "find_devices failed the audio volume check"
    }
}

function Set-AudioDeviceVolume {
    param (
        [string]$find_devices_config_file,
        [string]$find_devices_utility,
        [string]$log_file_name = $log_file_name ?? "log.txt",
        [string]$service_name = $service_name ?? ""
    )

    if (-not (Test-Path -Path $find_devices_config_file -PathType Leaf)) {
        Log -log_type error -failure_type FindDevicesConfigNotFound -service_name $service_name -message "Set-AudioDeviceVolume: No find_devices config file found: '$find_devices_config_file'" -log_file_name $log_file_name
        Throw "No find_devices config file found: '$find_devices_config_file'"
    }

    if (-not (Test-Path -Path $find_devices_utility -PathType Leaf)) {
        Log -log_type error -failure_type FindDevicesNotFound -service_name $service_name -message "Set-AudioDeviceVolume: find_devices executable '$find_devices_utility' not found" -log_file_name $log_file_name
        Throw "find_devices executable '$find_devices_utility' not found"
    }

    & $find_devices_utility -c $find_devices_config_file --no-stdout --disable-file-write > $null
    $find_devices_exit_code = $LASTEXITCODE

    if ($find_devices_exit_code -ne 0) {
        Log -log_type error -failure_type FindDevicesFailed -service_name $service_name -message "Set-AudioDeviceVolume: Failed to execute find_devices to find an audio device" -log_file_name $log_file_name
        Throw "Failed to execute find_devices to find an audio device and set the volume"
    }
}

function Test-AudioDeviceVolume-ExitOnError {
    param (
        [string]$find_devices_config_file,
        [string]$find_devices_utility
    )

    try {
        Test-AudioDeviceVolume -find_devices_config_file $find_devices_config_file -find_devices_utility $find_devices_utility
    }
    catch {
        Write-Error "Function Test-AudioDeviceVolume execution failed. Error: $($_.Exception.Message)"
        exit 1
    }
}

# function Set-AudioDeviceVolume-ExitOnError {
#     param (
#         [string]$audio_device,
#         [string]$find_devices_output_json_file,
#         [int]$playback_volume = 100,
#         [int]$capture_volume = 100,
#         [int]$max_retries = 10
#     )

#     $retry_count = 0

#     while ($retry_count -lt $max_retries) {
#         try {
#             Set-AudioDeviceVolume -audio_device $audio_device -find_devices_output_json_file $find_devices_output_json_file -capture_volume $capture_volume -playback_volume $playback_volume
#             Test-AudioDeviceVolume -audio_device $audio_device -find_devices_output_json_file $find_devices_output_json_file -capture_volume $capture_volume -playback_volume $playback_volume
#             break
#         }
#         catch {
#             $retry_count++
#             Write-Error "Function Set-AudioDeviceVolume execution failed. Error: $($_.Exception.Message)"
#             if ($retry_count -lt $max_retries) {
#                 Write-Host "Retrying..."
#                 Start-Sleep -Seconds 5
#             } else {
#                 exit 1
#             }
#         }
#     }
# }

function Set-AudioDeviceVolume-ExitOnError {
    param (
        [string]$find_devices_config_file,
        [string]$find_devices_utility,
        [int]$max_retries = 10
    )

    $retry_count = 0

    while ($retry_count -lt $max_retries) {
        try {
            Set-AudioDeviceVolume -find_devices_config_file $find_devices_config_file -find_devices_utility $find_devices_utility
            Test-AudioDeviceVolume -find_devices_config_file $find_devices_config_file -find_devices_utility $find_devices_utility
            break
        }
        catch {
            $retry_count++
            Write-Error "Function Set-AudioDeviceVolume execution failed. Error: $($_.Exception.Message)"
            if ($retry_count -lt $max_retries) {
                Write-Host "Retrying..."
                Start-Sleep -Seconds 5
            } else {
                exit 1
            }
        }
    }
}

function Invoke-GenerateDockerEnv {
    param (
        [string]$settings_file,
        [string]$output_file
    )

    if (-not (Test-Path -Path $settings_file -PathType Leaf)) {
        Throw "No settings file found: '$settings_file'"
    }

    Write-Host "Using settings file ""$settings_file"""

    $null = New-Item -Path $output_file -ItemType File -Force

    Add-Content -Path $output_file -Value "# DO NOT DIRECTLY MODIFY. THIS FILE WAS AUTO-GENERATED FROM ""settings.json""."
    Add-Content -Path $output_file -Value "# RUN ""generate_environment.ps1"" TO RE-GENERATE."
    Add-Content -Path $output_file -Value "#"

    $settings = Get-Content -Path $settings_file -Raw | ConvertFrom-Json

    foreach ($service in $settings.services) {
        
        $has_env_variables = $False

        foreach ($setting in $service.settings) {
            if ([string]::IsNullOrEmpty($setting.variable) -ne $True) {
                $has_env_variables = $True
                break
            }
        }

        if ($has_env_variables -eq $True) {
            Add-Content -Path $output_file -Value "# ---------------------------------------------"
            Add-Content -Path $output_file -Value "# $($service.name) service settings"
            Add-Content -Path $output_file -Value "# ---------------------------------------------"
        }

        foreach ($setting in $service.settings) {
            if ([string]::IsNullOrEmpty($setting.variable) -ne $True) {
                Add-Content -Path $output_file -Value "$($setting.variable)=$($setting.value)"
            }
        }
    }
}

function Print-AprxPositionBeacon {
    param (
        [string]$gps_util_utility,
        [string]$gps_service_name,  
        [string]$gps_service_port,
        [string]$comment,
        [string]$symTabId,
        [string]$sym

    )

    if (-not (Test-Path -Path $gps_util_utility -PathType Leaf)) {
        Write-Host "find_devices executable '$gps_util_utility' not found"
        exit 1
    }

    $gps_util_output_json_file = (New-TemporaryFile).FullName

    & $gps_util_utility -h $gps_service_name -p $gps_service_port -o $gps_util_output_json_file --no-stdout
    $gps_util_exit_code = $LASTEXITCODE

    if ($gps_util_exit_code -ne 0) {
        Write-Host "Failed to execute find_devices to find an audio device and set the volume"
        exit 1
    }

    # if gps_util output file does not exist then exit
    if (-not (Test-Path $gps_util_output_json_file)) {
        Write-Host "Error: No output json file found ""$gps_util_output_json_file"""
        exit 1
    }

    # Parse JSON data
    $jsonData = Get-Content $gps_util_output_json_file | ConvertFrom-Json

    $lat = $jsonData.position_ddm_short.lat
    $lon = $jsonData.position_ddm_short.lon
    $day = $jsonData.utc_time.day
    $hour = $jsonData.utc_time.hour
    $min = $jsonData.utc_time.min

    # check that position is not empty
    if ([string]::IsNullOrEmpty($lat) -or [string]::IsNullOrEmpty($lon)) {
        Write-Host "Lat or Long is empty"
        exit 1
    }

    # 
    #  Data Format:
    # 
    #     !   Lat  Sym  Lon  Sym Code   Comment
    #     =
    #    ------------------------------------------
    #     1    8    1    9      1        0-43
    #
    #  Examples:
    #
    #    !4903.50N/07201.75W-Test 001234
    #    !4903.50N/07201.75W-Test /A=001234
    #    !49  .  N/072  .  W-
    #

    $position_no_timestamp = "!" + $lat + $symTabId + $lon + $sym + $comment

    # 
    #  Data Format:
    # 
    #     /   Time  Lat   Sym  Lon  Sym Code   Comment
    #     @
    #    -----------------------------------------------
    #     1    7     8     1    9      1        0-43
    #
    #  Examples:
    #
    #    /092345z4903.50N/07201.75W>Test1234
    #    @092345/4903.50N/07201.75W>Test1234
    #

    $position_with_timestamp = "@$day$hour$minz" + $lat + $symTabId + $lon + $sym + $comment

    Write-Host "$position_with_timestamp"

    exit 0
}