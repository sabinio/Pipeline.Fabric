# Polls a Fabric long-running operation referenced by the Location header of a 202
# response until it reaches a terminal state, throwing on failure.
function Wait-FabricLongRunningOperation {
    param(
        [Parameter(Mandatory)]$OperationUrl,
        [int]$RetryAfter = 5,
        [int]$MaxAttempts = 720,
        $Headers
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $status = Invoke-RestMethod -Uri $OperationUrl -Method Get -Headers $Headers -ErrorAction Stop
        Write-Host "  operation status: $($status.status)"
        switch ($status.status) {
            "Succeeded" { return $status }
            "Completed" { return $status }
            "Failed" { throw "Fabric operation failed: $($status.error | ConvertTo-Json -Depth 5)" }
            default { } # NotStarted / Running - keep polling
        }
        Start-Sleep -Seconds $RetryAfter
    }

    throw "Fabric operation did not complete after $MaxAttempts attempts (OperationUrl: $OperationUrl)."
}
