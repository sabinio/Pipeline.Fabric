function Sync-GitToWorkspace {
    <#
    .SYNOPSIS
        Updates a Fabric workspace from its connected Git repository ("sync git to
        workspace") - i.e. pushes the committed Git state into the workspace.

    .DESCRIPTION
        Uses the Fabric Git integration REST API. Resolves the workspace id from the
        workspace name, then calls updateFromGit to bring the workspace up to the given
        commit. updateFromGit is a long-running operation, so it polls the operation
        until done.

        The target commit is supplied by the caller (-CommitHash) rather than read from
        Fabric's git status, because Fabric's reported remoteCommitHash can lag the real
        remote: in a pipeline the workspace should be updated to the exact commit the
        branch is currently on. Git status is still read, but only to obtain the current
        workspaceHead that updateFromGit requires for its concurrency check.

        Conflict resolution: when items differ between Git and the workspace, the
        requested policy decides which copy wins. 

        The caller must already be authenticated to Fabric (e.g. via Connect-Fabric).
        This function takes no knowledge of project settings - the pipeline wrapper
        translates settings into these explicit parameters.

    .PARAMETER WorkspaceName
        Display name of the Fabric workspace to update.

    .PARAMETER CommitHash
        The Git commit hash to update the workspace to - typically the current commit of
        the branch (git rev-parse HEAD).

    .PARAMETER ConflictResolutionPolicy
        How to resolve item conflicts between Git and the workspace. 'PreferRemote'
        (default) takes the Git copy; 'PreferWorkspace' keeps the workspace copy.

    .EXAMPLE
        Connect-Fabric
        Sync-GitToWorkspace -WorkspaceName 'myworkspace' -CommitHash (git rev-parse HEAD)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceName,
        [Parameter(Mandatory)]
        [string]$CommitHash,
        [ValidateSet("PreferRemote", "PreferWorkspace")]
        [string]$ConflictResolutionPolicy = "PreferWorkspace"
    )

    $WorkspaceId = Get-FabricWorkspaceId -workspaceName $WorkspaceName
    if (-not $WorkspaceId) {
        throw "Workspace '$WorkspaceName' not found."
    }
    # updateFromGit needs the workspace's current head for its concurrency check; read it
    # from git status (the target commit still comes from the caller's -CommitHash).
    write-host "Getting Git status for workspace '$WorkspaceName' ($WorkspaceId)"
    $Changes = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/git/status"
    Write-Host "$($Changes.changes.Count) item(s) changed in workspace '$WorkspaceName'."
    $workspaceHead = $Changes.workspaceHead

    Write-Host "Updating workspace '$WorkspaceName' ($WorkspaceId) from Git to commit '$CommitHash' using conflict policy '$ConflictResolutionPolicy'"

    $updateBody = @{
        remoteCommitHash   = $CommitHash
        workspaceHead      = $workspaceHead
        conflictResolution = @{
            conflictResolutionType   = "Workspace"
            conflictResolutionPolicy = $ConflictResolutionPolicy
        }
        options            = @{
            allowOverrideItems = $true
        }
    }

    # updateFromGit is a long-running operation; Invoke-FabricRestCall polls it to completion.
    Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/git/updateFromGit" -Method Post -Body $updateBody | Out-Null

    Write-Host "Workspace '$WorkspaceName' updated from Git to commit '$CommitHash'."
}

