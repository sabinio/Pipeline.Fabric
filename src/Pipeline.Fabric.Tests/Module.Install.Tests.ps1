param($ModulePath, $ProjectName)
BeforeAll {
	Set-StrictMode -Version 1.0
	if (-not (Test-path "Variable:ProjectName")-or [string]::IsNullOrWhiteSpace($ProjectName) ) { $ProjectName = (get-item $PSScriptRoot).basename -replace ".tests", "" }
	if (-not (Test-path "Variable:ModulePath") -or [string]::IsNullOrWhiteSpace($ModulePath) ) { $ModulePath = "$PSScriptRoot\..\$ProjectName.module" }
}
BeforeDiscovery {
	
	if (-not $ProjectName) { $ProjectName = (get-item $PSScriptRoot).basename -replace ".tests", "" }
	if (-not $ModulePath) { $ModulePath = "$PSScriptRoot\..\$ProjectName.module" }
}
Describe "Tests" {
	Context 'Ensure all Functions are being exported ' -Tag "ModuleInstall" {

		BeforeAll {
			Write-Host $ProjectName
			Write-Host $ModulePath

			if (get-module $ProjectName) { remove-module $ProjectName -Force }
			import-module "$ModulePath\$ProjectName.psd1" -Force 

			$module = get-module $ProjectName
		}
		it "<_> is exported from module" -TestCases (Get-ChildItem "$ModulePath\Functions" -File).BaseName {
			$function = $_
			$module.ExportedCommands.Keys | Should -Contain $function
			#  {get-command "$function"} | should not throw
		}     
	
	}
	Context 'Ensure all psd1 matches' -Tag "ModuleInstall" {
		BeforeAll {
			Write-Host $ProjectName
			Write-Host $ModulePath

			if (get-module $ProjectName) { remove-module $ProjectName -Force }
		
			$moduleData = import-localizedData -FileName "$ProjectName.psd1" -baseDirectory $ModulePath 
		}
		it "module name matches exactly in psd1 file" {
			$moduleData.RootModule | Should -beexactly "$ProjectName.psm1"
		}     
		it "module name matches exactly in psd1 file" {
			(Get-Item (join-path $ModulePath "*.psm1" )).Name | Should -beexactly "$ProjectName.psm1"
		}     

		it "Functions folder should match the name 'Functions' exactly" {
			(Get-ChildItem $modulePath -Directory -Filter "Functions" ).BaseName | Should -beexactly "Functions"
		}     
		if (test-path ([IO.Path]::combine($modulePath, "Functions", "Internal"))) {
			it "Internal folder should match the name 'Internal' exactly" {
				(Get-ChildItem (join-path $modulePath "Functions") -Directory -Filter "Internal" ).BaseName | Should -beexactly "Internal"
		
			}     
		}
	}
}