# Internal helpers load first so any script-scoped data they define (e.g. types.ps1)
# is available to the public functions.
# Join-Path is used rather than a '\' separated literal so the module also loads on Linux
# build agents, where a backslash is a legal filename character and not a separator.
foreach ($function in (Get-ChildItem (Join-Path $PSScriptRoot 'Functions' | Join-Path -ChildPath 'Internal' | Join-Path -ChildPath '*.ps1'))) {
	Write-Verbose "Loading $($function.BaseName)"
	. $function.FullName
}

foreach ($function in (Get-ChildItem (Join-Path $PSScriptRoot 'Functions' | Join-Path -ChildPath '*.ps1'))) {
	Write-Verbose "Loading $($function.BaseName)"
	. $function.FullName
}
