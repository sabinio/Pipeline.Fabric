<#
.SYNOPSIS
    Assign workspace item permissions from an access configuration file.

.DESCRIPTION
    Loads an access config (see access.sample.json next to this script) and applies it to a
    workspace. Permissions cascade: giving a principal a role on a report gives them the
    same role on the semantic model and warehouse behind it.

    Principals are resolved through Microsoft Graph by name - anything containing '@' is
    looked up as a user, everything else as a group - so the account running this needs to
    be able to read users and groups in the directory.

    Roles in the config are mapped to Fabric item permissions:

        admin       -> Admin
        member      -> Admin
        contributor -> Editor
        viewer      -> Viewer

    Run it with -DryRun first. The dry run resolves every item and principal and reports
    exactly what it would assign, without changing anything.

.PARAMETER WorkspaceName
    Display name of the workspace to apply permissions to.

.PARAMETER ConfigPath
    Path to the access configuration JSON. Defaults to the sample beside this script.

.PARAMETER DryRun
    Report what would be assigned without applying it.

.EXAMPLE
    ./03-assign-permissions.ps1 -WorkspaceName myworkspace -DryRun

.EXAMPLE
    ./03-assign-permissions.ps1 -WorkspaceName myworkspace -ConfigPath ../config/access.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$WorkspaceName,

    [string]$ConfigPath = (Join-Path $PSScriptRoot 'access.sample.json'),

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Import-Module Pipeline.Fabric -Force

Connect-Fabric

$workspaceId = Get-FabricWorkspaceId -workspaceName $WorkspaceName
if (-not $workspaceId) {
    throw "Workspace '$WorkspaceName' not found, or you do not have access to it."
}

$accessConfig = Get-AccessConfig -ConfigPath $ConfigPath

$result = Invoke-PermissionAssignment -WorkspaceId $workspaceId `
    -AccessConfig $accessConfig `
    -DryRun:$DryRun

Write-Host ""
Write-Host "Assigned : $($result.SuccessCount)"
Write-Host "Errors   : $($result.ErrorCount)"
Write-Host "Total    : $($result.TotalCount)"

# Items named in the config but missing from the workspace count as errors, so a non-zero
# count usually means the config and the workspace have drifted apart.
if ($result.ErrorCount -gt 0) {
    throw "$($result.ErrorCount) permission assignment(s) failed - see the warnings above."
}
