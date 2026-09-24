function Set-FabricWorkspaceIdentity {
    <#
    .SYNOPSIS
        Idempotently provisions or deprovisions a Fabric workspace's managed identity.

    .DESCRIPTION
        The workspace identity lets the workspace authenticate to Azure resources (e.g.
        Key Vault), provided the identity's application id is then granted access on that
        resource. Provisioning/deprovisioning when already in the desired state is a no-op.

    .PARAMETER WorkspaceId
        The workspace id.

    .PARAMETER Enabled
        $true to provision the managed identity, $false to deprovision it.

    .EXAMPLE
        Set-FabricWorkspaceIdentity -WorkspaceId $workspaceId -Enabled $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,
        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    try {
        if ($Enabled) {
            Write-Host "  Provisioning managed identity for workspace $WorkspaceId"
            Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/provisionIdentity" -Method Post | Out-Null
        }
        else {
            Write-Host "  Deprovisioning managed identity for workspace $WorkspaceId"
            Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/deprovisionIdentity" -Method Post | Out-Null
        }
    }
    catch {
        $detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        if ($detail -match 'already provisioned' -or $detail -match 'not provisioned' -or $detail -match 'WorkspaceIdentityDoesNotExist') {
            Write-Verbose "  Managed identity for workspace $WorkspaceId already in the desired state"
            return
        }
        throw
    }
}
