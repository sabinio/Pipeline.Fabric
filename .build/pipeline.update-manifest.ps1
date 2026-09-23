function Update-Manifest {
    [CmdletBinding()]
    param($settings, $ArtifactsPath)

    $psd1File = "$ArtifactsPath\$($settings.ProjectName)\$($settings.ProjectName).psd1"
    Write-Host $psd1File
    $psd1File = (Get-Item $psd1File).FullName
    if ((Test-Path $psd1File) -eq $false) {
        throw "$psd1File does not exist!"
    }

    [string] $prerelease = $settings.prerelease
    $VersionNumber = $settings.VersionNumber
    $VersionNumber = $VersionNumber.Trim()

    Write-Host "Updating $psd1File with version=$VersionNumber and prerelease=$prerelease" 

    try {
        Set-ItemProperty -Path $psd1file -Name IsReadOnly -Value $false
        Update-ModuleManifest -Path $psd1File `
            -Prerelease $prerelease `
            -ModuleVersion $VersionNumber
        Set-ItemProperty -Path $psd1file -Name IsReadOnly -Value $true
        write-host $ErrorActionPreference
        Test-ModuleManifest -Path $psd1File -ErrorAction $ErrorActionPreference
    
    }
    catch {
        Throw $_
    }
}