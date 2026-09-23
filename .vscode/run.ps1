
param (
    $file,
    [string[]]
    $code
)

$psscriptroot = $file
$allcode = $code -join "`n"
Write-Host "-------------------------------------------------------"
Write-host $allcode
Write-Host "-------------------------------------------------------"
Write-host $file
Write-Host "-------------------------------------------------------"
Invoke-Expression $allcode