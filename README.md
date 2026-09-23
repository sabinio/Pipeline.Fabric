# Introduction

PowerShell module for deploying to and managing Microsoft Fabric workspaces from a CI/CD pipeline.

It wraps the Fabric REST API and the [fabric-cicd](https://microsoft.github.io/fabric-cicd/) Python
publisher so a pipeline can deploy a repository of Fabric items, deploy the Org Apps that
fabric-cicd does not publish, assign workspace permissions, and sync saved warehouse queries.

## Installation

```powershell
Install-Module Pipeline.Fabric -Repository PSGallery
```

## Prerequisites

- PowerShell 7.0 or higher
- `Az.Accounts` — supplies the `Connect-AzAccount` / `Get-AzAccessToken` used to authenticate to
  Fabric. It is not declared in `RequiredModules` so consumers stay in control of the Az version
  they install.
- `python` with `fabric_cicd` installed — only needed for `Deploy-FabricItems`, which shells out to
  the bundled `scripts/fabric-cicd-deploy.py`.
- Network access to the Fabric API (`api.fabric.microsoft.com`), the Power BI API
  (`api.powerbi.com`) and, for permission assignment, Microsoft Graph.

## Commands

|Command|Purpose|
|-|-|
|`Connect-Fabric`|Authenticate to Fabric, interactively or with a service principal.|
|`Deploy-FabricItems`|Deploy the items in a repository directory to a workspace via fabric-cicd.|
|`Deploy-FabricOrgApp`|Deploy an Org App and its audiences, which fabric-cicd does not publish.|
|`Invoke-PermissionAssignment`|Assign cascading permissions to reports, semantic models and warehouses.|
|`Get-AccessConfig`|Load the access configuration used by `Invoke-PermissionAssignment`.|
|`Get-FabricWorkspaceId`, `Get-FabricItems`|Resolve a workspace id and list its items.|
|`Get-FabricDWServer`, `Get-FabricDWServerId`|Resolve warehouse connection strings and ids.|
|`Get-FabricDWQueries`, `Sync-FabricDWQueries`|Read and synchronise a warehouse's saved SQL queries.|
|`Sync-GitToWorkspace`|Sync a Git-connected workspace.|
|`Invoke-FabricRestCall`|Call any Fabric REST endpoint, handling auth and long-running operations.|

## Usage

```powershell
Import-Module Pipeline.Fabric

Connect-Fabric

Deploy-FabricItems -Environment prd `
    -WorkspaceName "myworkspace" `
    -Workspace myworkspace `
    -RepositoryDirectory src/myworkspace `
    -ItemsInScope "Report,SemanticModel,Warehouse"

Deploy-FabricOrgApp -WorkspaceName "myworkspace" -Path src/myworkspace/Apps/Reports.OrgApp -FolderPath Apps
```

Every command supports `-Verbose`, and the ones that change a workspace support `-WhatIf`.

## Documentation

Docs are generated from the comment-based help to the [docs folder](docs/Home.md) using `platyPS`,
and published to the GitHub wiki on push to `main`.

## Contributing

See [Contributing](Contributing.md) for the build, test and publish tasks.
