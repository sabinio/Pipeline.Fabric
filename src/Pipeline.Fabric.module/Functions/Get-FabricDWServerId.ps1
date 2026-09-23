function Get-FabricDWServerId {
    param (
        [string]$workspaceName
    )

    $workspaceId = Get-FabricWorkspaceId -workspaceName $workspaceName
    if (-not $WorkspaceId) {
        throw "Workspace $($WorkspaceSettings.WorkspaceName) not found."
    }   
    $Warehouses = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/warehouses"
    $DWConnections = @{}

    $Warehouses | ForEach-Object {
        $warehouseName = $_.displayName;
        $DWConnections."$warehouseName" = $_.id;
    }
    return $DWConnections
}