param(
    [string]$GPS_SETTINGS_FILE_NAME = "./settings.json",
    [string]$ENV_FILE_NAME = "./.env"
)

Write-Host "Running generate_environment.ps1"
Write-Host ""

Write-Host "Script variables:"
Write-Host ""
Write-Host "`$GPS_SETTINGS_FILE_NAME: `"$GPS_SETTINGS_FILE_NAME`""
Write-Host "`$ENV_FILE_NAME: `"$ENV_FILE_NAME`""
Write-Host ""
Write-Host "Generating `"$ENV_FILE_NAME`""
Write-Host ""

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

Invoke-GenerateDockerEnv -settings_file $GPS_SETTINGS_FILE_NAME -output_file ./.env

