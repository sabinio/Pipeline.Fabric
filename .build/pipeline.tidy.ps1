[CmdletBinding()]
param($rootPath, $Settings)

    try{
        if (-not $noLogo) {
            Write-BannerTidy
        }

    }
    catch {
        throw
    }
    finally 
    {
        Pop-Location
    }