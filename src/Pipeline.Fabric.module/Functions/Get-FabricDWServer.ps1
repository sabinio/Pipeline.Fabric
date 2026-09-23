
function Get-FabricDWServer {
    param (
        [string]$workspaceName
    )

    $WorkspaceId = Get-FabricWorkspaceId -workspaceName $workspaceName
    if (-not $WorkspaceId) {
        throw "Workspace '$workspaceName' not found."
    }
    $Warehouses = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/warehouses"
    $DWConnections = @{}

    $Warehouses | ForEach-Object {
        $warehouseName = $_.displayName;
        $DWConnections."$warehouseName" = $_.properties.connectionString;
    }
    return $DWConnections
}
