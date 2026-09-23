[CmdletBinding()]
param($rootPath, $Settings)

try {
	$ProjectName = $settings.ProjectName;

	push-location $rootPath
	if (-not $noLogo) {
		Write-BannerBuild
	}

	# Every public function is one file in Functions\ named after the function, so the
	# manifest's FunctionsToExport is generated from those file names. Anything that should
	# stay private lives in Functions\Internal\ and is not picked up here.
	$Functions = (Get-ChildItem $rootpath/src/$ProjectName.module/Functions -File | Select-Object ).BaseName

	Write-Host ([IO.Path]::Combine($rootpath, "src", "$ProjectName.module", "$ProjectName.psd1"))
	Test-ModuleManifest ([IO.Path]::Combine($rootpath, "src", "$ProjectName.module", "$ProjectName.psd1"))
	Update-ModuleManifest -Path ([IO.Path]::Combine($rootpath, "src", "$ProjectName.module", "$ProjectName.psd1"))   -FunctionsToExport $Functions

	$config = New-PesterConfiguration @{
		Run        = @{
			PassThru = $true;
			Path     = "$rootpath/src/$ProjectName.ConfigTests"
		};
		TestResult = @{
			Enabled    = $true;
			OutputPath = "$outPath/test-results/$ProjectName.configTests.results.xml"
			SuiteName  = "ConfigTests"
		};
		Filter     = @{
			ExcludeTag = "$($settings.ExcludeTags)"
		}
	}

	$results = Invoke-Pester  -Configuration $config

	if ($settings.FailOnTests -eq $true -and $results.FailedCount -gt 0) {
		throw "Tests have failed see results above"
	}

	$config.Run.Path =  "$rootpath/src/$ProjectName.Tests"
	$config.Filter.ExcludeTag = ""
	$config.Filter.Tag = "ModuleInstall"
	$config.TestResult.OutputPath = "$outPath/test-results/$ProjectName.ModuleInstall.results.xml"

	$results = Invoke-Pester -configuration  $config

	if ($settings.FailOnTests -eq $true -and $results.FailedCount -gt 0) {
		throw "Tests have failed see results above"
	}
}
catch {
	throw
}
finally {
	Pop-Location
}
