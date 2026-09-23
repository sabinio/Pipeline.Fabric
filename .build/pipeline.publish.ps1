[CmdletBinding()]
param($settings, $ArtifactsPath)

   # if (-not $noLogo) { Write-PublishPackage }

    try {
        write-Verbose "Publishing module $($settings.ProjectName) to Powershell Gallery"

       if ($settings.PowershellRepository -ne  "PSGallery" )
        {
            if ($settings.PowershellRepositoryKey -isnot [securestring] ){
                throw "PowershellRepositoryKey must be a secure string"
            }

            $patToken = $settings.PowershellRepositoryKey 
            
            $credential = New-Object System.Management.Automation.PSCredential($settings.PowershellRepositoryUsername, $patToken)
            $env:VSS_NUGET_EXTERNAL_FEED_ENDPOINTS = @{endpointCredentials=`
                ,@{endpoint=$settings.PowershellRepositoryFeed;
                username=$Settings.PowershellRepositoryUsername; 
                password=$Credential.GetNetworkCredential().Password }}| Convertto-json -Compress

            if ((Get-PSRepository | where-object Name -eq $settings.PowershellRepository).Count -eq 0){
                Write-Host "Registering Repository"
                Write-Host "  Name     : $($Settings.PowershellRepository)"
                Write-Host "  Feed     : $($settings.PowershellRepositoryFeed)"
                Write-Host "  Username : $($Settings.PowershellRepositoryUsername)"
                Write-Host "  Key      : $($Settings.PowershellRepositoryKey)"

                Register-PSRepository -Name $settings.PowershellRepository `
                                        -SourceLocation $settings.PowershellRepositoryFeed `
                                        -PublishLocation $settings.PowershellRepositoryFeed `
                                        -InstallationPolicy Trusted `
                                        -Verbose:$verbosePreference -Credential $credential

            }
            $publishModuleArguments =@{NuGetApiKey="no value"} 
        }
        else{
            
            if ($settings.PowershellRepositoryKey -isnot [securestring]) { 
                throw "PowershellRepositoryKey must be a secure string"
            }
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "dummyUsername", $settings.PowershellRepositoryKey 
            $clearPowershellRepositoryKey = $Credential.GetNetworkCredential().Password 
            $publishModuleArguments =@{NuGetApiKey=$clearPowershellRepositoryKey }
        }
        if (-not $settings.ShouldNotPublish -or $settings.ShouldNotPublish -eq "False")
        {
            Write-Host "Publishing module $($Settings.ProjectName) -version $($settings.Fullversion) to $($settings.PowershellRepository) "
            
            Publish-module  -Path "$ArtifactsPath\$($settings.ProjectName)" @publishModuleArguments -Force -Repository $settings.PowershellRepository   -ErrorAction Stop -Verbose:$verbosePreference
            Write-Host "Published module "
        }
        
        Write-Host "Finding module $($Settings.ProjectName) -version $($settings.Fullversion)"
        $module = Find-Module $Settings.ProjectName -Repository $settings.PowershellRepository -RequiredVersion $settings.Fullversion -AllowPrerelease -Credential $credential -ErrorAction SilentlyContinue -Verbose:$verbosePreference
        while(-not $module){
            Write-Verbose "Package not found so sleeping for 10s"
            Start-Sleep 10
            Write-Host "." -NoNewline
            $module = Find-Module $Settings.ProjectName -Repository $settings.PowershellRepository -RequiredVersion $settings.Fullversion  -AllowPrerelease -Verbose:$verbosePreference -ErrorAction SilentlyContinue -Credential $credential
        }
        Write-Host "-Found module $($module.Version)"

        #Downloading the module
        $DownloadFolder = join-path $ArtifactsPath "DownloadedModules"
        if (-not (Test-Path $DownloadFolder)){new-item $DownloadFolder -ItemType Directory| Out-Null}
        $DownloadModuleFolder = join-path (join-path $DownloadFolder $Settings.ProjectName) $settings.VersionNumber
        if (Test-Path $DownloadModuleFolder){remove-item $DownloadModuleFolder -Recurse -Force | Out-Null}
        Write-Host "Saving module locally to test ($DownloadFolder)"
        Save-Module $Settings.ProjectName -RequiredVersion $settings.Fullversion -Path $DownloadFolder -Repository $settings.PowershellRepository -AllowPrerelease  -verbose:$verbosePreference -ErrorAction Stop -Credential $credential
        
        #Testing on the downloaded module
        Write-Host "Running tests on module in ($DownloadModuleFolder)"

            
        $container = New-PesterContainer -Path "$artifactspath/$($settings.ProjectName).Tests" -Data @{ModulePath="$DownloadModuleFolder"}  #An empty data is required for Pester 5.1.0 Beta 

        $pesterpreference = New-PesterConfiguration @{
				TestResult=@{OutputPath="$outPath/test-results/$($settings.ProjectName).postPublish.tests.results.xml" 
        					;OutputFormat="NUnitXml"
							;Enabled=$true
							;TestSuiteName="PostPublish"};
        		Run=@{Container = $container
					 ;PassThru=$true}
        		Filter=@{Tag =  "ModuleInstall" };
        		Output=@{Verbosity= "Detailed"}
		}

		$results = Invoke-Pester -Configuration $pesterpreference 
		if ($settings.FailOnTests -eq $true -and ($results.FailedCount -gt 0)) {
				throw "Tests have failed see results above"
			}    
		}
    catch {
        Throw
    }
    finally {
        Pop-Location
    }