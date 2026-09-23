[CmdletBinding()]
param($settings
    , $artifactsPath
    , $rootpath
    , $outPath )

    $ProjectName = $settings.ProjectName;

try {
        
    if (-not $noLogo) {
        Write-BannerTest
    }
    
    if (Test-Path "$outPath/test-results/") { $null }
    else {
        New-Item -ItemType Directory -Force -Path "$outPath/test-results/" | Out-Null 
    }
    get-module $ProjectName | remove-module  -force

	$container = New-PesterContainer -Path  "$rootpath/src/$ProjectName.Tests" -Data @{ModulePath="$artifactsPath\$ProjectName";ProjectName=$ProjectName}; 
	
	$pesterpreference = New-PesterConfiguration @{
		TestResult=@{OutputPath="$outPath/test-results/$ProjectName.PsScripttests.results.xml"
					;Enabled=$true
					;TestSuiteName="PSScriptAnalyser"};
		Run 		= @{Container = $container;
						PassThru = $true};
		Output		= @{Verbosity= "Normal"}
	}
	if ($settings.TestFilter -ne ""){
		$pesterpreference.Filter.Fullname  =$settings.TestFilter
	}
	else {
		$pesterpreference.Filter.Tag =  "PSScriptAnalyzer"
	}

	$ScriptAnalysis = Invoke-Pester -Configuration $pesterpreference


	$container = New-PesterContainer -Path "$rootpath/src/$ProjectName.Tests" -Data @{ModulePath="$artifactsPath\$ProjectName";ProjectName=$ProjectName}  #An empty data is required for Pester 5.1.0 Beta 

	$pesterpreference = New-PesterConfiguration @{
		TestResult=@{OutputPath="$outPath/test-results/$ProjectName.tests.results.xml" 
					;Enabled=$true
					;TestSuiteName="Tests"};

		CodeCoverage= @{Enabled=$true;
						OutputPath  =  "$outPath/test-results/coverage_$ProjectName.xml" 
						Path = "$artifactsPath/$ProjectName/Functions\*.ps1";
						};
		Run 		= @{Container = $container;
						PassThru = $true};
		Filter 		= @{ExcludeTag =  "PSScriptAnalyzer";
		   		   		FullName =  $settings.TestFilter}
		Output		= @{Verbosity= "Detailed"}
	}

	if ($VerbosePreference -eq "Continue"){
		$pesterpreference.Debug = @{WriteDebugMessages = $true
   								   ;WriteDebugMessagesFrom ="Mock"}
	}
    
    $NormalTests = Invoke-Pester -Configuration $pesterpreference 
		
    Write-Host "Normal Tests Total $($NormalTests.TotalCount ) Passed $($NormalTests.PassedCount) NotRun $($NormalTests.NotRunCount) Skipped $($NormalTests.SkippedCount)"
    Write-Host "ScriptAnalysis Tests Total $($ScriptAnalysis.TotalCount ) Passed $($ScriptAnalysis.PassedCount) NotRun $( $ScriptAnalysis.NotRunCount) "
    if ($settings.FailOnTests -eq $true -and ($NormalTests.FailedCount -gt 0 -or $ScriptAnalysis.FailedCount -gt 0)){
            Throw "Tests Failed see above"
    }
}

catch {
    throw
}
