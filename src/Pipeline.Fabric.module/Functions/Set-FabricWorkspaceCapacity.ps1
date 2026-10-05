function Set-FabricWorkspaceCapacity {
    <#
    .SYNOPSIS
        Idempotently ensures a Fabric workspace is assigned to the given capacity.

    .PARAMETER WorkspaceId
        The workspace id.

    .PARAMETER CapacityId
        The capacity the workspace should be assigned to.

    .EXAMPLE
        Set-FabricWorkspaceCapacity -WorkspaceId $workspaceId -CapacityId $capacityId
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,
        [Parameter(Mandatory)]
        [string]$CapacityId
    )

    $workspace = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId"

    if ($workspace.capacityId -eq $CapacityId) {
        Write-Verbose "  Workspace $WorkspaceId already assigned to capacity $CapacityId"
        return
    }

    Write-Host "  Assigning workspace $WorkspaceId to capacity $CapacityId (was $($workspace.capacityId))"
    Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/assignToCapacity" -Method Post -Body @{ capacityId = $CapacityId } | Out-Null
}
