---
external help file: Pipeline.Fabric-help.xml
Module Name: Pipeline.Fabric
online version:
schema: 2.0.0
---

# Get-FabricItems

## SYNOPSIS
List the items in a Fabric workspace.

## SYNTAX

### ById (Default)
```
Get-FabricItems -WorkspaceId <String> [-Type <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ByName
```
Get-FabricItems -WorkspaceName <String> [-Type <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Calls the Fabric REST API (v1/workspaces/{workspaceId}/items) and returns the items
in the workspace.
Optionally filter to a single item type (e.g.
Warehouse, Lakehouse,
Notebook, SemanticModel, Report, DataPipeline).

## EXAMPLES

### EXAMPLE 1
```
Get-FabricItems -WorkspaceName 'myworkspace' -Type Warehouse
```

## PARAMETERS

### -WorkspaceId
The workspace id.
If omitted it is resolved from WorkspaceName.

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

### -WorkspaceName
Workspace display name to resolve the id from when WorkspaceId is not supplied.

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

### -Type
Optional item type to filter by (e.g.
Warehouse, Lakehouse, Notebook).

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
