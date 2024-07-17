####################################################################
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
####################################################################

. ./common.ps1

Test-HttpGetEndpoint-ExitOnError -endpoint_url "http://localhost:$env:SVC_CONTROL_WS_REST_PORT/api/v1/services"

exit 0
