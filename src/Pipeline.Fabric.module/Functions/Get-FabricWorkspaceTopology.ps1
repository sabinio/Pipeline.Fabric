function Get-FabricWorkspaceTopology {
    <#
    .SYNOPSIS
        Expands the Workspaces config section into a flat list of Fabric workspace
        definitions - one entry per environment/layer/domain combination.

    .DESCRIPTION
        Reads the medallion-layer/domain topology from the consumer's pipeline config (a
        "Workspaces" section, passed in via -Config) and produces the concrete list of
        workspaces that should exist, resolving workspace naming, Git and managed-identity
        settings for each. Makes no calls to the Fabric API - this is pure config expansion,
        so it can be filtered and unit tested independently of deployment. Constants that
        apply to every workspace (capacity, the automation service principal, Data
        Team/Admins groups, Git owner/branch) live at the top level of config, alongside this
        section, and are not part of its output - callers read them directly off $settings.

        Environment resolution: a domain's own "environments" list wins; otherwise its
        layer's "environments" list; otherwise every environment in Config.Environments
        except "ref" (opt-in per domain/layer, since it's a static reference copy only
        needed for specific workspaces).

        Naming resolution: a layer's own "namingPatternByEnvironment.<env>" wins; otherwise
        its "namingPattern"; otherwise Config.DefaultNamingPattern. Patterns support the
        tokens {env}, {prefix} and {domain}.

    .PARAMETER Config
        The Workspaces config object, e.g. $settings.Workspaces.

    .PARAMETER Environments
        Optional list of environment names to restrict the topology to.

    .PARAMETER Layers
        Optional list of medallion layer names (config keys under MedallionLayers) to
        restrict the topology to.

    .PARAMETER Domains
        Optional list of domain names to restrict the topology to.

    .EXAMPLE
        Get-FabricWorkspaceTopology -Config $settings.Workspaces -Environments dev -Layers silver
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,
        [string[]]$Environments,
        [string[]]$Layers,
        [string[]]$Domains
    )

    $defaultPattern = if ($Config.DefaultNamingPattern) { $Config.DefaultNamingPattern } else { '{env}_{prefix}_{domain}' }
    $nonRefEnvironments = @($Config.Environments | Where-Object { $_ -ne 'ref' })

    $topology = New-Object System.Collections.Generic.List[object]

    foreach ($layerProp in $Config.MedallionLayers.psobject.Properties) {
        $layerName = $layerProp.Name
        $layer = $layerProp.Value

        if ($Layers -and $layerName -notin $Layers) { continue }

        $layerEnvironments = if ($layer.environments) { @($layer.environments) } else { $nonRefEnvironments }

        foreach ($domainProp in $layer.domains.psobject.Properties) {
            $domainName = $domainProp.Name
            $domain = $domainProp.Value
            if ($Domains -and $domainName -notin $Domains) { continue }

            $domainEnvironments = if ($domain.environments) { @($domain.environments) } else { $layerEnvironments }

            foreach ($envName in $domainEnvironments) {
                if ($Environments -and $envName -notin $Environments) { continue }

                $pattern = $defaultPattern
                if ($layer.namingPattern) { $pattern = $layer.namingPattern }
                if ($layer.namingPatternByEnvironment -and ($layer.namingPatternByEnvironment.psobject.Properties.Name -contains $envName)) {
                    $pattern = $layer.namingPatternByEnvironment.$envName
                }
                $workspaceDisplayName = $pattern.Replace('{env}', $envName).Replace('{prefix}', $layer.prefix).Replace('{domain}', $domainName)

                $repository = if ($domain.repository) { $domain.repository } elseif ($layer.repository) { $layer.repository } else { '' }
                $secure = [bool]$domain.secure
                $setManagedIdentity = if ($null -ne $layer.setManagedIdentity) { [bool]$layer.setManagedIdentity } else { $true }

                $topology.Add([pscustomobject]@{
                    Environment          = $envName
                    Layer                = $layerName
                    Domain               = $domainName
                    WorkspaceDisplayName = $workspaceDisplayName
                    Repository           = $repository
                    DirectoryName        = "/src/$layerName/$domainName"
                    SetManagedIdentity   = $setManagedIdentity
                    Secure               = $secure
                })
            }
        }
    }

    return $topology
}
