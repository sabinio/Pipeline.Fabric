---
external help file: Pipeline.Fabric-help.xml
Module Name: Pipeline.Fabric
online version:
schema: 2.0.0
---

# Get-AccessConfig

## SYNOPSIS
Loads access configuration from a JSON file.

## SYNTAX

```
Get-AccessConfig [-ConfigPath] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Reads and parses the access configuration JSON file that defines user/group access
to reports with cascading permissions to semantic models and warehouses.

## EXAMPLES

### EXAMPLE 1
```
$config = Get-AccessConfig -ConfigPath "config/access.json"
```

### EXAMPLE 2
```
$config = Get-AccessConfig -ConfigPath "config/access.json" -Verbose
```

## PARAMETERS

### -ConfigPath
Path to the access.json configuration file.

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
