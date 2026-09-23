function Connect-Fabric {
 param($ClientId, $ClientSecretSecure, $TenantId)

    
    $resourceUrl = "https://api.fabric.microsoft.com"
    if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) {
        if ( $ClientID ) {
            Write-Host "Login to Azure using Service Principal..."
            $pscredential = New-Object -TypeName System.Management.Automation.PSCredential `
                -argumentlist $ClientId, $ClientSecretSecure                       
            Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $TenantId
        }
        else {
            Write-Host "Login to Azure using User Account..."
            Connect-AzAccount -Tenant $TenantId -authscope $resourceUrl 
        }
    }
    Write-Host "This is the current Azure Context:"
    Get-AzContext
}


