---
external help file: Pipeline.Fabric-help.xml
Module Name: Pipeline.Fabric
online version:
schema: 2.0.0
---

# Deploy-FabricOrgApp

## SYNOPSIS
Deploys an Org App (and its audiences) to a Fabric workspace from its Git
source definition.

## SYNTAX

### ByName (Default)
```
Deploy-FabricOrgApp -WorkspaceName <String> -Path <String> [-FolderPath <String>] [-SkipAudiences]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```
Deploy-FabricOrgApp -WorkspaceId <String> -Path <String> [-FolderPath <String>] [-SkipAudiences]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The fabric-cicd deployment (Deploy-FabricItems) does not publish OrgApp /
OrgAppAudience items, so this function deploys them directly against the dedicated
Fabric OrgApp / OrgAppAudience REST APIs:

  OrgApp:         https://learn.microsoft.com/rest/api/fabric/orgapp/items
  OrgAppAudience: https://learn.microsoft.com/rest/api/fabric/orgappaudience/items

Given the source folder of an Org App (the '\<name\>.OrgApp' directory produced by
Fabric Git integration) it:

  1.
Reads the app's '.platform' (display name) and 'definition.json'.
  2.
Creates the OrgApp (POST .../orgApps, with the definition inline) if one with
     that display name does not already exist, otherwise updates its definition
     (POST .../orgApps/{id}/updateDefinition).
  3.
For every OrgAppAudience under the app's '.children' folder, rewrites the
     'parentAppId' - which in Git holds the app's *logicalId* - to the id of the
     app just deployed, then creates or updates each audience against the
     .../orgAppAudiences API.

Each definition is the two parts the APIs accept - 'definition.json' and
'.platform'.
Create and updateDefinition are long-running operations, so 202
responses are polled to completion (by Invoke-FabricRestCall).
The caller must
already be authenticated to Fabric (e.g.
via Connect-Fabric).

Both the app's 'elements' and every audience's 'elementReferences' are rewritten from
the Git form (which identifies each report by 'itemLogicalId') to the resolved form the
APIs require - 'itemId' (the report's real id in the target workspace) plus
'folderObjectId' (the workspace id).
Both must be resolved the same way because the
OrgAppAudience API requires each audience reference's (itemId, folderObjectId, itemType)
to match the parent app's corresponding element.
The reports deployed into the workspace
do not carry the Git logical ids (fabric-cicd leaves their .platform logicalId all-zero),
so the logical id cannot be matched against the workspace items directly; instead a map
itemLogicalId -\> { itemId; folderObjectId } is built by joining the app's own 'elements'
(logicalId + displayName) to the workspace items (displayName + real id) on display name,
then applied to the app and every audience.
The referenced reports must already exist in
the target workspace (they do when the item deployment - Deploy-FabricItems - has run
first, as pipeline.deploy-workspace does).

## EXAMPLES

### EXAMPLE 1
```
Connect-Fabric
Deploy-FabricOrgApp -WorkspaceName 'myworkspace' -Path 'src/myworkspace/Apps/Reports.OrgApp'
```

### EXAMPLE 2
```
Deploy-FabricOrgApp -WorkspaceName 'myworkspace' -Path 'src/myworkspace/Apps/Reports.OrgApp' -WhatIf
```

## PARAMETERS

### -WorkspaceName
Display name of the target Fabric workspace.
The id is resolved from it.

```yaml
Type: String
Parameter Sets: ByName
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WorkspaceId
Target workspace id.
Supply this instead of WorkspaceName to skip name resolution.

```yaml
Type: String
Parameter Sets: ById
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Path to the '.OrgApp' source folder (the one containing '.platform',
'definition.json' and the '.children' folder).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FolderPath
Workspace folder the app should live in, as a '/'-separated path relative to the
workspace root (e.g.
'Apps') - normally the app's location in the Git source tree
relative to the repository directory.
Folders are created if they do not exist,
and an existing app is moved if it is not already there.
Omit to deploy to the
workspace root.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipAudiences
Deploy only the OrgApp shell and not the audiences under '.children'.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
