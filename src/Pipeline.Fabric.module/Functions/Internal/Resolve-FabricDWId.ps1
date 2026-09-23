function Resolve-FabricDWId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName,
        [Parameter(Mandatory = $true)]
        [string]$WarehouseName
    )

    $warehouses = Get-FabricDWServerId -workspaceName $WorkspaceName
    $id = $warehouses.$WarehouseName
    if (-not $id) {
        throw "Warehouse '$WarehouseName' not found in workspace '$WorkspaceName'."
    }
    return $id
}
