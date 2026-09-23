---
external help file: Pipeline.Fabric-help.xml
Module Name: Pipeline.Fabric
online version:
schema: 2.0.0
---

# Invoke-FabricRestCall

## SYNOPSIS
Central helper for calling the Fabric REST API.

## SYNTAX

```
Invoke-FabricRestCall [-Endpoint] <String> [-Method <String>] [-Body <Object>] [-NoWait]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Acquires a bearer token from the current Az context, issues the request, and
transparently waits out long-running (202 Accepted) operations.
For list responses
the '.value' array is returned; otherwise the parsed response object (or $null for
an empty body).
Requires a prior Connect-Fabric.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Endpoint
The API path (e.g.
'v1/workspaces') or a fully-qualified URL.

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

### -Method
HTTP method.
Defaults to Get.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Get
Accept pipeline input: False
Accept wildcard characters: False
```

### -Body
Request body for Post/Patch/Put - a hashtable/object (serialised to JSON) or a
pre-serialised JSON string.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoWait
For a long-running (202 Accepted) response, return a pending-operation handle
(a 'Fabric.PendingOperation' object carrying the operation URL) instead of polling
it to completion.
The caller is then responsible for waiting on it - e.g.
via
Wait-FabricLongRunningOperation - which lets several operations be submitted first
and then awaited together.
Non-202 responses are unaffected.

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
