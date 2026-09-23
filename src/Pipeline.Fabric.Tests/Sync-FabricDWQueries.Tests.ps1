<#
    Pester tests for Sync-FabricDWQueries.

    These tests mock the two API seams so no real Fabric / Power BI calls are made:
      * Get-FabricDWQueries   -> returns the "workspace" (remote) saved queries
      * Invoke-FabricDWQueryApi -> the write endpoint (Post = create, Put = update, Delete = remove)

    They encode the behaviour described in Sync-DWQueries.md. Each Context maps to one
    row of that table:

    | Workspace  | Local   | Same | Newest    | Update          | Notes                  |
    |------------|---------|------|-----------|-----------------|------------------------|
    | NonShared  | Exists  |  =   | (either)  | Workspace       | promote workspace->shared |
    | NonShared  | Exists  |  !=  | Workspace | Local           |                        |
    | NonShared  | Exists  |  !=  | Local     | Workspace       | promote workspace->shared |
    | NonShared  | Missing |  -   | -         | None            |                        |
    | Missing    | Exists  |  -   | -         | Workspace       | create (shared)        |
    | Exists     | Exists  |  =   | -         | None            |                        |
    | Exists     | Exists  |  !=  | Local     | Workspace       |                        |
    | Exists     | Exists  |  !=  | Workspace | Local           |                        |
    | Exists     | Missing |  -   | -         | Remove Workspace|                        |

    Rule: every write to a workspace query makes it shared (isShared = true).
#>

param($ModulePath, $ProjectName)

BeforeDiscovery {
    if (-not (Test-Path "Variable:ProjectName") -or [string]::IsNullOrWhiteSpace($ProjectName)) { $ProjectName = (Get-Item $PSScriptRoot).BaseName -replace ".tests", "" }
    if (-not (Test-Path "Variable:ModulePath") -or [string]::IsNullOrWhiteSpace($ModulePath)) { $ModulePath = "$PSScriptRoot\..\$ProjectName.module" }
}

BeforeAll {
    if (-not (Test-Path "Variable:ProjectName") -or [string]::IsNullOrWhiteSpace($ProjectName)) { $ProjectName = (Get-Item $PSScriptRoot).BaseName -replace ".tests", "" }
    if (-not (Test-Path "Variable:ModulePath") -or [string]::IsNullOrWhiteSpace($ModulePath)) { $ModulePath = "$PSScriptRoot\..\$ProjectName.module" }
    Import-Module (Join-Path $ModulePath "$ProjectName.psd1") -Force

    $script:Dwid = '00000000-0000-0000-0000-000000000000'

    # Create a *.sql file in the given folder and (optionally) stamp its LastWriteTime.
    function New-LocalSqlFile {
        param(
            [Parameter(Mandatory)][string]$Dir,
            [Parameter(Mandatory)][string]$Name,
            [Parameter(Mandatory)][string]$Content,
            [datetime]$LastWrite
        )
        $path = Join-Path $Dir "$Name.sql"
        Set-Content -LiteralPath $path -Value $Content -NoNewline
        if ($PSBoundParameters.ContainsKey('LastWrite')) {
            (Get-Item -LiteralPath $path).LastWriteTime = $LastWrite
        }
        return $path
    }
}

AfterAll {
    Remove-Module $ProjectName -Force -ErrorAction SilentlyContinue
}

Describe 'Sync-FabricDWQueries' {

    BeforeEach {
        # Fresh, empty warehouse folder per test.
        $script:Dir = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:Dir | Out-Null

        # Default: no writes happen. Individual tests assert what was / wasn't called.
        Mock -ModuleName $ProjectName Invoke-FabricDWQueryApi { }
    }

    Context 'Row 1 - Workspace NonShared, Local Exists, SQL Same -> promote workspace to shared' {
        It 'PUTs the query as shared even though the SQL is identical' {
            New-LocalSqlFile -Dir $Dir -Name 'q1' -Content 'select 1' -LastWrite (Get-Date '2026-01-01') | Out-Null
            Mock -ModuleName $ProjectName Get-FabricDWQueries {
                @([pscustomobject]@{ queryId = 101; queryName = 'q1'; sqlExpression = 'select 1'; isShared = $false; updatedAt = (Get-Date '2026-01-02') })
            }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Put' -and $Body.queryName -eq 'q1' -and $Body.isShared -eq $true
            }
        }
    }

    Context 'Row 2 - Workspace NonShared, Local Exists, SQL Different, Workspace newest -> update Local' {
        It 'overwrites the local file with the workspace SQL and makes no API write' {
            $path = New-LocalSqlFile -Dir $Dir -Name 'q2' -Content 'select 1' -LastWrite (Get-Date '2026-01-01')
            Mock -ModuleName $ProjectName Get-FabricDWQueries {
                @([pscustomobject]@{ queryId = 102; queryName = 'q2'; sqlExpression = 'select 2'; isShared = $false; updatedAt = (Get-Date '2026-02-01') })
            }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            (Get-Content -LiteralPath $path -Raw) | Should -BeExactly 'select 2'
            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 0 -Exactly
        }
    }

    Context 'Row 3 - Workspace NonShared, Local Exists, SQL Different, Local newest -> update Workspace (shared)' {
        It 'PUTs the workspace with the local SQL and marks it shared' {
            New-LocalSqlFile -Dir $Dir -Name 'q3' -Content 'select 3' -LastWrite (Get-Date '2026-03-01') | Out-Null
            Mock -ModuleName $ProjectName Get-FabricDWQueries {
                @([pscustomobject]@{ queryId = 103; queryName = 'q3'; sqlExpression = 'select 1'; isShared = $false; updatedAt = (Get-Date '2026-01-01') })
            }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Put' -and $Body.queryName -eq 'q3' -and $Body.sqlExpression -eq 'select 3' -and $Body.isShared -eq $true
            }
        }
    }

    Context 'Row 4 - Workspace NonShared, Local Missing -> None' {
        It 'does nothing for a non-shared workspace query with no local file' {
            Mock -ModuleName $ProjectName Get-FabricDWQueries {
                @([pscustomobject]@{ queryId = 104; queryName = 'q4'; sqlExpression = 'select 1'; isShared = $false; updatedAt = (Get-Date '2026-01-01') })
            }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 0 -Exactly
            Test-Path (Join-Path $Dir 'q4.sql') | Should -BeFalse
        }
    }

    Context 'Row 5 - Workspace Missing, Local Exists -> create Workspace (shared)' {
        It 'POSTs a new shared query built from the local file' {
            New-LocalSqlFile -Dir $Dir -Name 'q5' -Content 'select 5' -LastWrite (Get-Date '2026-01-01') | Out-Null
            Mock -ModuleName $ProjectName Get-FabricDWQueries { @() }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and $Body.queryName -eq 'q5' -and $Body.sqlExpression -eq 'select 5' -and $Body.isShared -eq $true
            }
        }
    }

    Context 'Row 6 - Workspace Exists (shared), Local Exists, SQL Same -> None' {
        It 'makes no API write and leaves the local file untouched' {
            $path = New-LocalSqlFile -Dir $Dir -Name 'q6' -Content 'select 6' -LastWrite (Get-Date '2026-01-01')
            Mock -ModuleName $ProjectName Get-FabricDWQueries {
                @([pscustomobject]@{ queryId = 106; queryName = 'q6'; sqlExpression = 'select 6'; isShared = $true; updatedAt = (Get-Date '2026-01-01') })
            }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 0 -Exactly
            (Get-Content -LiteralPath $path -Raw) | Should -BeExactly 'select 6'
        }
    }

    Context 'Row 7 - Workspace Exists (shared), Local Exists, SQL Different, Local newest -> update Workspace' {
        It 'PUTs the workspace with the local SQL' {
            New-LocalSqlFile -Dir $Dir -Name 'q7' -Content 'select 7 new' -LastWrite (Get-Date '2026-05-01') | Out-Null
            Mock -ModuleName $ProjectName Get-FabricDWQueries {
                @([pscustomobject]@{ queryId = 107; queryName = 'q7'; sqlExpression = 'select 7 old'; isShared = $true; updatedAt = (Get-Date '2026-01-01') })
            }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Put' -and $Body.queryName -eq 'q7' -and $Body.sqlExpression -eq 'select 7 new' -and $Body.isShared -eq $true
            }
        }
    }

    Context 'Row 8 - Workspace Exists (shared), Local Exists, SQL Different, Workspace newest -> update Local' {
        It 'overwrites the local file with the workspace SQL and makes no API write' {
            $path = New-LocalSqlFile -Dir $Dir -Name 'q8' -Content 'select 8 old' -LastWrite (Get-Date '2026-01-01')
            Mock -ModuleName $ProjectName Get-FabricDWQueries {
                @([pscustomobject]@{ queryId = 108; queryName = 'q8'; sqlExpression = 'select 8 new'; isShared = $true; updatedAt = (Get-Date '2026-05-01') })
            }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            (Get-Content -LiteralPath $path -Raw) | Should -BeExactly 'select 8 new'
            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 0 -Exactly
        }
    }

    Context 'Row 9 - Workspace Exists (shared), Local Missing -> remove Workspace' {
        It 'DELETEs the orphaned shared workspace query' {
            Mock -ModuleName $ProjectName Get-FabricDWQueries {
                @([pscustomobject]@{ queryId = 9009; queryName = 'q9'; sqlExpression = 'select 9'; isShared = $true; updatedAt = (Get-Date '2026-01-01') })
            }

            Sync-FabricDWQueries -DatawarehouseId $Dwid -WarehousePath $Dir

            Should -Invoke -ModuleName $ProjectName Invoke-FabricDWQueryApi -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Delete' -and $Body.queryId -eq 9009
            }
        }
    }
}
