<#
.SYNOPSIS
    Get and synchronise saved (shared/personal) SQL queries for a Fabric Warehouse.

.DESCRIPTION
    The Fabric Warehouse editor stores saved SQL queries against an internal Power BI
    (wabi) OData endpoint:

        {BaseUrl}/v1.0/myorg/datawarehouses/{DatawarehouseId}/queries

    These functions call that endpoint. Unlike the public Fabric REST API
    (api.fabric.microsoft.com) this endpoint is authenticated with a Power BI token
    (resource https://analysis.windows.net/powerbi/api).

    Sync-FabricDWQueries reads every *.sql file in the ROOT of the warehouse project
    folder (non-recursive) and, comparing against the queries already saved in the
    warehouse, updates any whose SQL differs and creates any that do not yet exist.
#>


function Sync-FabricDWQueries {
    <#
    .SYNOPSIS
        Sync the *.sql files in the root of the warehouse folder to the warehouse's saved queries.

    .DESCRIPTION
        For every *.sql file directly inside WarehousePath (subfolders are ignored) this:
          * creates a saved query when none with the same name exists, and
          * updates the saved query when the stored SQL differs from the file.

        The query name is the file name without the .sql extension. The SQL expression
        is the raw file content.

    .PARAMETER DatawarehouseId
        The warehouse id. If omitted it is resolved from WorkspaceName + WarehouseName.

    .PARAMETER WorkspaceName
        Workspace to resolve the warehouse id from when DatawarehouseId is not supplied.

    .PARAMETER WarehouseName
        Warehouse display name used for resolution. Required with WorkspaceName.

    .PARAMETER WarehousePath
        Path to the root warehouse folder that contains the *.sql query files.

    .PARAMETER WhatIf
        Report the actions that would be taken without calling the API.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$DatawarehouseId,

        [string]$WorkspaceName,
        [string]$WarehouseName,

        [Parameter(Mandatory = $true)]
        [string]$WarehousePath,

        [string]$BaseUrl = "https://api.powerbi.com"
    )

    if (-not $DatawarehouseId) {
        if (-not $WorkspaceName) {
            throw "Provide either -DatawarehouseId or -WorkspaceName."
        }
        if (-not $WarehouseName) {
            throw "Provide -WarehouseName to resolve the warehouse id from -WorkspaceName."
        }
        $DatawarehouseId = Resolve-FabricDWId -WorkspaceName $WorkspaceName -WarehouseName $WarehouseName
    }

    if (-not (Test-Path $WarehousePath)) {
        throw "Warehouse path not found: $WarehousePath"
    }

    Write-Host "Syncing queries to warehouse $DatawarehouseId"

    # Local *.sql files in the ROOT of the warehouse folder (non-recursive), keyed by query name.
    $local = @{}
    foreach ($file in (Get-ChildItem -Path $WarehousePath -Filter *.sql -File)) {
        $local[$file.BaseName] = $file
    }

    # Workspace (remote) saved queries keyed by name. Keep the most recently updated when a
    # name appears more than once.
    $existing = @{}
    foreach ($query in (Get-FabricDWQueries -DatawarehouseId $DatawarehouseId -BaseUrl $BaseUrl)) {
        if (-not $existing.ContainsKey($query.queryName) -or
            $query.updatedAt -gt $existing[$query.queryName].updatedAt) {
            $existing[$query.queryName] = $query
        }
    }

    $created = 0; $updated = 0; $pulled = 0; $removed = 0; $unchanged = 0

    $names = [System.Collections.Generic.HashSet[string]]::new([string[]](@($local.Keys) + @($existing.Keys)))

    foreach ($name in $names) {
        $file = $local[$name]
        $match = $existing[$name]

        # Workspace missing, local present -> create as a shared query.
        if ($null -eq $match) {
            write-host "Need to Add file $file"

            $sqlExpression = Get-FileSql $file
            if ($PSCmdlet.ShouldProcess($name, "Create query")) {
                Invoke-FabricDWQueryApi -DatawarehouseId $DatawarehouseId -Method Post -BaseUrl $BaseUrl -Body ([ordered]@{
                        queryName     = $name
                        sqlExpression = $sqlExpression
                        mExpression   = $null
                        isShared      = $true
                    }) | Out-Null
                Write-Host "  + Created '$name'"
            }
            $created++
            continue
        }

        # Workspace present, local missing.
        if ($null -eq $file) {
            if ($match.isShared) {
                write-host "Need to remove file $name ($($match.queryId))"
                # Orphaned shared query -> remove it from the workspace.
                if ($PSCmdlet.ShouldProcess($name, "Remove query $($match.queryId)")) {
                    Invoke-FabricDWQueryApi -DatawarehouseId $DatawarehouseId -Method Delete  -BaseUrl $BaseUrl -Body ([ordered]@{
                            queryName = $name
                            queryId   = $match.queryId
                            updatedAt = $match.updatedAt
                        }) | Out-Null
                    Write-Host "  - Removed '$name' (id $($match.queryId))"
                }
                $removed++
            }
            else {
                # Personal (non-shared) query with no local file -> leave it alone.
                $unchanged++
            }
            continue
        }

        # Both present.
        $sqlExpression = Get-FileSql $file

        if (Compare-QuerySql $match.sqlExpression $sqlExpression) {
            # Same SQL. Promote to shared if it is not already; otherwise nothing to do.
            if (-not $match.isShared) {
                
                write-host "Make query shared $name ($($match.queryId))"
                if ($PSCmdlet.ShouldProcess($name, "Share query $($match.queryId)")) {
                    Invoke-FabricDWQueryApi -DatawarehouseId $DatawarehouseId -Method Put  -BaseUrl $BaseUrl -Body ([ordered]@{
                            isShared      = $true
                            queryId       = $match.queryId
                            queryName     = $name
                            sqlExpression = $sqlExpression
                            updatedAt     = $match.updatedAt
                        }) | Out-Null
                    Write-Host "  ~ Shared '$name' (id $($match.queryId))"
                }
                $updated++
            }
            else {
                $unchanged++
            }
            continue
        }

        # Different SQL - newest side wins.
        if ($file.LastWriteTime -gt $match.updatedAt) {
            # Local is newest -> push to the workspace (as shared).
            Write-Host "Updating query as this one is newer"
            if ($PSCmdlet.ShouldProcess($name, "Update query $($match.queryId)")) {
                Invoke-FabricDWQueryApi -DatawarehouseId $DatawarehouseId -Method Put  -BaseUrl $BaseUrl -Body ([ordered]@{
                        isShared      = $true
                        queryId       = $match.queryId
                        queryName     = $name
                        sqlExpression = $sqlExpression
                        updatedAt     = $match.updatedAt
                    }) | Out-Null
                Write-Host "  ~ Updated '$name' (id $($match.queryId))"
            }
            $updated++
        }
        else {
            # Workspace is newest -> pull down to the local file.
            if ($PSCmdlet.ShouldProcess($file.FullName, "Update local file")) {
                Set-Content -Path $file.FullName -Value $match.sqlExpression -NoNewline
                Write-Host "  v Updated local '$name'"
            }
            $pulled++
        }
    }

    Write-Host "Done. Created: $created, Updated: $updated, Pulled: $pulled, Removed: $removed, Unchanged: $unchanged"
}
