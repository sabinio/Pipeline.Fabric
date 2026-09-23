<#
.SYNOPSIS
    Connect to Fabric and list what is in a workspace.

.DESCRIPTION
    The "hello world" for this module. Authenticates, resolves the workspace id from its
    display name, lists the items in it (optionally filtered by type) and reports the
    warehouses with their connection strings.

    Nothing here changes anything, so it is the safe way to check that authentication and
    workspace access are working before running any of the other samples.

.PARAMETER WorkspaceName
    Display name of the workspace to inspect.

.PARAMETER Type
    Optional item types to list. Omit to list everything in the workspace.

.PARAMETER ExportPath
    Optional path to write the item list to as JSON.

.EXAMPLE
    ./01-explore-workspace.ps1 -WorkspaceName myworkspace

.EXAMPLE
    ./01-explore-workspace.ps1 -WorkspaceName myworkspace -Type Report,SemanticModel -ExportPath items.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$WorkspaceName,

    [string[]]$Type,

    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

Import-Module Pipeline.Fabric -Force

# Connect-Fabric is a no-op when there is already an Az context, so it is safe to call every time.
# Pass -ClientId/-ClientSecretSecure/-TenantId instead to sign in as a service principal.
Connect-Fabric

$workspaceId = Get-FabricWorkspaceId -workspaceName $WorkspaceName
if (-not $workspaceId) {
    throw "Workspace '$WorkspaceName' not found, or you do not have access to it."
}
Write-Host "Workspace '$WorkspaceName' is $workspaceId"

# With no -Type, Get-FabricItems returns every item in the workspace.
$items = if ($Type) {
    foreach ($itemType in $Type) {
        Get-FabricItems -WorkspaceId $workspaceId -Type $itemType
    }
}
else {
    Get-FabricItems -WorkspaceId $workspaceId
}

$items |
    Sort-Object type, displayName |
    Format-Table -AutoSize @{ n = 'Type'; e = { $_.type } },
                           @{ n = 'Name'; e = { $_.displayName } },
                           @{ n = 'Id';   e = { $_.id } }

Write-Host ""
Write-Host "$(@($items).Count) item(s) in '$WorkspaceName'"

# Warehouses are worth calling out separately - the connection string is what you point
# SSMS, sqlcmd or a semantic model at.
$warehouses = Get-FabricDWServer -workspaceName $WorkspaceName
if ($warehouses.Count -gt 0) {
    Write-Host ""
    Write-Host "Warehouses:"
    foreach ($warehouse in $warehouses.GetEnumerator()) {
        Write-Host "  $($warehouse.Key) -> $($warehouse.Value)"
    }
}

if ($ExportPath) {
    $items | ConvertTo-Json -Depth 5 | Set-Content -Path $ExportPath -Encoding utf8
    Write-Host ""
    Write-Host "Wrote $(@($items).Count) item(s) to $ExportPath"
}
