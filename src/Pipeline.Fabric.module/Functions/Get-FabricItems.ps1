function Get-FabricItems {
    <#
    .SYNOPSIS
        List the items in a Fabric workspace.

    .DESCRIPTION
        Calls the Fabric REST API (v1/workspaces/{workspaceId}/items) and returns the items
        in the workspace. Optionally filter to a single item type (e.g. Warehouse, Lakehouse,
        Notebook, SemanticModel, Report, DataPipeline).

    .PARAMETER WorkspaceId
        The workspace id. If omitted it is resolved from WorkspaceName.

    .PARAMETER WorkspaceName
        Workspace display name to resolve the id from when WorkspaceId is not supplied.

    .PARAMETER Type
        Optional item type to filter by (e.g. Warehouse, Lakehouse, Notebook).

    .EXAMPLE
        Get-FabricItems -WorkspaceName 'myworkspace' -Type Warehouse
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string]$WorkspaceName,

        [string]$Type
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $WorkspaceId = Get-FabricWorkspaceId -workspaceName $WorkspaceName
        if (-not $WorkspaceId) {
            throw "Workspace '$WorkspaceName' not found."
        }
    }

    $endpoint = "v1/workspaces/$WorkspaceId/items"
    if ($Type) {
        $endpoint += "?type=$Type"
    }

    return Invoke-FabricRestCall $endpoint
}
