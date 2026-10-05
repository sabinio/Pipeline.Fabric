# Finds the id of a Fabric "connection" resource (stored Git credentials) to use when
# connecting a workspace to Git - matched by display-name substring and connection type.
# Note: reads a single page of v1/connections; Invoke-FabricRestCall unwraps the response's
# '.value' array so continuation paging isn't available through it - fine for the small
# number of connections a tenant typically has configured.
function Get-FabricGitConnectionId {
    param(
        [string]$NamePattern = 'GitHub',
        [string]$ConnectionType = 'GitHubSourceControl'
    )

    $connections = Invoke-FabricRestCall 'v1/connections'
    $matching = $connections | Where-Object { $_.displayName -like "*$NamePattern*" -and $_.connectionDetails.type -eq $ConnectionType }

    if (-not $matching) {
        $available = ($connections | ForEach-Object { "$($_.displayName) ($($_.connectionDetails.type))" }) -join ', '
        throw "No Fabric connection found matching '*$NamePattern*' of type '$ConnectionType'. Available: $available"
    }

    $selected = $matching | Select-Object -First 1
    Write-Verbose "  Using Git connection '$($selected.displayName)' ($($selected.id))"
    return $selected.id
}
