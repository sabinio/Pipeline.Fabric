function Compare-QuerySql {
    # Returns $true when the two SQL strings are equivalent, ignoring line-ending and
    # trailing whitespace differences that are not meaningful.
    param([string]$a, [string]$b)

    $normalise = {
        param($s)
        if ($null -eq $s) { return "" }
        (($s -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd()
    }
    return (& $normalise $a) -eq (& $normalise $b)
}
