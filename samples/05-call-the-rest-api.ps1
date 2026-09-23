<#
.SYNOPSIS
    Call any Fabric REST endpoint through Invoke-FabricRestCall.

.DESCRIPTION
    Invoke-FabricRestCall is the seam every other command in the module is built on, and it
    is there for the endpoints the module does not wrap. It:

      * acquires the Fabric bearer token from the current Az context,
      * takes a path ('v1/workspaces') or a full URL,
      * unwraps a list response to its '.value' array, and
      * waits out long-running (202 Accepted) operations, unless you pass -NoWait.

    This sample runs a few read-only calls. The last one shows the -NoWait pattern: submit
    several long-running operations, then await them together, which is much faster than
    waiting for each in turn.

    Note the one sharp edge: list endpoints are paged and this helper returns only the first
    page, so a workspace with more items than fit in a page will come back short.

.PARAMETER WorkspaceName
    Workspace to run the example calls against.

.EXAMPLE
    ./05-call-the-rest-api.ps1 -WorkspaceName myworkspace
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$WorkspaceName
)

$ErrorActionPreference = 'Stop'

Import-Module Pipeline.Fabric -Force

Connect-Fabric

$workspaceId = Get-FabricWorkspaceId -workspaceName $WorkspaceName
if (-not $workspaceId) {
    throw "Workspace '$WorkspaceName' not found, or you do not have access to it."
}

# --- a plain list call -------------------------------------------------------------------
Write-Host "=== Workspaces you can see ==="
Invoke-FabricRestCall "v1/workspaces" |
    Sort-Object displayName |
    Select-Object -First 10 displayName, id |
    Format-Table -AutoSize

# --- the folders in a workspace ----------------------------------------------------------
Write-Host "=== Folders in '$WorkspaceName' ==="
$folders = Invoke-FabricRestCall "v1/workspaces/$workspaceId/folders"
if (@($folders).Count -eq 0) {
    Write-Host "(none - everything is at the workspace root)"
}
else {
    $folders | Select-Object displayName, id, parentFolderId | Format-Table -AutoSize
}

# --- a query string, and a single object rather than a list ------------------------------
Write-Host "=== Reports in '$WorkspaceName' ==="
$reports = Invoke-FabricRestCall "v1/workspaces/$workspaceId/items?type=Report"
$reports | Select-Object displayName, id | Format-Table -AutoSize

if (@($reports).Count -gt 0) {
    $report = @($reports)[0]
    Write-Host "=== One report, fetched by id ==="
    # A single-item endpoint returns the object itself, not a '.value' array.
    Invoke-FabricRestCall "v1/workspaces/$workspaceId/items/$($report.id)" |
        Select-Object displayName, type, id, workspaceId |
        Format-List
}

# --- the Org Apps in the workspace, which no wrapper covers ------------------------------
Write-Host "=== Org Apps in '$WorkspaceName' ==="
$orgApps = Invoke-FabricRestCall "v1/workspaces/$workspaceId/orgApps"
if (@($orgApps).Count -eq 0) {
    Write-Host "(none)"
}
else {
    $orgApps | Select-Object displayName, id | Format-Table -AutoSize

    Write-Host "=== Audiences of each Org App ==="
    $audiences = Invoke-FabricRestCall "v1/workspaces/$workspaceId/orgAppAudiences"
    $audiences | Select-Object displayName, id | Format-Table -AutoSize
}

<#
    Submitting long-running operations without waiting for each one
    ---------------------------------------------------------------
    A POST that returns 202 is polled to completion by default. With -NoWait you get a
    'Fabric.PendingOperation' back instead, so several can be in flight at once - this is
    how Deploy-FabricOrgApp deploys all of an app's audiences concurrently:

        $pending = foreach ($item in $items) {
            Invoke-FabricRestCall "v1/workspaces/$workspaceId/<collection>" `
                -Method Post -Body $item -NoWait
        }

        foreach ($operation in $pending) {
            Wait-FabricLongRunningOperation -OperationUrl $operation.OperationUrl `
                -RetryAfter $operation.RetryAfter `
                -Headers $operation.Headers
        }

    Wait-FabricLongRunningOperation is internal to the module, so from outside it you would
    poll $operation.OperationUrl yourself - or simply leave off -NoWait and let each call
    block.
#>
