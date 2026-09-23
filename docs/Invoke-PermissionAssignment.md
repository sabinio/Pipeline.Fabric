---
external help file: Pipeline.Fabric-help.xml
Module Name: Pipeline.Fabric
online version:
schema: 2.0.0
---

# Invoke-PermissionAssignment

## SYNOPSIS
Invokes permission assignment for Fabric workspace items.

## SYNTAX

```
Invoke-PermissionAssignment [-WorkspaceId] <String> [-AccessConfig] <Object> [-DryRun]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Assigns cascading permissions to reports, semantic models, and warehouses based on access configuration.
When a user/group is assigned to a report, they automatically receive the same role on the associated
semantic model and warehouse.

## EXAMPLES

### EXAMPLE 1
```
$config = Get-AccessConfig -ConfigPath "config/access.json"
Invoke-PermissionAssignment -WorkspaceId $workspaceId -AccessConfig $config -Verbose
```

### EXAMPLE 2
```
Invoke-PermissionAssignment -WorkspaceId $workspaceId -AccessConfig $config -DryRun -Verbose
```

## PARAMETERS

### -WorkspaceId
The Fabric workspace ID.

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

### -AccessConfig
The access configuration object (from Get-AccessConfig).

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DryRun
If specified, shows what would be done without making changes.

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
