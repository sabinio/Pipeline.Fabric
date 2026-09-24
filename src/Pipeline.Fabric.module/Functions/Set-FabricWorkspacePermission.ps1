function Set-FabricWorkspacePermission {
    <#
    .SYNOPSIS
        Idempotently ensures a principal has a given role assignment on a Fabric workspace.

    .DESCRIPTION
        Looks up the workspace's existing role assignments; adds a new one if the principal
        has none, updates it if the role differs, or does nothing if it already matches.

    .PARAMETER WorkspaceId
        The workspace id.

    .PARAMETER Role
        The role to assign: Admin, Contributor, Member or Viewer.

    .PARAMETER PrincipalId
        The Entra object id of the user/group/service principal.

    .PARAMETER PrincipalType
        The principal type: User, Group or ServicePrincipal.

    .EXAMPLE
        Set-FabricWorkspacePermission -WorkspaceId $workspaceId -Role Admin -PrincipalId $spId -PrincipalType ServicePrincipal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,
        [Parameter(Mandatory)]
        [ValidateSet('Admin', 'Contributor', 'Member', 'Viewer')]
        [string]$Role,
        [Parameter(Mandatory)]
        [string]$PrincipalId,
        [Parameter(Mandatory)]
        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [string]$PrincipalType
    )

    $existing = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/roleAssignments" |
        Where-Object { $_.principal.id -eq $PrincipalId -and $_.principal.type -eq $PrincipalType }

    if ($existing) {
        if ($existing.role -eq $Role) {
            Write-Verbose "  $PrincipalType $PrincipalId already has $Role on workspace $WorkspaceId"
            return
        }
        Write-Host "  Updating $PrincipalType $PrincipalId from $($existing.role) to $Role on workspace $WorkspaceId"
        Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/roleAssignments/$($existing.id)" -Method Patch -Body @{ role = $Role } | Out-Null
        return
    }

    Write-Host "  Adding $PrincipalType $PrincipalId as $Role on workspace $WorkspaceId"
    Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/roleAssignments" -Method Post -Body @{
        principal = @{ id = $PrincipalId; type = $PrincipalType }
        role      = $Role
    } | Out-Null
}
