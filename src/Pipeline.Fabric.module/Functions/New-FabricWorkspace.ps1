function New-FabricWorkspace {
    <#
    .SYNOPSIS
        Creates a new Fabric workspace.

    .DESCRIPTION
        Thin wrapper over POST v1/workspaces. Does not check whether a workspace with the
        same display name already exists - callers that need idempotency (e.g. Set-FabricWorkspace)
        should check with Get-FabricWorkspaceId first.

    .PARAMETER DisplayName
        The workspace display name.

    .PARAMETER CapacityId
        Optional Fabric capacity to assign the workspace to at creation time.

    .EXAMPLE
        New-FabricWorkspace -DisplayName 'dev_slv_core' -CapacityId $capacityId
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,
        [string]$CapacityId
    )

    $body = @{ displayName = $DisplayName }
    if ($CapacityId) { $body.capacityId = $CapacityId }

    $workspace = Invoke-FabricRestCall 'v1/workspaces' -Method Post -Body $body
    return $workspace.id
}
