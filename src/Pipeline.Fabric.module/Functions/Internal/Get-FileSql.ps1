function Get-FileSql {
    # Raw file content, or an empty string for an empty file.
    param($File)
    $sql = Get-Content -Path $File.FullName -Raw
    if ($null -eq $sql) { return "" }
    return $sql
}
