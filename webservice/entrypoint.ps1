####################################################################
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
####################################################################

Write-Host "Starting web service"

& node /webservice/app.js
$exit_code = $LASTEXITCODE

Write-Host "Web service exited with code $exit_code"

exit $exit_code
