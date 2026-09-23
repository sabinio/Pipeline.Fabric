function Get-PowerBIToken {
    # Power BI / wabi endpoints require the Power BI resource token, not the Fabric one.
    $token = Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api"
    if (-not $token) {
        throw "Failed to get a Power BI access token - run Connect-Fabric first."
    }
    $cred = New-Object System.Management.Automation.PSCredential ("user", $token.Token)
    return $cred.GetNetworkCredential().Password
}
