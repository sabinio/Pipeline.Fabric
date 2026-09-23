
function Invoke-FabricRestCall {
    <#
    .SYNOPSIS
        Central helper for calling the Fabric REST API.

    .DESCRIPTION
        Acquires a bearer token from the current Az context, issues the request, and
        transparently waits out long-running (202 Accepted) operations. For list responses
        the '.value' array is returned; otherwise the parsed response object (or $null for
        an empty body). Requires a prior Connect-Fabric.

    .PARAMETER Endpoint
        The API path (e.g. 'v1/workspaces') or a fully-qualified URL.

    .PARAMETER Method
        HTTP method. Defaults to Get.

    .PARAMETER Body
        Request body for Post/Patch/Put - a hashtable/object (serialised to JSON) or a
        pre-serialised JSON string.

    .PARAMETER NoWait
        For a long-running (202 Accepted) response, return a pending-operation handle
        (a 'Fabric.PendingOperation' object carrying the operation URL) instead of polling
        it to completion. The caller is then responsible for waiting on it - e.g. via
        Wait-FabricLongRunningOperation - which lets several operations be submitted first
        and then awaited together. Non-202 responses are unaffected.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Endpoint,
        [ValidateSet('Get', 'Post', 'Patch', 'Put', 'Delete')]
        [string]$Method = 'Get',
        $Body,
        [switch]$NoWait
    )

    # Convert access token secure string to clear text
    $Token = Get-AzAccessToken -ResourceUrl "https://api.fabric.microsoft.com"
    if (-not $Token -or [string]::IsNullOrWhiteSpace($Token.Token)) {
        throw "Failed to get a Fabric access token - run Connect-Fabric first."
    }
    $cred = New-Object System.Management.Automation.PSCredential ("user", $Token.Token)
    $plainToken = $cred.GetNetworkCredential().Password

    $headers = @{
        'Authorization' = "Bearer $plainToken"
        'Content-Type'  = 'application/json'
    }

    $uri = if ($Endpoint -match '^https?://') { $Endpoint } else { "https://api.fabric.microsoft.com/$Endpoint" }

    $params = @{
        Uri         = $uri
        Method      = $Method
        Headers     = $headers
        ErrorAction = 'Stop'
    }
    if ($null -ne $Body) {
        $params.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 20 }
    }

    $response = Invoke-WebRequest @params

    # Handle long-running operations (202 Accepted + Location header). By default they are
    # polled to completion here; with -NoWait the pending operation is returned for the
    # caller to await later.
    if ($response.StatusCode -eq 202 -and $response.Headers['Location']) {
        $operationUrl = $response.Headers['Location'][0]
        $retryAfter = 5
        if ($response.Headers['Retry-After']) {
            $retryAfter = [int]($response.Headers['Retry-After'] | Select-Object -First 1)
        }
        if ($NoWait) {
            Write-Host "  accepted - operation $operationUrl (await deferred)"
            return [pscustomobject]@{
                PSTypeName   = 'Fabric.PendingOperation'
                OperationUrl = $operationUrl
                RetryAfter   = $retryAfter
                Headers      = $headers
            }
        }
        Write-Host "  accepted - polling operation $operationUrl"
        return Wait-FabricLongRunningOperation -OperationUrl $operationUrl -RetryAfter $retryAfter -Headers $headers
    }

    if ([string]::IsNullOrWhiteSpace($response.Content)) {
        return $null
    }
    $content = $response.Content | ConvertFrom-Json
    if ($content.PSObject.Properties.Name -contains 'value') {
        return $content.value
    }
    return $content
}
