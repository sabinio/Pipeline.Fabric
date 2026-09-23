<#
.SYNOPSIS
    Sync the *.sql files in a folder to a warehouse's saved queries, in both directions.

.DESCRIPTION
    The Fabric warehouse editor keeps "saved queries" against the warehouse. This keeps them
    in step with the .sql files in a folder so they can live in source control.

    For every *.sql file in the ROOT of -WarehousePath (subfolders are ignored), where the
    query name is the file name without the extension:

      * file exists, query does not      -> the query is created, shared
      * both exist, same SQL             -> nothing, except a personal query is promoted to shared
      * both exist, different SQL        -> the newer side wins; local newer pushes up,
                                            workspace newer overwrites the local file
      * query exists, file does not      -> a shared query is deleted, a personal one is left alone

    Because it writes to the local files as well as to the warehouse, run it with -WhatIf
    first. Use -ListOnly to just read the saved queries and change nothing at all.

.PARAMETER WorkspaceName
    Workspace holding the warehouse.

.PARAMETER WarehouseName
    Warehouse display name, e.g. myworkspace_dw.

.PARAMETER WarehousePath
    Folder containing the *.sql files.

.PARAMETER ListOnly
    Just list the saved queries currently in the warehouse.

.EXAMPLE
    ./04-sync-warehouse-queries.ps1 -WorkspaceName myworkspace -WarehouseName myworkspace_dw -ListOnly

.EXAMPLE
    ./04-sync-warehouse-queries.ps1 -WorkspaceName myworkspace -WarehouseName myworkspace_dw -WarehousePath ./queries -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$WorkspaceName,

    [Parameter(Mandatory)]
    [string]$WarehouseName,

    [string]$WarehousePath,

    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'

Import-Module Pipeline.Fabric -Force

Connect-Fabric

if ($ListOnly) {
    # Read-only: what the warehouse currently has saved.
    $queries = Get-FabricDWQueries -WorkspaceName $WorkspaceName -WarehouseName $WarehouseName
    $queries |
        Sort-Object queryName |
        Format-Table -AutoSize @{ n = 'Name';     e = { $_.queryName } },
                               @{ n = 'Shared';   e = { $_.isShared } },
                               @{ n = 'Updated';  e = { $_.updatedAt } },
                               @{ n = 'Id';       e = { $_.queryId } }
    Write-Host "$(@($queries).Count) saved quer(ies) in $WarehouseName"
    return
}

if (-not $WarehousePath) {
    throw "Provide -WarehousePath (the folder holding the *.sql files), or use -ListOnly."
}

# -WhatIf flows through from this script, so Sync-FabricDWQueries reports the creates,
# updates, pulls and deletes it would make without performing any of them.
Sync-FabricDWQueries -WorkspaceName $WorkspaceName `
    -WarehouseName $WarehouseName `
    -WarehousePath $WarehousePath
