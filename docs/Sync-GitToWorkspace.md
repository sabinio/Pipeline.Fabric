---
external help file: Pipeline.Fabric-help.xml
Module Name: Pipeline.Fabric
online version:
schema: 2.0.0
---

# Sync-GitToWorkspace

## SYNOPSIS
Updates a Fabric workspace from its connected Git repository ("sync git to
workspace") - i.e.
pushes the committed Git state into the workspace.

## SYNTAX

```
Sync-GitToWorkspace [-WorkspaceName] <String> [-CommitHash] <String> [[-ConflictResolutionPolicy] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Uses the Fabric Git integration REST API.
Resolves the workspace id from the
workspace name, then calls updateFromGit to bring the workspace up to the given
commit.
updateFromGit is a long-running operation, so it polls the operation
until done.

The target commit is supplied by the caller (-CommitHash) rather than read from
Fabric's git status, because Fabric's reported remoteCommitHash can lag the real
remote: in a pipeline the workspace should be updated to the exact commit the
branch is currently on.
Git status is still read, but only to obtain the current
workspaceHead that updateFromGit requires for its concurrency check.

Conflict resolution: when items differ between Git and the workspace, the
requested policy decides which copy wins. 

The caller must already be authenticated to Fabric (e.g.
via Connect-Fabric).
This function takes no knowledge of project settings - the pipeline wrapper
translates settings into these explicit parameters.

## EXAMPLES

### EXAMPLE 1
```
Connect-Fabric
Sync-GitToWorkspace -WorkspaceName 'myworkspace' -CommitHash (git rev-parse HEAD)
```

## PARAMETERS

### -WorkspaceName
Display name of the Fabric workspace to update.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CommitHash
The Git commit hash to update the workspace to - typically the current commit of
the branch (git rev-parse HEAD).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConflictResolutionPolicy
How to resolve item conflicts between Git and the workspace.
'PreferRemote'
(default) takes the Git copy; 'PreferWorkspace' keeps the workspace copy.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: PreferWorkspace
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
