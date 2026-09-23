<#
.SYNOPSIS
Invokes permission assignment for Fabric workspace items.

.DESCRIPTION
Assigns cascading permissions to reports, semantic models, and warehouses based on access configuration.
When a user/group is assigned to a report, they automatically receive the same role on the associated
semantic model and warehouse.

.PARAMETER WorkspaceId
The Fabric workspace ID.

.PARAMETER AccessConfig
The access configuration object (from Get-AccessConfig).

.PARAMETER DryRun
If specified, shows what would be done without making changes.

.EXAMPLE
$config = Get-AccessConfig -ConfigPath "config/access.json"
Invoke-PermissionAssignment -WorkspaceId $workspaceId -AccessConfig $config -Verbose

.EXAMPLE
Invoke-PermissionAssignment -WorkspaceId $workspaceId -AccessConfig $config -DryRun -Verbose
#>

function Invoke-PermissionAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,
        
        [Parameter(Mandatory)]
        [object]$AccessConfig,
        
        [switch]$DryRun
    )

    $GraphApiBase = "https://graph.microsoft.com/v1.0"

    $RoleToPermissionMap = @{
        "admin"        = "Admin"
        "member"       = "Admin"
        "contributor"  = "Editor"
        "viewer"       = "Viewer"
    }

    # Helper: Get Graph API token
    function Get-GraphToken {
        try {
            $token = Get-AzAccessToken -ResourceUrl $GraphApiBase -ErrorAction Stop
            return $token.Token
        }
        catch {
            throw "Failed to get Graph API token: $_"
        }
    }

    # Helper: Make Graph API request
    function Invoke-GraphRequest {
        param(
            [ValidateSet("Get", "Post", "Put", "Delete")][string]$Method,
            [string]$Uri,
            [object]$Body
        )
        try {
            $token = Get-GraphToken
            $headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
            $params = @{ Method = $Method; Uri = $Uri; Headers = $headers }
            if ($Body) { $params.Body = $Body | ConvertTo-Json -Depth 10 }
            return Invoke-RestMethod @params -ErrorAction Stop
        }
        catch {
            Write-Error "Graph API request failed [$Method $Uri]: $_"
            throw
        }
    }

    # Helper: Resolve group to object ID
    function Get-GroupObjectId {
        param([string]$GroupName)
        try {
            Write-Verbose "Resolving group: $GroupName"
            $uri = "$GraphApiBase/groups?`$filter=displayName eq '$GroupName'&`$select=id"
            $result = Invoke-GraphRequest -Method Get -Uri $uri
            if ($result.value -and $result.value.Count -gt 0) {
                return $result.value[0].id
            }
            Write-Warning "Group '$GroupName' not found"
            return $null
        }
        catch {
            Write-Error "Error resolving group: $_"
            return $null
        }
    }

    # Helper: Resolve user to object ID
    function Get-UserObjectId {
        param([string]$Email)
        try {
            Write-Verbose "Resolving user: $Email"
            $uri = "$GraphApiBase/users/$Email"
            $result = Invoke-GraphRequest -Method Get -Uri $uri
            if ($result.id) { return $result.id }
            Write-Warning "User '$Email' not found"
            return $null
        }
        catch {
            Write-Error "Error resolving user: $_"
            return $null
        }
    }

    # Helper: Get workspace items using existing Invoke-FabricRestCall
    function Get-WorkspaceItemsDict {
        param([string]$WorkspaceId, [string]$ItemType)
        try {
            Write-Verbose "Fetching $ItemType items"
            $endpoint = "v1/workspaces/$WorkspaceId/items?type=$ItemType"
            $response = Invoke-FabricRestCall -Endpoint $endpoint
            $items = @{}
            foreach ($item in $response) {
                $items[$item.displayName] = $item.id
            }
            return $items
        }
        catch {
            Write-Error "Error fetching items: $_"
            return @{}
        }
    }

    # Helper: Set permission using existing Invoke-FabricRestCall
    function Set-Permission {
        param(
            [string]$WorkspaceId,
            [string]$ItemId,
            [string]$ItemType,
            [string]$PrincipalId,
            [string]$PrincipalType,
            [string]$Role
        )
        try {
            Write-Verbose "Assigning $PrincipalType as $Role to $ItemType"
            if ($DryRun) {
                Write-Host "[DRY RUN] Would assign $Role to $ItemType" -ForegroundColor Cyan
                return $true
            }
            $endpoint = "v1/workspaces/$WorkspaceId/items/$ItemId/permissions"
            $body = @{
                principals = @(@{
                    id   = $PrincipalId
                    type = $PrincipalType
                    role = $Role
                })
            }
            Invoke-FabricRestCall -Endpoint $endpoint -Method Post -Body $body | Out-Null
            return $true
        }
        catch {
            Write-Error "Error setting permission: $_"
            return $false
        }
    }

    Write-Host "Processing access configuration for workspace: $WorkspaceId" -ForegroundColor Green
    if ($DryRun) {
        Write-Host "[DRY RUN MODE] No changes will be applied" -ForegroundColor Yellow
    }

    # Pre-fetch items
    Write-Host "Pre-fetching workspace items..." -ForegroundColor Cyan
    $reports = Get-WorkspaceItemsDict -WorkspaceId $WorkspaceId -ItemType Report
    $semanticModels = Get-WorkspaceItemsDict -WorkspaceId $WorkspaceId -ItemType SemanticModel
    $warehouses = Get-WorkspaceItemsDict -WorkspaceId $WorkspaceId -ItemType Warehouse

    $successCount = 0
    $errorCount = 0

    # Process Reports
    if ($AccessConfig.reports) {
        Write-Host "`n=== Processing Reports ===" -ForegroundColor Cyan
        foreach ($report in $AccessConfig.reports) {
            $reportName = $report.name
            $reportId = $reports[$reportName]
            
            if (-not $reportId) {
                Write-Warning "Report '$reportName' not found"
                $errorCount++
                continue
            }

            Write-Host "Processing report: $reportName" -ForegroundColor Yellow
            foreach ($access in $report.access) {
                $principalName = $access.name
                
                # Determine if principal is group or user based on email pattern
                $isUser = $principalName -like "*@*"
                if ($isUser) {
                    $objectId = Get-UserObjectId -Email $principalName
                    $principalType = "User"
                } else {
                    $objectId = Get-GroupObjectId -GroupName $principalName
                    $principalType = "Group"
                }
                
                if (-not $objectId) { $errorCount++; continue }
                
                # Process each role in the roles array
                foreach ($role in $access.roles) {
                    $mappedRole = $RoleToPermissionMap[$role.ToLower()]
                    if (Set-Permission -WorkspaceId $WorkspaceId -ItemId $reportId -ItemType Report -PrincipalId $objectId -PrincipalType $principalType -Role $mappedRole) {
                        $successCount++
                    } else {
                        $errorCount++
                    }
                }
            }
        }
    }

    # Process Semantic Models
    if ($AccessConfig.semanticModels) {
        Write-Host "`n=== Processing Semantic Models ===" -ForegroundColor Cyan
        foreach ($model in $AccessConfig.semanticModels) {
            $modelName = $model.name
            $modelId = $semanticModels[$modelName]
            
            if (-not $modelId) {
                Write-Warning "Semantic Model '$modelName' not found"
                $errorCount++
                continue
            }

            Write-Host "Processing semantic model: $modelName" -ForegroundColor Yellow
            foreach ($access in $model.access) {
                $principalName = $access.name
                
                # Determine if principal is group or user based on email pattern
                $isUser = $principalName -like "*@*"
                if ($isUser) {
                    $objectId = Get-UserObjectId -Email $principalName
                    $principalType = "User"
                } else {
                    $objectId = Get-GroupObjectId -GroupName $principalName
                    $principalType = "Group"
                }
                
                if (-not $objectId) { $errorCount++; continue }
                
                # Process each role in the roles array
                foreach ($role in $access.roles) {
                    $mappedRole = $RoleToPermissionMap[$role.ToLower()]
                    if (Set-Permission -WorkspaceId $WorkspaceId -ItemId $modelId -ItemType SemanticModel -PrincipalId $objectId -PrincipalType $principalType -Role $mappedRole) {
                        $successCount++
                    } else {
                        $errorCount++
                    }
                }
            }
        }
    }

    # Process Warehouses
    if ($AccessConfig.warehouses) {
        Write-Host "`n=== Processing Warehouses ===" -ForegroundColor Cyan
        foreach ($warehouse in $AccessConfig.warehouses) {
            $warehouseName = $warehouse.name
            $warehouseId = $warehouses[$warehouseName]
            
            if (-not $warehouseId) {
                Write-Warning "Warehouse '$warehouseName' not found"
                $errorCount++
                continue
            }

            Write-Host "Processing warehouse: $warehouseName" -ForegroundColor Yellow
            foreach ($access in $warehouse.access) {
                $principalName = $access.name
                
                # Determine if principal is group or user based on email pattern
                $isUser = $principalName -like "*@*"
                if ($isUser) {
                    $objectId = Get-UserObjectId -Email $principalName
                    $principalType = "User"
                } else {
                    $objectId = Get-GroupObjectId -GroupName $principalName
                    $principalType = "Group"
                }
                
                if (-not $objectId) { $errorCount++; continue }
                
                # Process each role in the roles array
                foreach ($role in $access.roles) {
                    $mappedRole = $RoleToPermissionMap[$role.ToLower()]
                    if (Set-Permission -WorkspaceId $WorkspaceId -ItemId $warehouseId -ItemType Warehouse -PrincipalId $objectId -PrincipalType $principalType -Role $mappedRole) {
                        $successCount++
                    } else {
                        $errorCount++
                    }
                }
            }
        }
    }

    Write-Host "`n--- Summary ---" -ForegroundColor Cyan
    Write-Host "Successfully assigned: $successCount permissions" -ForegroundColor Green
    Write-Host "Errors: $errorCount"

    return @{
        SuccessCount = $successCount
        ErrorCount   = $errorCount
        TotalCount   = $successCount + $errorCount
    }
}
