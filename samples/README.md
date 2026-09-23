# Pipeline.Fabric samples

Runnable examples of the module. Each script is self-contained, takes a workspace name, and
has comment-based help (`Get-Help ./01-explore-workspace.ps1 -Full`).

They are ordered roughly as you would use them: look at a workspace, deploy to it, secure it,
then the two specialised jobs.

| Script | What it shows | Changes anything? |
|-|-|-|
| [01-explore-workspace.ps1](01-explore-workspace.ps1) | `Connect-Fabric`, `Get-FabricWorkspaceId`, `Get-FabricItems`, `Get-FabricDWServer` — list a workspace and its warehouses | No |
| [02-deploy-workspace.ps1](02-deploy-workspace.ps1) | `Deploy-FabricItems` then `Deploy-FabricOrgApp` — a full deployment stage in the order that matters | Yes (`-WhatIf` supported) |
| [03-assign-permissions.ps1](03-assign-permissions.ps1) | `Get-AccessConfig` + `Invoke-PermissionAssignment` — apply an access config | Yes (`-DryRun` supported) |
| [04-sync-warehouse-queries.ps1](04-sync-warehouse-queries.ps1) | `Get-FabricDWQueries`, `Sync-FabricDWQueries` — keep saved warehouse queries in source control | Yes (`-WhatIf` and `-ListOnly` supported) |
| [05-call-the-rest-api.ps1](05-call-the-rest-api.ps1) | `Invoke-FabricRestCall` — reach endpoints the module does not wrap | No |

[access.sample.json](access.sample.json) is the access configuration that `03` reads. Copy it,
put your own group and item names in it, and keep it with your repository.

## Before you start

```powershell
Install-Module Pipeline.Fabric -Repository PSGallery
Install-Module Az.Accounts     -Repository PSGallery
```

`02-deploy-workspace.ps1` additionally needs python with fabric-cicd:

```bash
pip install fabric-cicd
```

Then sign in. Every sample calls `Connect-Fabric`, which reuses an existing Az context and only
prompts when there isn't one:

```powershell
Connect-Fabric
```

For a service principal — which is how a pipeline would run these — pass the credentials instead:

```powershell
Connect-Fabric -ClientId $env:CLIENT_ID `
    -ClientSecretSecure (ConvertTo-SecureString $env:CLIENT_SECRET -AsPlainText -Force) `
    -TenantId $env:TENANT_ID
```

## A first run

Start with the read-only one — it is the quickest way to confirm auth and access are working:

```powershell
./01-explore-workspace.ps1 -WorkspaceName myworkspace
```

Then a deployment, previewing it first:

```powershell
./02-deploy-workspace.ps1 -WorkspaceName myworkspace -RepositoryDirectory src/myworkspace -Environment dev -WhatIf
./02-deploy-workspace.ps1 -WorkspaceName myworkspace -RepositoryDirectory src/myworkspace -Environment dev
```

And permissions, dry run first:

```powershell
./03-assign-permissions.ps1 -WorkspaceName myworkspace -ConfigPath ./access.sample.json -DryRun
./03-assign-permissions.ps1 -WorkspaceName myworkspace -ConfigPath ./access.sample.json
```

## Using the commands directly

The samples are wrappers around ordinary commands — there is nothing stopping you calling them
straight from a console:

```powershell
Import-Module Pipeline.Fabric
Connect-Fabric

# What is in the workspace?
Get-FabricItems -WorkspaceName myworkspace -Type Report

# Deploy one org app, previewing first
Deploy-FabricOrgApp -WorkspaceName myworkspace -Path src/myworkspace/Apps/Reports.OrgApp -FolderPath Apps -WhatIf
Deploy-FabricOrgApp -WorkspaceName myworkspace -Path src/myworkspace/Apps/Reports.OrgApp -FolderPath Apps

# Update a Git-connected workspace to the current commit
Sync-GitToWorkspace -WorkspaceName myworkspace -CommitHash (git rev-parse HEAD)

# Anything the module does not wrap
Invoke-FabricRestCall "v1/workspaces/$workspaceId/orgApps"
```

## In a pipeline

The samples take the same arguments a pipeline would pass, so they drop straight into a step:

```yaml
- task: PowerShell@2
  displayName: 'Deploy Fabric workspace'
  inputs:
    pwsh: true
    filePath: 'samples/02-deploy-workspace.ps1'
    arguments: >-
      -WorkspaceName $(FABRIC_WORKSPACE_NAME)
      -RepositoryDirectory src/$(FABRIC_WORKSPACE_NAME)
      -Environment $(ENVIRONMENT)
```

```yaml
- name: Deploy Fabric workspace
  shell: pwsh
  run: |
    ./samples/02-deploy-workspace.ps1 `
      -WorkspaceName ${{ env.FABRIC_WORKSPACE_NAME }} `
      -RepositoryDirectory src/${{ env.FABRIC_WORKSPACE_NAME }} `
      -Environment ${{ env.ENVIRONMENT }}
```

## When something goes wrong

**"Workspace 'x' not found, or you do not have access to it."**
`Get-FabricWorkspaceId` matches on the exact display name and returns nothing if the signed-in
principal cannot see the workspace. Check `Get-AzContext`, and that the principal is a member of
the workspace.

**"Failed to get a Fabric access token - run Connect-Fabric first."**
There is no Az context, or it has expired. Run `Connect-Fabric` again.

**"Report '<name>' (Report) referenced by the org app was not found in the target workspace."**
The Org App is being deployed before the reports it points at. Deploy the items first — which is
exactly the order `02-deploy-workspace.ps1` uses.

**An item that is definitely in the workspace is reported as missing.**
Fabric list endpoints are paged and `Invoke-FabricRestCall` returns only the first page, so in a
large workspace items beyond it are invisible to the module.

**"Multiple Report items named 'x' in workspace ..."**
Org app element references are resolved by display name, so two items of the same type sharing a
name cannot be told apart. Rename one.
