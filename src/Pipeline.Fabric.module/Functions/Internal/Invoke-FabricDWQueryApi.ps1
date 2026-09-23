function Invoke-FabricDWQueryApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatawarehouseId,
        [string]$Path,
        [ValidateSet("Get", "Post", "Patch", "Put", "Delete")]
        [string]$Method = "Get",
        $Body,
        [string]$BaseUrl = "https://api.powerbi.com"
    )
    try {
        $plainToken = Get-PowerBIToken
        $headers = @{
            'Authorization' = "Bearer $plainToken"
            'Content-Type'  = 'application/json'
        }

        $uri = "$BaseUrl/v1.0/myorg/datawarehouses/$DatawarehouseId/queries"
        if ($Path) {
            $uri += $Path
        }

        $params = @{
            Uri     = $uri
            Method  = $Method
            Headers = $headers
        }
        if ($null -ne $Body) {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
        }

        return Invoke-RestMethod @params
    }
    catch {
        throw
    }

}
