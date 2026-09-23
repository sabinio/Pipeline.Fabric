<#
.SYNOPSIS
Loads access configuration from a JSON file.

.DESCRIPTION
Reads and parses the access configuration JSON file that defines user/group access
to reports with cascading permissions to semantic models and warehouses.

.PARAMETER ConfigPath
Path to the access.json configuration file.

.EXAMPLE
$config = Get-AccessConfig -ConfigPath "config/access.json"

.EXAMPLE
$config = Get-AccessConfig -ConfigPath "config/access.json" -Verbose
#>

function Get-AccessConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    try {
        Write-Verbose "Loading access configuration from: $ConfigPath"
        
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }

        $jsonContent = Get-Content -Path $ConfigPath -Raw
        $config = ConvertFrom-Json -InputObject $jsonContent
        
        Write-Verbose "Access configuration loaded successfully"
        return $config
    }
    catch {
        Write-Error "Error loading configuration: $_"
        throw
    }
}
