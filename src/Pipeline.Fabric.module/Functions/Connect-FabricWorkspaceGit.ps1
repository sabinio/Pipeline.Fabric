function Connect-FabricWorkspaceGit {
    <#
    .SYNOPSIS
        Idempotently connects a Fabric workspace to its Git repository and initializes it.

    .DESCRIPTION
        - If the workspace has no Git connection yet, connects it to the given repository/
          branch/directory (using a stored Fabric connection matching ConnectionNamePattern
          for credentials) and initializes it with strategy 'None' (workspace content wins).
        - If already connected but not yet initialized, ensures the caller's Git credentials
          point at the configured connection and initializes it.
        - If already connected and initialized, just re-confirms the Git credentials.

    .PARAMETER WorkspaceId
        The workspace id.

    .PARAMETER WorkspaceDisplayName
        Display name, used only for log messages.

    .PARAMETER GitProviderType
        e.g. 'GitHub'.

    .PARAMETER OwnerName
        Git organisation/owner.

    .PARAMETER RepositoryName
        Repository name.

    .PARAMETER BranchName
        Branch to connect to. Defaults to 'main'.

    .PARAMETER DirectoryName
        Directory within the repository to sync, e.g. '/src/core'.

    .PARAMETER ConnectionNamePattern
        Display-name substring used to select the stored Fabric connection representing the
        Git credentials to use. Defaults to 'GitHub'.

    .EXAMPLE
        Connect-FabricWorkspaceGit -WorkspaceId $id -WorkspaceDisplayName 'dev_slv_core' `
            -OwnerName 'MyOrg' -RepositoryName 'my-repo' -DirectoryName '/src/silver/core'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,
        [string]$WorkspaceDisplayName = $WorkspaceId,
        [string]$GitProviderType = 'GitHub',
        [Parameter(Mandatory)]
        [string]$OwnerName,
        [Parameter(Mandatory)]
        [string]$RepositoryName,
        [string]$BranchName = 'main',
        [Parameter(Mandatory)]
        [string]$DirectoryName,
        [string]$ConnectionNamePattern = 'GitHub'
    )

    $connectionId = Get-FabricGitConnectionId -NamePattern $ConnectionNamePattern

    $gitConnection = $null
    try {
        $gitConnection = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/git/connection"
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
            Write-Verbose "  No git connection found yet for workspace $WorkspaceDisplayName"
        }
        else {
            throw
        }
    }

    if (-not $gitConnection -or $gitConnection.gitConnectionState -eq 'NotConnected') {
        Write-Host "  Connecting workspace $WorkspaceDisplayName to $OwnerName/$RepositoryName ($DirectoryName@$BranchName)"
        Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/git/connect" -Method Post -Body @{
            gitProviderDetails = @{
                gitProviderType = $GitProviderType
                ownerName       = $OwnerName
                repositoryName  = $RepositoryName
                branchName      = $BranchName
                directoryName   = $DirectoryName
            }
            myGitCredentials  = @{
                source       = 'ConfiguredConnection'
                connectionId = $connectionId
            }
        } | Out-Null

        Write-Host "  Initializing git connection for workspace $WorkspaceDisplayName"
        Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/git/initializeConnection" -Method Post -Body @{ initializationStrategy = 'None' } | Out-Null
        return
    }

    Write-Host "  Ensuring git credentials for workspace $WorkspaceDisplayName use the configured connection"
    Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/git/myGitCredentials" -Method Patch -Body @{
        source       = 'ConfiguredConnection'
        connectionId = $connectionId
    } | Out-Null

    if ($gitConnection.gitConnectionState -eq 'Connected') {
        Write-Host "  Initializing git connection for workspace $WorkspaceDisplayName"
        Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/git/initializeConnection" -Method Post -Body @{ initializationStrategy = 'None' } | Out-Null
    }
    else {
        Write-Verbose "  Git connection for workspace $WorkspaceDisplayName already $($gitConnection.gitConnectionState)"
    }
}
