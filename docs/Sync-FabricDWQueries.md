---
external help file: Pipeline.Fabric-help.xml
Module Name: Pipeline.Fabric
online version:
schema: 2.0.0
---

# Sync-FabricDWQueries

## SYNOPSIS
Sync the *.sql files in the root of the warehouse folder to the warehouse's saved queries.

## SYNTAX

```
Sync-FabricDWQueries [[-DatawarehouseId] <String>] [[-WorkspaceName] <String>] [[-WarehouseName] <String>]
 [-WarehousePath] <String> [[-BaseUrl] <String>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
For every *.sql file directly inside WarehousePath (subfolders are ignored) this:
  * creates a saved query when none with the same name exists, and
  * updates the saved query when the stored SQL differs from the file.

The query name is the file name without the .sql extension.
The SQL expression
is the raw file content.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -DatawarehouseId
The warehouse id.
If omitted it is resolved from WorkspaceName + WarehouseName.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WorkspaceName
Workspace to resolve the warehouse id from when DatawarehouseId is not supplied.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WarehouseName
Warehouse display name used for resolution.
Required with WorkspaceName.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WarehousePath
Path to the root warehouse folder that contains the *.sql query files.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BaseUrl
{{ Fill BaseUrl Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: Https://api.powerbi.com
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Report the actions that would be taken without calling the API.

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
