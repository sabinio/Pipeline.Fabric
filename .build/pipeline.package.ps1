[CmdletBinding()]
param($settings, $ArtifactsPath)

    if (-not $noLogo) { Write-BannerPackage }

    . "$PSScriptroot/scripts/sabinio.pipeline.artifacts/package-artifacts.ps1"        

    push-location $rootPath

    try{
        write-Verbose "Writing artifacts to $ArtifactsPath"

        Publish-Artifacts -artifactsPath  $artifactsPath -path ".build/*" -name ".build" -verbose:$VerbosePreference

        #For each artifact to be produced by the build put an entry here. 
        
        Publish-Artifacts -artifactsPath  $artifactsPath -path "src/$($settings.ProjectName).module/*" -Name "$($settings.ProjectName)" -verbose:$VerbosePreference
        Publish-Artifacts -artifactsPath  $artifactsPath -path "src/$($settings.ProjectName).Tests/*" -Name "$($settings.ProjectName).Tests" -verbose:$VerbosePreference

        Publish-Artifacts -artifactsPath  $artifactsPath -path "docs/*" -Name "docs" -verbose:$VerbosePreference

    }
    catch{
        Throw
    }
    finally{
        Pop-Location
    }