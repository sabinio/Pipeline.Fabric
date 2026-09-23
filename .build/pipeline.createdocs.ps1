[CmdletBinding()]
param($settings, $rootpath)



$psd1File = "$rootpath\src\$($settings.ProjectName).module\$($settings.ProjectName).psd1"
$MarkDownHelp = "$rootpath\\docs"
$functions = "$rootpath\src\$($settings.ProjectName).module\Functions"

Import-Module $psd1File -Force
    $files = Get-ChildItem $functions -Filter *.ps1
    foreach ($f in $files) {
        New-MarkdownHelp -Command $f.BaseName -OutputFolder $MarkDownHelp -force
    }

    $homeMarkdown = "$MarkDownHelp\Home.md"

    $markDownFiles = Get-ChildItem $MarkDownHelp -Exclude "Home.md"
    $markdownLinks = ""
    foreach ($m in $markDownFiles) {
        $markdownLinks += "|[$($m.BaseName)]($($m.BaseName))`n"
    } 
$homeContent = @"
#$($settings.ProjectName) wiki

Welcome to the $($settings.ProjectName) wiki!
Here's a list of the cmdlets in this module.
|Module|
|-|
$markDownLinks
"@
New-Item -Path $homeMarkdown -ItemType File -Value $homeContent -Force