Write-Host "Starting web service"

& node /webservice/app.js
$exit_code = $LASTEXITCODE

Write-Host "Web service exited with code $exit_code"

exit $exit_code
