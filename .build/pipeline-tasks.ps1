[CmdletBinding()]
param (
    [switch] $Clean,
    [switch] $Test,
    [Switch] $Build,
    [switch] $Package,
    [switch] $Publish,
    [switch] $Tidy,
    [switch] $noLogo,
    [switch] $LoadAllmodules,
    [string] $environment = $env:ENVIRONMENT,
    [string] $rootPath = $env:ROOTPATH,
    [string] $artifactsPath = $env:ARTIFACTSPATH,
    [string] $verboseLogging = $env:VERBOSELOGGING, #"Install,Build,Package,DeployInfra,Deploy,Config,Module,*",
    [parameter(ValueFromRemainingArguments = $true)]
    $parameterOverrides
)
$global:ErrorActionPreference = "Stop"
$ErrorActionPreference = "Stop"

push-location "$PSScriptroot/.."
Set-StrictMode -Version 1.0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#use this to connect to azure
#get-azcontext -ListAvailable | Where-Object {$_.subscription.name -like "*sabin*"} | Select-Object -first 1 | set-azcontext

try {
    if ([string]::IsNullOrEmpty($environment)) {
            $environment = 'localdev'
    }
    if ([string]::IsNullOrEmpty($rootPath)) { $rootPath = join-path $PSScriptroot ".." | Resolve-Path };
    if ([string]::IsNullOrEmpty($artifactsPath)) { $artifactsPath = join-path $rootPath "artifacts" };
    [string] $outPath = join-path $rootPath "out";

    . $PSScriptroot/scripts/logging.ps1

    Write-Host "##[group]Parameters"
    Write-Host "Processing with "
    Write-Host "   Root path       = $rootpath"
    Write-Host "   Artifacts path  = $artifactsPath"
    Write-Host "   Out path        = $outPath"
    Write-Host "   PSScriptroot    = $PSScriptroot"
    Write-Host "   Logging         = $VerboseLogging"
	Write-Host "   Environment"
    Get-ChildItem env: | %{
    Write-Host ("      {0,-30} = {1:300} " -f $_.Name,$_.Value)
    }
    Write-Host "##[endgroup]"
    
    if ($Clean) {
		Write-Host "##[group]Clean"
        if (Test-path $artifactsPath) { Remove-Item -Path $artifactsPath -Recurse -Force | Out-Null }
        if (Test-path $outPath) { Remove-Item -Path $outPath -Recurse -Force | Out-Null }
		Write-Host "##[endgroup]"
    }
	$dependencies = @(
   @{"Build"               = @{Modules = @("platyps","Az.keyVault","Az.Accounts"); Tools = @()  }},
   @{"package"            = @{Modules = @(); Tools = @() }},
   @{"publish"            = @{Modules = @("Az.keyVault"); Tools = @() }},
   @{"test"           = @{Modules = @("Pester","PSScriptAnalyzer","Az.Accounts"); Tools = @() }}
)
    $modules = New-Object System.Collections.ArrayList
    $tools = New-Object System.Collections.ArrayList
    $PSBoundParameters.keys |ForEach-Object{
        if ($dependencies.$_.modules) {$modules.addrange($dependencies.$_.modules)}
        if ($dependencies.$_.tools) {$tools.AddRange($dependencies.$_.tools)}
    }
    $modules.add("Pipeline.Config") | Out-Null
	$modules.add("Microsoft.PowerShell.Management") | Out-Null
	$modules.add("Microsoft.PowerShell.Utility") | Out-Null
	$modules.add("PowerShellGet, PackageManagement") | Out-Null

    Write-Host "Modules $($modules -join ',') "
    Write-Host "Tools $($Toos -join ',') "
    Write-Host ($PsversionTable | out-string)
    
	$id = new-guid
	Write-Host "vso[task.logdetail id=$id;name=project;type=build;order=1]create new timeline record"
	./.build/pipeline.install-tools.ps1 -workingPath $artifactsPath/tools -verbose:$VerbosePreference -DependentTools $Tools -DependentModules $Modules -SaveLockFile:($env:DONT_SAVE_MODULE_LOCK-ne"true") -LoadAll:$LoadAllmodules
	Write-Host "vso[task.logdetail id=$id;state=Completed]update timeline record"

	Write-Host "##[group]Settings"
    $settings = (Get-ProjectSettings -environment $environment -ConfigRootPath (join-path $PSScriptroot "config") -verbose:(Test-LogAreaEnabled -logging $verboseLogging -area "config") -overrides $parameterOverrides) 
    write-host ("##vso[build.updatebuildnumber] {0}.{1}" -f $settings.ProjectName, $settings.FullVersion)
	write-host ("##vso[task.setvariable variable=ProjectName;IsOutput=true]{0}" -f $settings.ProjectName)
	write-host ("##vso[task.setvariable variable=ProjectName;]{0}" -f $settings.ProjectName)

	Write-Host ($settings | Convertto-json -depth 5)

	Write-Host "##[endgroup]"

	$testresultsFolder = join-path $outPath "test-results"  
    if (Test-Path $testresultsFolder ){
        Write-Verbose "Clearing Test results folder"
        Remove-Item (join-path $testresultsFolder "*" ) -Recurse -Force 
    }
    else {
        New-Item -ItemType Directory -Force -Path $testresultsFolder | Out-Null 
    }

    if ($Build) {     
		Write-Host "##[group]Build"
		./.build/pipeline.build.ps1  -settings $settings -rootPath $rootPath -verbose:(Test-LogAreaEnabled -logging $verboseLogging -area "build")
        ./.build/pipeline.createdocs.ps1  -settings $settings -rootPath $rootPath -verbose:(Test-LogAreaEnabled -logging $verboseLogging -area "build")
		Write-Host "##[endgroup]"
    }

    if ($Package) {
		Write-Host "##[group]Package"
        ./.build/pipeline.package.ps1  -settings $settings -ArtifactsPath $artifactsPath -verbose:(Test-LogAreaEnabled -logging $verboseLogging -area "package")
		Write-Host "##[endgroup]"
    }

    if ($Test) {
        Write-Host "##[group]Test"
        ./.build/pipeline.test.ps1 -ArtifactsPath $artifactsPath -settings $settings -rootpath $rootpath -outPath $outPath -verbose:(Test-LogAreaEnabled -logging $verboseLogging -area "test") 
		Write-Host "##[endgroup]"
    }

    if ($Publish) {
		Write-Host "##[group]Publish"
        . ./.build/pipeline.update-manifest.ps1 
        Update-Manifest -settings $settings -ArtifactsPath $artifactsPath -verbose:(Test-LogAreaEnabled -logging $verboseLogging -area "publish")
        ./.build/pipeline.publish.ps1  -settings $settings -ArtifactsPath $artifactsPath -verbose:(Test-LogAreaEnabled -logging $verboseLogging -area "publish")
		Write-Host "##[endgroup]"
    }

    if ($Tidy) {
		Write-Host "##[group]Tidy"
        ./.build/pipeline.tidy.ps1 -ArtifactsPath $artifactsPath -settings $settings -outPath $outPath -verbose:(Test-LogAreaEnabled -logging $verboseLogging -area "tidy") 
		Write-Host "##[endgroup]"
    }
}

catch {
    
	$errorRecord = $_
    # This provides the vs code friendly links to the position the error occurs 
    Write-Host ("##vso[task.logissue type=error;sourcepath={0};linenumber={1};columnnumber={2};code={3};]{4}" -f  `
                $ErrorRecord.InvocationInfo.ScriptName,`
                $ErrorRecord.InvocationInfo.ScriptLineNumber,`
                $ErrorRecord.InvocationInfo.OffsetInLine,`
                $errorRecord.Exception.HResult,`
                $errorRecord     
                   )

    Write-Host "##vso[task.complete result=Failed;]$errorRecord"
    # This provides the vs code friendly links to the position the error occurs 
    Write-Host -ForegroundColor Red "$ErrorRecord $($ErrorRecord.InvocationInfo.PositionMessage)"

    if ($ErrorRecord.Exception) {
        Write-Host -ForegroundColor Red $ErrorRecord.Exception
    }

    if ($null -ne (Get-Member -InputObject $ErrorRecord -Name ScriptStackTrace)) {
        #PS 3.0 has a stack trace on the ErrorRecord; if we have it, use it & skip the manual stack trace below
        Write-Host -ForegroundColor Red $ErrorRecord.ScriptStackTrace
    }
    else {

        Get-PSCallStack | Select-Object -Skip 1 | ForEach-Object {
            Write-Host -ForegroundColor Yellow -NoNewLine "! "
            Write-Host -ForegroundColor Red $_.Command $_.Location $(if ($_.Arguments.Length -le 80) { $_.Arguments })
        }
    }  

    if ("$env:SYSTEM_COLLECTIONURI" -eq "")  {Throw } #Don't throw with Azure DevOps. You get an awful error
} 
finally{
    pop-location
}