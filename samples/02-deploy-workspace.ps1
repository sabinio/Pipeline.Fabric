<#
.SYNOPSIS
    Deploy a repository of Fabric items to a workspace, then deploy its Org Apps.

.DESCRIPTION
    This is the shape of a real deployment stage, in the order that matters:

      1. Deploy-FabricItems publishes the items (reports, semantic models, warehouses, ...)
         through fabric-cicd.
      2. Deploy-FabricOrgApp then publishes any Org Apps found in the source tree.

    The order is not optional. fabric-cicd does not publish OrgApp / OrgAppAudience items,
    which is why step 2 exists, and an Org App's audiences reference the reports by id - so
    those reports have to be in the workspace already or the org app deployment will fail
    with "Report '<name>' ... was not found in the target workspace".

    Each '*.OrgApp' folder is deployed into the workspace folder matching its location in the
    source tree, so 'src/myworkspace/Apps/Reports.OrgApp' lands in a workspace folder 'Apps'.

.PARAMETER WorkspaceName
    Display name of the target workspace.

.PARAMETER RepositoryDirectory
    The directory holding the Fabric item folders to deploy, e.g. 'src/myworkspace'.

.PARAMETER Environment
    Environment name, used to pick the fabric-cicd parameter file (parameter.<env>.yml).

.PARAMETER ItemsInScope
    Comma separated fabric-cicd item types to publish.

.PARAMETER OnlyChanged
    Publish only the items that have changed.

.PARAMETER SkipOrgApps
    Deploy the items but not the Org Apps.

.EXAMPLE
    ./02-deploy-workspace.ps1 -WorkspaceName myworkspace -RepositoryDirectory src/myworkspace -Environment dev

.EXAMPLE
    # See what the org app deployment would do without touching the workspace
    ./02-deploy-workspace.ps1 -WorkspaceName myworkspace -RepositoryDirectory src/myworkspace -Environment dev -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$WorkspaceName,

    [Parameter(Mandatory)]
    [string]$RepositoryDirectory,

    [Parameter(Mandatory)]
    [string]$Environment,

    [string]$ItemsInScope = 'Report,SemanticModel,Notebook,Lakehouse,Warehouse,DataPipeline,VariableLibrary',

    [switch]$OnlyChanged,

    [switch]$SkipOrgApps
)

$ErrorActionPreference = 'Stop'

Import-Module Pipeline.Fabric -Force

Connect-Fabric

# ---------------------------------------------------------------------------------------
# 1. Items, via fabric-cicd. Needs python with the fabric_cicd package installed.
#
# Deploy-FabricItems has no -WhatIf of its own, so it is guarded here - otherwise running
# this sample with -WhatIf would still publish every item for real and only the org app
# step would be a preview.
# ---------------------------------------------------------------------------------------
if ($PSCmdlet.ShouldProcess("workspace '$WorkspaceName'", "Deploy items ($ItemsInScope) from $RepositoryDirectory")) {
    Deploy-FabricItems -Environment $Environment `
        -WorkspaceName $WorkspaceName `
        -Workspace $WorkspaceName `
        -RepositoryDirectory $RepositoryDirectory `
        -ItemsInScope $ItemsInScope `
        -OnlyChanged:$OnlyChanged
}

if ($SkipOrgApps) {
    Write-Host "SkipOrgApps set - not deploying Org Apps."
    return
}

# ---------------------------------------------------------------------------------------
# 2. Org Apps, via the dedicated OrgApp / OrgAppAudience REST APIs.
# ---------------------------------------------------------------------------------------
$orgApps = @(Get-ChildItem -Path $RepositoryDirectory -Directory -Recurse -Filter '*.OrgApp' -ErrorAction SilentlyContinue)
if ($orgApps.Count -eq 0) {
    Write-Host "No '*.OrgApp' folders under $RepositoryDirectory - nothing more to deploy."
    return
}

$repositoryRoot = (Resolve-Path $RepositoryDirectory).Path
foreach ($orgApp in $orgApps) {
    # Put the app in the workspace folder that mirrors where it sits in the source tree.
    $folderPath = [System.IO.Path]::GetRelativePath($repositoryRoot, $orgApp.Parent.FullName).Replace('\', '/')
    if ($folderPath -eq '.') { $folderPath = '' }

    Write-Host "Deploying Org App $($orgApp.FullName) into workspace folder '$folderPath'"
    Deploy-FabricOrgApp -WorkspaceName $WorkspaceName `
        -Path $orgApp.FullName `
        -FolderPath $folderPath
}
