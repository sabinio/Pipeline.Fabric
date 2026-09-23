---
external help file: Pipeline.Fabric-help.xml
Module Name: Pipeline.Fabric
online version:
schema: 2.0.0
---

# Get-FabricDWQueries

## SYNOPSIS
Return the saved queries for a Fabric Warehouse.

## SYNTAX

### ById (Default)
```
Get-FabricDWQueries -DatawarehouseId <String> [-BaseUrl <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ByName
```
Get-FabricDWQueries -WorkspaceName <String> -WarehouseName <String> [-BaseUrl <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -DatawarehouseId
The warehouse (datawarehouse) id, e.g.
00000000-0000-0000-0000-000000000000.

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
Alternative to DatawarehouseId - resolve the id from the workspace + warehouse name.

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

### -WarehouseName
Warehouse display name to resolve when using WorkspaceName.

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

### -BaseUrl
{{ Fill BaseUrl Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Https://api.powerbi.com
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
