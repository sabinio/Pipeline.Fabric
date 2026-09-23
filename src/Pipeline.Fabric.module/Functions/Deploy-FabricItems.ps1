<#
Deploy-FabricItems  -Environment "${{ inputs.environment }}" `
    -Workspace "$Workspace" `
    -OnlyChanged
    -ItemsInScope "${{ inputs.items_to_deploy }}" 
#>
function Deploy-FabricItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Environment,
        [Parameter(Mandatory = $true)]
        [string]$Workspace,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName,
        [Parameter(Mandatory = $false)]
        [string]$ItemsInScope = "Notebook,Environment,Report,SemanticModel,Lakehouse,DataPipeline,VariableLibrary,Warehouse",
        [Parameter(Mandatory = $false)]
        [switch]$OnlyChanged ,
        [Parameter(Mandatory = $false)]
        [switch]$BulkDeploy ,        
        [Parameter(Mandatory = $true)]
        [String]$RepositoryDirectory ,
        [switch]$IgnoreParameterFile ,
        [string]$OverrideParameterFile 
    )

    Write-Host "=== $("$Environment".ToUpper()) Deployment ==="
    Write-Host "Workspace: $Workspace"
    Write-Host "Environment: $Environment"
    Write-Host ""
    if ($IgnoreParameterFile) {
        Write-Host "Ignoring parameter file"
    }
    if ("$Environment" -eq "prd") {
        Write-Host "⚠️  PRODUCTION DEPLOYMENT IN PROGRESS ⚠️"
        Write-Host ""
    }
          
    Write-Host "Looking for workspace: $WorkspaceName"
          
    $WorkspaceId = Get-FabricWorkspaceId  $WorkspaceName
          
    # Deploy to workspace
    Write-Host "Target: $WorkspaceName ($WorkspaceId)"
    Write-Host "Items: $ItemsInScope"
          
        $Params  = @("--WorkspaceId",$WorkspaceId`
                    ,"--Environment",$Environment `
                    ,"--RepositoryDirectory", $RepositoryDirectory`
                    ,"--ItemsInScope",$ItemsInScope `
        )
    if ($OnlyChanged) {
        $Params += @("--OnlyChanged",$true)
    }
    if ($BulkDeploy) {
        $Params += @("--BulkDeploy",$true)
    }

    if ($VerbosePreference -eq "Continue") {
        $Params += @("--Debug",$true)
    }
    $ParameterFile = "parameter.$Environment.yml"

    if ($IgnoreParameterFile) {
        Write-Host "Ignoring parameter file: $ParameterFile"
        $ParameterFile = "EmptyParameter.yml"
    }
    elseif ($OverrideParameterFile) {
        Write-Host "Overriding parameter file: $OverrideParameterFile"
        $ParameterFile = $OverrideParameterFile
    }

    if (-not (Test-Path (Join-Path $RepositoryDirectory $ParameterFile))) {
        # Fall back to non-environment-specific parameter file
        $ParameterFile = "parameter.yml"
    }

    if (Test-Path (Join-Path $RepositoryDirectory $ParameterFile)) {
        Write-Host "Using parameter file: $ParameterFile"
        $Params += @("--ParameterFile", $ParameterFile)
    }
    else {
        Write-Host "Parameter file not found: $ParameterFile"
    }

    if ($BulkDeploy) {
        Write-Host "Bulk Deploy configured."
    }
    else {
        Write-Host "Bulk Deploy not configured."
    }

    $Warehouses = Get-FabricDWServerId -workspaceName $WorkspaceName
    foreach ($Warehouse in $Warehouses.GetEnumerator()) {
        Write-Host "Target Data Warehouse: $($Warehouse.Key) ($($Warehouse.Value))"
    }
    
    $fabriccicdScript = join-path $PSScriptRoot "..\scripts\fabric-cicd-deploy.py" 
 
    if (Test-Path $fabriccicdScript) {
        python $fabriccicdScript @Params
    } else {
        Write-Host "Error: $fabriccicdScript not found"
        exit 1
    }
          
    Write-Host "✅ $("$Environment".ToUpper()) deployment completed successfully"
}