Set-PSRepository -InstallationPolicy trusted

$buildCommand = '.\.build\pipeline-tasks.ps1  -Install -Build -test -Package -Clean'
invoke-expression $buildCommand 

Write-Host "##########################################################"
Write-Host "Windows powershell"
Write-Host "##########################################################"

powershell $buildCommand
Write-Host "##########################################################"
Write-Host "Windows powershell"
Write-Host "##########################################################"
wsl pwsh $buildCommand