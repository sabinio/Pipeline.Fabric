
# Contributing

Obtain a PAT token from Azure DevOps that has scopes of package management.

Obtain the config setting for the pat token. This will create an entry in the [base config file](.build\config\base\config.json).
Copy the entry to your personal localdev config file in ```.build\config\personal\<user>-localdev.json```

``` powershell
Set-SecureSetting -ConfigRootPath .\.build\config\ -Name PowershellRepositoryKey -Value "<pat token"
```

# Build, Test and Publish tasks

Activity|Command
-|-
Install tools and modules|```.build\pipeline-tasks.ps1 -install```
Build <br>(regenerates FunctionsToExport and the docs)|```.build\pipeline-tasks.ps1 -build```
Test|```.build\pipeline-tasks.ps1 -Test```
Package|```.build\pipeline-tasks.ps1 -package```
Publish|```.build\pipeline-tasks.ps1 -publish```

## Environments
configuraiton environments are used to group settings and allow publishing to different locations

Environment|Description
-|-|
localdev|Use to develop locally, publish to Azure DevOps Artifact feed, packages published as prerelease
ci|used for PR and CI stages, publish to Powershell gallery as prerelease
prod|Use to publish to powershell galley without prerelease setting

## Version numbers

For CI, PR and Prod version numbers are managed by AzureDevops build counters using a base version number.
For localdev the version number is 0.0.<time> where time is a combination of days since 2020 and elapsed minutes in the day. 
The prelrelease tag is defined based on config. Developers should specify their own prerelease setting 

## Module layout

Folder|Contents
-|-
```src\Pipeline.Fabric.module\Functions```|One file per **public** function, named exactly after the function. ```FunctionsToExport``` in the manifest is regenerated from these file names by ```.build\pipeline.build.ps1```, so adding a file here is all that is needed to export a command.
```src\Pipeline.Fabric.module\Functions\Internal```|Private helpers and script data. Not exported.
```src\Pipeline.Fabric.module\scripts```|The ```fabric-cicd-deploy.py``` publisher invoked by ```Deploy-FabricItems```. It is resolved relative to the calling function's ```$PSScriptRoot```, which is why the module dot-sources its function files rather than loading them from text.

## Testing

Pester tests are located in [TestFolder](.\src\Pipeline.Fabric.Tests)

Each test should start with the following to ensure the test can be run against the local source and against the module downloaded from the gallery

``` powershell
param($ModulePath, $ProjectName)

BeforeAll {
    if (-not (Test-Path "Variable:ProjectName") -or [string]::IsNullOrWhiteSpace($ProjectName)) { $ProjectName = (Get-Item $PSScriptRoot).BaseName -replace ".tests", "" }
    if (-not (Test-Path "Variable:ModulePath") -or [string]::IsNullOrWhiteSpace($ModulePath)) { $ModulePath = "$PSScriptRoot\..\$ProjectName.module" }
    Import-Module (Join-Path $ModulePath "$ProjectName.psd1") -Force
}
```

Tests tagged ```ModuleInstall``` are also run against the published module after it has been
downloaded from the gallery, so they must not depend on anything outside the module folder.

## PSScriptAnalyser

All modules are analysed against PSScriptAnalyser rules using this [pester test](.\src\Pipeline.Fabric.Tests\PSScript-Analyse.Tests.ps1)
