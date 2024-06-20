. ./common.ps1

Test-HttpGetEndpoint-ExitOnError -endpoint_url "http://localhost:$env:SVC_CONTROL_WS_REST_PORT/api/v1/services"

exit 0
