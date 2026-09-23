function Get-FabricDWQueries {
    <#
    .SYNOPSIS
        Return the saved queries for a Fabric Warehouse.

    .PARAMETER DatawarehouseId
        The warehouse (datawarehouse) id, e.g. 00000000-0000-0000-0000-000000000000.

    .PARAMETER WorkspaceName
        Alternative to DatawarehouseId - resolve the id from the workspace + warehouse name.

    .PARAMETER WarehouseName
        Warehouse display name to resolve when using WorkspaceName.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [string]$DatawarehouseId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string]$WorkspaceName,
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string]$WarehouseName,

        [string]$BaseUrl = "https://api.powerbi.com"
    )
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $DatawarehouseId = Resolve-FabricDWId -WorkspaceName $WorkspaceName -WarehouseName $WarehouseName
    }

    write-host "Getting queries from Fabric"
    $response = Invoke-FabricDWQueryApi -DatawarehouseId $DatawarehouseId -Method Get -BaseUrl $BaseUrl
    return $response.value
}
