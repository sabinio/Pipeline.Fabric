param($ModulePath, $SourcePath, $ProjectName)
BeforeDiscovery {
	if (-not (Test-path "Variable:ProjectName")-or [string]::IsNullOrWhiteSpace($ProjectName) ) { $ProjectName = (get-item $PSScriptRoot).basename -replace ".tests", "" }
	if (-not (Test-path "Variable:ModulePath") -or [string]::IsNullOrWhiteSpace($ModulePath) ) { $ModulePath = "$PSScriptRoot\..\$ProjectName.module" }
	if (-not  (Test-path "Variable:SourcePath") -or [string]::IsNullOrWhiteSpace($sourcePath)) { $SourcePath = "$ModulePath" }

	Write-Verbose "ModulePath = $ModulePath" -Verbose
	Write-Verbose "SourcePath = $SourcePath" -Verbose
	$ModulePath = resolve-path $ModulePath
	$SourcePath = Resolve-path $SourcePath 
	$Modules = Get-ChildItem $ModulePath -Filter '*.psm1' -Recurse
	
	$Scripts = Get-ChildItem $ModulePath -Filter '*.ps1' -Recurse | Where-Object { $_.name -NotMatch 'Tests.ps1' }

	# PSUseSingularNouns  - the exported command names (Get-FabricItems, Sync-FabricDWQueries, ...)
	#                      are the module's published API; renaming them would break consumers.
	# PSUseShouldProcess  - raised for nested private helpers (Set-OrgAppItem, Set-Permission) that
	#                      deliberately use the enclosing cmdlet's $PSCmdlet.ShouldProcess so -WhatIf
	#                      flows from the public command.
	$ExcludeRules = @('PSAvoidTrailingWhitespace', 'PSAvoidUsingWriteHost', 'PSUseSingularNouns', 'PSUseShouldProcessForStateChangingFunctions' )
    
	$Rules = (Get-ScriptAnalyzerRule  | Where-Object { $ExcludeRules -notcontains $_.ruleName }).RuleName
}
BeforeAll {
	$ExcludeRules = @('PSAvoidTrailingWhitespace', 'PSAvoidUsingWriteHost' ,'PSUseOutputTypeCorrectly', 'PSUseSingularNouns', 'PSUseShouldProcessForStateChangingFunctions')
	if (-not (Test-path "Variable:ProjectName")-or [string]::IsNullOrWhiteSpace($ProjectName) ) { $ProjectName = (get-item $PSScriptRoot).basename -replace ".tests", "" }
	if (-not (Test-path "Variable:ModulePath") -or [string]::IsNullOrWhiteSpace($ModulePath) ) { $ModulePath = "$PSScriptRoot\..\$ProjectName.module" }
	if (-not  (Test-path "Variable:SourcePath") -or [string]::IsNullOrWhiteSpace($sourcePath)) { $SourcePath = "$ModulePath" }

	Write-Verbose "ModulePath = $ModulePath" -Verbose
	Write-Verbose "SourcePath = $SourcePath" -Verbose
	$ModulePath = resolve-path $ModulePath
	$SourcePath = Resolve-path $SourcePath
}
Describe 'PSAnalyser Testing Modules ' -Tag "PSScriptAnalyzer" -ForEach $Modules {
	BeforeAll {
		$Module = $_
		$RuleResults = Invoke-ScriptAnalyzer -Path $module.FullName  -ExcludeRule $ExcludeRules
		$HasResults = $RuleResults.Count -ne 0
	} 
	It " Rule <_>" -TestCases $Rules {
		if ($HasResults) {
			($RuleResults | Where-Object { $_.Rulename -eq $rule }).Message | should -be $null Message "sdfsd"
                   
		}
	}

}
    

Describe 'PSAnalyser Testing scripts - <BaseName> <sourceFile>'  -Tag "PSScriptAnalyzer" -ForEach ($Scripts | ForEach-Object {@{Basename=$_.basename;sourcefile=$_.FullName}}) {
	BeforeAll {
		$sourceFile = $sourcefile.replace($ModulePath, $sourcePath )

		$RuleResults = Invoke-ScriptAnalyzer -Path $sourcefile    -ExcludeRule $ExcludeRules
		$HasResults = $RuleResults.Count -ne 0
	}
	It "Rule <_> " -TestCases $Rules {
		$rule = $_
		if ($HasResults) {
			($RuleResults | Where-Object { $_.Rulename -eq $rule }).Message | should -be $null 
		}
	}
	
}

