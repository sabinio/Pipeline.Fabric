function Get-FabricWorkspaceId {
    param (
        [string]$workspaceName
    )
    $Workspaces = Invoke-FabricRestCall "v1/workspaces"

    # Display the workspaces
    $WorkspaceId = ($Workspaces | Where-Object { $_.displayName -eq $WorkspaceName }).id
    return $WorkspaceId
}