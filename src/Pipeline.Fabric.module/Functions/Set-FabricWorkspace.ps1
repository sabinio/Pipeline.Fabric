function Set-FabricWorkspace {
    <#
    .SYNOPSIS
        Idempotently provisions a single Fabric workspace container end-to-end.

    .DESCRIPTION
        Creates the workspace if it doesn't exist, assigns it to a capacity, sets the
        standard role assignments (automation service principal, Data Team, Data Admins),
        provisions or deprovisions its managed identity, and optionally connects it to Git.

        This is the single-workspace building block behind the -ProvisionWorkspaces pipeline
        task (pipeline.provision-workspaces.ps1), which calls this once per entry produced by
        Get-FabricWorkspaceTopology. It can equally be called directly to provision or repair
        one workspace.

    .PARAMETER WorkspaceDisplayName
        The workspace's display name, e.g. 'dev_slv_core'.

    .PARAMETER CapacityId
        The Fabric capacity the workspace should be assigned to.

    .PARAMETER FabricAutomationAccountId
        Service principal object id to set as Admin (the CI/CD identity). Skipped if empty.

    .PARAMETER DataTeamGroupId
        Entra group object id to set as Contributor. Skipped if empty, or if -Secure is set.

    .PARAMETER DataAdminsGroupId
        Entra group object id to set as Admin. Skipped if empty.

    .PARAMETER Secure
        Marks the workspace as holding sensitive data (e.g. HR/payroll): the Data Team group
        is not given access - only Data Admins and the automation account are.

    .PARAMETER SetManagedIdentity
        Whether the workspace should have a managed identity provisioned ($true) or
        deprovisioned ($false). Defaults to $true.

    .PARAMETER ConnectGit
        When set, connects the workspace to Git using Repository/DirectoryName/Git* below.

    .PARAMETER Repository
        Git repository name to connect to (required when -ConnectGit is set).

    .PARAMETER DirectoryName
        Directory within the repository to sync, e.g. '/src/core'.

    .PARAMETER GitProviderType
        Git provider type. Defaults to 'GitHub'.

    .PARAMETER GitOwnerName
        Git organisation/owner.

    .PARAMETER GitBranchName
        Branch to connect to. Defaults to 'main'.

    .EXAMPLE
        Set-FabricWorkspace -WorkspaceDisplayName 'dev_slv_core' -CapacityId $capacityId `
            -FabricAutomationAccountId $spId -DataTeamGroupId $dataTeamId -DataAdminsGroupId $dataAdminsId `
            -ConnectGit -Repository 'my-repo' -DirectoryName '/src/silver/core' -GitOwnerName 'MyOrg'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceDisplayName,
        [Parameter(Mandatory)]
        [string]$CapacityId,
        [string]$FabricAutomationAccountId,
        [string]$DataTeamGroupId,
        [string]$DataAdminsGroupId,
        [switch]$Secure,
        [bool]$SetManagedIdentity = $true,
        [switch]$ConnectGit,
        [string]$Repository,
        [string]$DirectoryName,
        [string]$GitProviderType = 'GitHub',
        [string]$GitOwnerName,
        [string]$GitBranchName = 'main'
    )

    Write-Host "`r`n### $WorkspaceDisplayName ###"

    $workspaceId = Get-FabricWorkspaceId -workspaceName $WorkspaceDisplayName
    if (-not $workspaceId) {
        Write-Host "  Creating workspace $WorkspaceDisplayName"
        $workspaceId = New-FabricWorkspace -DisplayName $WorkspaceDisplayName -CapacityId $CapacityId
    }
    else {
        Write-Host "  Workspace $WorkspaceDisplayName already exists ($workspaceId)"
    }

    Set-FabricWorkspaceCapacity -WorkspaceId $workspaceId -CapacityId $CapacityId

    if ($FabricAutomationAccountId) {
        Set-FabricWorkspacePermission -WorkspaceId $workspaceId -Role Admin -PrincipalId $FabricAutomationAccountId -PrincipalType ServicePrincipal
    }
    if ($DataTeamGroupId -and -not $Secure) {
        Set-FabricWorkspacePermission -WorkspaceId $workspaceId -Role Contributor -PrincipalId $DataTeamGroupId -PrincipalType Group
    }
    if ($DataAdminsGroupId) {
        Set-FabricWorkspacePermission -WorkspaceId $workspaceId -Role Admin -PrincipalId $DataAdminsGroupId -PrincipalType Group
    }

    Set-FabricWorkspaceIdentity -WorkspaceId $workspaceId -Enabled $SetManagedIdentity

    if ($ConnectGit) {
        if ([string]::IsNullOrEmpty($Repository)) {
            Write-Warning "  -ConnectGit was set for $WorkspaceDisplayName but no -Repository was supplied - skipping git connection"
        }
        else {
            Connect-FabricWorkspaceGit -WorkspaceId $workspaceId -WorkspaceDisplayName $WorkspaceDisplayName `
                -GitProviderType $GitProviderType -OwnerName $GitOwnerName -RepositoryName $Repository `
                -BranchName $GitBranchName -DirectoryName $DirectoryName
        }
    }

    return $workspaceId
}
