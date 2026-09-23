using namespace  System.Management.Automation.Language;
Set-StrictMode -version 1.0
<#
    .DESCRIPTION
        Custom rule text when you call Invoke-Something.
#>  


function Write-BeforeAll {
    param ($Statements, $Start, $End, $Message)
    
    Write-DebugDiag -message1 "Write-BeforeAll -start" -Message2 "$($Statements.Count) $Start $End $Message" -Extent $statement[0].Extent -Level 0

    try {

        $StartingExtent = $statements[$Start].Extent
        $EndingExtent = $statements[$End].Extent
        $extent = [ScriptExtent]::new([ScriptPosition]::new("", $StartingExtent.StartScriptPosition.LineNumber, $StartingExtent.StartScriptPosition.ColumnNumber, "")
            , [ScriptPosition]::new("", $EndingExtent.EndScriptPosition.LineNumber, $EndingExtent.EndScriptPosition.ColumnNumber, ""))

        $Response = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
            Message    = $Message
            ; Extent   = $Extent
            ;
            ; RuleName = "sdfsd"#$PSCmdlet.MyInvocation.InvocationName
            ; Severity = "Warning" 
        }

        $startLineNumber = $Response.Extent.StartLineNumber
        [int]$endLineNumber = $Response.Extent.EndLineNumber
        [int]$startColumnNumber = $Response.Extent.StartColumnNumber
        [int]$endColumnNumber = $Response.Extent.EndColumnNumber
        [string]$correction = "BeforeAll {`n    " + ($statements[$start..$end].extent.text -join "`n    ") + "`n}"
        [string]$optionalDescription = 'Wrap statements in BeforeAll'
                       
        $correctionExtent = New-Object Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent $startLineNumber, $endLineNumber, $startColumnNumber, $endColumnNumber, $correction, "", $optionalDescription
        $suggestedCorrections = New-Object System.Collections.ObjectModel.Collection['Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent']
        $suggestedCorrections.add($correctionExtent) | out-null
        $Response.SuggestedCorrections = $suggestedCorrections
   
        Write-Output $Response

        Write-DebugDiag -Message1 "Write-BeforeAll -end" -Messge2 "Respone = $($Response.Message)" -Extent $statement[0].Extent -Level 0
    }
    catch {
        Write-DebugDiag -Message1 "Write-BeforeAll -error" -Extent $_ $statement[0].Extent -Level 0

    }
} 
function Write-DebugDiag {
    param ($message1, $message2, $Extent, $level)
    $indent = (" " * 2 * $level)
    try {
        if ($null -ne $Env:DEBUGSCRIPTANAL) {
            Write-output ([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]::new($indent + $message1, $Extent, $message2, "Information", $null, $null, $null))
        }
    }
    Catch {
        Write-Host $_
    }
}
function PesterScriptBlocksForV5Compat {

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.Management.Automation.Language.ScriptBlockAst]$ScriptBlockAst,
        [string] $ScriptFilePath
    )

    Begin {
        $PesterBlockCommands = "Describe", "Context", "InPesterModuleScope"
        $PesterRunCommands = "BeforeAll", "BeforeEach", "BeforeDiscovery", "AfterAll", "AfterEach", "InModuleScope", "It"

        function get-FileLink([StatementAst]$Statement, $file) {
            return "$($Statement.Extent.File)`:$($Statement.Extent.StartLineNumber)`:$($Statement.Extent.StartColumnNumber)"
        }

        function Find-BadBlocks {
            param($script, $file, $level = 1) 

            
            $blocks = $script.FindAll( { param ($i) return ($i -is [NamedBlockAst]) }, $false)
            foreach ( $o in $blocks ) {
                ##find all statements in a block, each Should -Be a command Ast with command of a pester command

                #We navigate the statements as using Find results in finding items within command calls
                [int]$FirstBadStatementInBlock = -2
                [int]$lastBadStatementInBlock = -2
                
                $StatementIndex = 0
                $badBlock = $false
                $bad = ""
                foreach ($statement in $o.statements) {
                    $BadStatement = $false
                    Write-DebugDiag -message1 "Processing " -Message2 "$StatementIndex/$($o.Statements.Count) $FirstBadStatementInBlock $LastBadStatementInBlock "  -Extent $statement.Extent -Level $level

                    if ($statement -isNot [PipelineAst] ) {
                        #All Pester statements are Pipelines
                        $bad = "Code found outside of Pester Block Not PipelineAST $statement"  
                        $BadStatement=$true 
                    }
                    elseif ( $statement.PipelineElements[0] -isnot [CommandAst]) {
                        #The item in the pipeline needs to be a Command, expressions and other things aren't valid pester
                        $bad = "Code found outside of Pester Block Not CommandAst $statement"   
                        $BadStatement=$true
                    }
                    else {
                        
                        $command = $statement.PipelineElements[0].CommandElements
                        if ($null -eq $Command) {
                            Write-Verbose "Should definitely not get here"
                        }
                        if ($PesterBlockCommands -contains $Command[0].Value ) {
                            Write-Verbose "Found Command $($Command[0])"
                            #We are using this rather than find otherwise scripts for ForEach or other parameter values are incorrectly identified
                            $scripts = $command | Where-Object { $_ -is [ScriptBlockExpressionAst] }
                            if ($scripts.Length -gt 1 ) {
                                Throw "should only have 1 script in a describe block"
                            }  
                            else {
                                #Check child blocks
                                Find-BadBlocks $scripts[0].ScriptBlock -file $File -level ($level + 1)
                            }
                        } 
                        elseif ($PesterRunCommands -notContains $Command[0].Value ) {

                            $bad = "Code found outside of Pester Block $statement"
                            $BadStatement=$true
                        }
                    }
                    
                    #Check if statement is continuous
                    if ($badstatement) {
                        Write-DebugDiag -message1 "Found bad block" -Message2 $bad  -Extent $statement.Extent -Level $level
                        if (-not $badBlock) {
                            $FirstBadStatementInBlock = $StatementIndex
                            $badBlock = $true
                        }
                        $LastBadStatementInBlock = $StatementIndex
                    }
                    else {
                        if ($badBlock) {
                            Write-DebugDiag -message1 "Save Bad Block on Good Statement" -Message2 "$StatementIndex $FirstBadStatementInBlock $LastBadStatementInBlock"  -Extent $statement.Extent -Level $level

                            Write-BeforeAll  -statements $o.statements -Start $FirstBadStatementInBlock -end $lastBadStatementInBlock -message $bad#"--"
                            $badBlock = $false
                            $bad = ""
                        }
                    }
                    if ( $statementIndex -eq ($o.statements.Count - 1) -and $badBlock) {
                        Write-BeforeAll  -statements $o.statements -Start $FirstBadStatementInBlock -end $lastBadStatementInBlock -message $bad
                        $bad = ""
                    }
                
                    $StatementIndex ++
                }
            }
        }
    }


    Process {
        Try {
            #it seems VSCode runs this on fragments, if we dont do this it slows stuff down and we only need to check the global content
            #We possibly could work at a fragment level to see if its valid
            if ($null -eq $ScriptBlockAst.Parent.Parent) {
                #Check for Pester
                $Pester = $ScriptBlockAst.Find( { param ($command) $command -is [CommandAst] -and ([commandAst]$command).CommandElements[0].Value -eq "Describe" }, $true)

                if ($null -ne $Pester) {
        
                    Find-BadBlocks -Script $ScriptBlockAst -File "" -level 2
                }
        
            }
        
        }
        catch {
    
            $PSCmdlet.ThrowTerminatingError( $_ )
    
        }
    }
}

Export-ModuleMember -Function PesterScriptBlocksForV5Compat