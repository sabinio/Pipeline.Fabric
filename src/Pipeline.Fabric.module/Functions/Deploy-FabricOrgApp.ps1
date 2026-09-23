function Deploy-FabricOrgApp {
    <#
    .SYNOPSIS
        Deploys an Org App (and its audiences) to a Fabric workspace from its Git
        source definition.

    .DESCRIPTION
        The fabric-cicd deployment (Deploy-FabricItems) does not publish OrgApp /
        OrgAppAudience items, so this function deploys them directly against the dedicated
        Fabric OrgApp / OrgAppAudience REST APIs:

          OrgApp:         https://learn.microsoft.com/rest/api/fabric/orgapp/items
          OrgAppAudience: https://learn.microsoft.com/rest/api/fabric/orgappaudience/items

        Given the source folder of an Org App (the '<name>.OrgApp' directory produced by
        Fabric Git integration) it:

          1. Reads the app's '.platform' (display name) and 'definition.json'.
          2. Creates the OrgApp (POST .../orgApps, with the definition inline) if one with
             that display name does not already exist, otherwise updates its definition
             (POST .../orgApps/{id}/updateDefinition).
          3. For every OrgAppAudience under the app's '.children' folder, rewrites the
             'parentAppId' - which in Git holds the app's *logicalId* - to the id of the
             app just deployed, then creates or updates each audience against the
             .../orgAppAudiences API.

        Each definition is the two parts the APIs accept - 'definition.json' and
        '.platform'. Create and updateDefinition are long-running operations, so 202
        responses are polled to completion (by Invoke-FabricRestCall). The caller must
        already be authenticated to Fabric (e.g. via Connect-Fabric).

        Both the app's 'elements' and every audience's 'elementReferences' are rewritten from
        the Git form (which identifies each report by 'itemLogicalId') to the resolved form the
        APIs require - 'itemId' (the report's real id in the target workspace) plus
        'folderObjectId' (the workspace id). Both must be resolved the same way because the
        OrgAppAudience API requires each audience reference's (itemId, folderObjectId, itemType)
        to match the parent app's corresponding element. The reports deployed into the workspace
        do not carry the Git logical ids (fabric-cicd leaves their .platform logicalId all-zero),
        so the logical id cannot be matched against the workspace items directly; instead a map
        itemLogicalId -> { itemId; folderObjectId } is built by joining the app's own 'elements'
        (logicalId + displayName) to the workspace items (displayName + real id) on display name,
        then applied to the app and every audience. The referenced reports must already exist in
        the target workspace (they do when the item deployment - Deploy-FabricItems - has run
        first, as pipeline.deploy-workspace does).

    .PARAMETER WorkspaceName
        Display name of the target Fabric workspace. The id is resolved from it.

    .PARAMETER WorkspaceId
        Target workspace id. Supply this instead of WorkspaceName to skip name resolution.

    .PARAMETER Path
        Path to the '.OrgApp' source folder (the one containing '.platform',
        'definition.json' and the '.children' folder).

    .PARAMETER FolderPath
        Workspace folder the app should live in, as a '/'-separated path relative to the
        workspace root (e.g. 'Apps') - normally the app's location in the Git source tree
        relative to the repository directory. Folders are created if they do not exist,
        and an existing app is moved if it is not already there. Omit to deploy to the
        workspace root.

    .PARAMETER SkipAudiences
        Deploy only the OrgApp shell and not the audiences under '.children'.

    .EXAMPLE
        Connect-Fabric
        Deploy-FabricOrgApp -WorkspaceName 'myworkspace' -Path 'src/myworkspace/Apps/Reports.OrgApp'

    .EXAMPLE
        Deploy-FabricOrgApp -WorkspaceName 'myworkspace' -Path 'src/myworkspace/Apps/Reports.OrgApp' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$WorkspaceName,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$WorkspaceId,

        [Parameter(Mandatory)]
        [string]$Path,

        [string]$FolderPath,

        [switch]$SkipAudiences
    )

    # Builds InlineBase64 definition parts from the files directly under an item folder
    # (the item's '.platform' and 'definition.json'); child folders such as '.children'
    # are deployed as their own items, not as parts of the parent.
    function Get-DefinitionParts {
        param(
            [string]$ItemPath,
            [hashtable]$Overrides   # optional map of relative-path -> replacement text
        )

        $parts = @()
        # -Force: on Linux runners dot-files such as '.platform' are hidden and would
        # otherwise be skipped, and the API requires '.platform' when updateMetadata=true.
        foreach ($file in (Get-ChildItem -LiteralPath $ItemPath -File -Force)) {
            $relativePath = $file.Name
            if ($Overrides -and $Overrides.ContainsKey($relativePath)) {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($Overrides[$relativePath])
            }
            else {
                $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            }
            $parts += [ordered]@{
                path        = $relativePath
                payload     = [System.Convert]::ToBase64String($bytes)
                payloadType = 'InlineBase64'
            }
        }
        return , $parts
    }

    # Resolves a '/'-separated workspace folder path to its folder id, creating any
    # missing folders along the way. Returns $null for an empty path (workspace root).
    function Resolve-FabricFolderId {
        param(
            [string]$WorkspaceId,
            [string]$FolderPath
        )

        $segments = @($FolderPath -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })
        if ($segments.Count -eq 0) { return $null }

        $folders = @(Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/folders")
        $parentId = $null
        foreach ($segment in $segments) {
            $match = $folders | Where-Object {
                if ($_.displayName -ne $segment) { return $false }
                $itsParent = if ($_.PSObject.Properties['parentFolderId']) { $_.parentFolderId } else { $null }
                if ($parentId) { return $itsParent -eq $parentId }
                return [string]::IsNullOrEmpty($itsParent)
            }
            if (-not $match) {
                if (-not $PSCmdlet.ShouldProcess("Folder '$segment' (under '$FolderPath')", "Create workspace folder")) {
                    return $null
                }
                Write-Host "Creating workspace folder '$segment'"
                $body = @{ displayName = $segment }
                if ($parentId) { $body.parentFolderId = $parentId }
                $match = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/folders" -Method Post -Body $body
                $folders += $match
            }
            $parentId = $match.id
        }
        return $parentId
    }

    # Creates the item in the given OrgApp collection ('orgApps' or 'orgAppAudiences') if
    # none with that display name exists, otherwise updates its definition. Returns the
    # deployed item id. With -NoWait the create/update long-running operation is not awaited;
    # the pending operation ('Fabric.PendingOperation') is returned instead so the caller can
    # submit several and await them together (see -NoWait on Invoke-FabricRestCall).
    function Set-OrgAppItem {
        param(
            [string]$WorkspaceId,
            [string]$Collection,   # 'orgApps' or 'orgAppAudiences'
            [string]$Kind,         # readable label for logging
            [string]$DisplayName,
            $Parts,
            [string]$FolderId,     # target workspace folder; empty = workspace root
            [switch]$NoWait
        )

        $existing = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/$Collection" |
            Where-Object { $_.displayName -eq $DisplayName }
        if ($existing -is [array] -and $existing.Count -gt 1) {
            throw "Multiple $Kind items named '$DisplayName' found in the workspace - cannot determine which to update."
        }

        $definition = @{ parts = $Parts }

        if ($existing) {
            $itemId = $existing.id

            # Move the item if it is not already in the requested folder.
            $currentFolderId = if ($existing.PSObject.Properties['folderId']) { $existing.folderId } else { $null }
            if ($FolderId -and $currentFolderId -ne $FolderId) {
                if ($PSCmdlet.ShouldProcess("$Kind '$DisplayName' ($itemId)", "Move to folder $FolderId")) {
                    Write-Host "Moving $Kind '$DisplayName' ($itemId) to folder $FolderId"
                    Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/items/$itemId/move" `
                        -Method Post -Body @{ targetFolderId = $FolderId } | Out-Null
                }
            }

            if ($PSCmdlet.ShouldProcess("$Kind '$DisplayName' ($itemId)", "Update definition")) {
                Write-Host "Updating $Kind '$DisplayName' ($itemId)"
                $op = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/$Collection/$itemId/updateDefinition?updateMetadata=true" `
                    -Method Post -Body @{ definition = $definition } -NoWait:$NoWait
                if ($NoWait) { return $op }
            }
            return $itemId
        }

        if ($PSCmdlet.ShouldProcess("$Kind '$DisplayName'", "Create item")) {
            Write-Host "Creating $Kind '$DisplayName'"
            $body = @{
                displayName = $DisplayName
                definition  = $definition
            }
            if ($FolderId) { $body.folderId = $FolderId }
            $created = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/$Collection" -Method Post -Body $body -NoWait:$NoWait
            if ($NoWait) { return $created }
            # A 201 returns the created item (with id); a 202 LRO returns the operation
            # status instead, so fall back to a list lookup for the assigned id.
            if ($created.id) {
                return $created.id
            }
            $new = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/$Collection" |
                Where-Object { $_.displayName -eq $DisplayName }
            return $new.id
        }
        return $null
    }

    # Builds the map used to resolve element references: itemLogicalId -> { itemId; folderObjectId }.
    # The reports deployed into the workspace do not carry the Git logical ids (their .platform
    # logicalId is all-zero), so the logical id cannot be matched against the workspace items
    # directly. Instead the app's 'elements' pair each logical id with a display name, and the
    # workspace items pair each display name with its real id - joined on display name here.
    # folderObjectId is the workspace id (org app element references locate content by workspace,
    # which is what Fabric's own Git-synced definitions use).
    function Build-LogicalIdReferenceMap {
        param(
            $AppDefinition,        # parsed app definition.json (its 'elements' supply logicalId + displayName)
            $WorkspaceItems,       # workspace items list (supply displayName -> real id)
            [string]$WorkspaceId
        )

        $itemByKey = @{}
        foreach ($item in @($WorkspaceItems)) {
            $key = "$($item.type)|$($item.displayName)"
            if ($itemByKey.ContainsKey($key)) {
                throw "Multiple '$($item.type)' items named '$($item.displayName)' in workspace $WorkspaceId - cannot resolve element references unambiguously."
            }
            $itemByKey[$key] = $item
        }

        $map = @{}
        foreach ($element in @($AppDefinition.elements)) {
            if (-not $element.itemLogicalId) { continue }
            $item = $itemByKey["$($element.itemType)|$($element.displayName)"]
            if (-not $item) {
                throw "Report '$($element.displayName)' ($($element.itemType)) referenced by the org app was not found in the target workspace. Deploy the workspace items before the org app."
            }
            $map[$element.itemLogicalId] = [ordered]@{ itemId = $item.id; folderObjectId = $WorkspaceId }
        }
        return $map
    }

    # Rewrites an element-reference list (an app 'elements' array or an audience
    # 'elementReferences' array) from the Git form that identifies each report by 'itemLogicalId'
    # to the resolved form ('itemId' + 'folderObjectId') the APIs require. All other properties
    # (elementType, displayName, isElementHidden, ...) are preserved; references without a logical
    # id (already resolved, or app-only elements such as links) are passed through unchanged.
    function Resolve-ElementReferenceList {
        param(
            $References,           # array of element references (PSCustomObjects)
            [hashtable]$RefMap,    # itemLogicalId -> { itemId; folderObjectId }
            [string]$Context       # label for error messages
        )

        $resolved = foreach ($ref in @($References)) {
            if (-not ($ref.PSObject.Properties['itemLogicalId'] -and $ref.itemLogicalId)) {
                $ref
                continue
            }
            $target = $RefMap[$ref.itemLogicalId]
            if (-not $target) {
                throw "${Context}: no deployed workspace item maps to logical id '$($ref.itemLogicalId)'."
            }

            $new = [ordered]@{}
            foreach ($prop in $ref.PSObject.Properties) {
                if ($prop.Name -eq 'itemLogicalId') { continue }
                $new[$prop.Name] = $prop.Value
            }
            $new['folderObjectId'] = $target.folderObjectId
            $new['itemId'] = $target.itemId
            $new
        }
        return @($resolved)
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Org App source path not found: $Path"
    }

    $platformPath = Join-Path $Path '.platform'
    if (-not (Test-Path -LiteralPath $platformPath)) {
        throw "No '.platform' found in '$Path' - is this an .OrgApp folder?"
    }
    $platform = Get-Content -LiteralPath $platformPath -Raw | ConvertFrom-Json
    if ($platform.metadata.type -ne 'OrgApp') {
        throw "'$Path' is a '$($platform.metadata.type)' item, not an OrgApp."
    }
    $appName = $platform.metadata.displayName

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $WorkspaceId = Get-FabricWorkspaceId -workspaceName $WorkspaceName
        if (-not $WorkspaceId) {
            throw "Workspace '$WorkspaceName' not found."
        }
    }

    Write-Host "=== Deploying Org App '$appName' to workspace $WorkspaceId ==="

    # Resolve the workspace folder the app should live in (creating it if needed) so the
    # app lands in the same folder as in the Git source tree.
    $folderId = $null
    if (-not [string]::IsNullOrWhiteSpace($FolderPath)) {
        $folderId = Resolve-FabricFolderId -WorkspaceId $WorkspaceId -FolderPath $FolderPath
        if ($folderId) {
            Write-Host "App folder '$FolderPath' resolved to $folderId"
        }
    }

    # Build the itemLogicalId -> { itemId; folderObjectId } map (see Build-LogicalIdReferenceMap)
    # used to resolve the app's 'elements' and every audience's 'elementReferences'. Both must be
    # resolved the same way: the audience API requires each reference's (itemId, folderObjectId,
    # itemType) to match the parent app's corresponding element, so a verbatim app (logical ids)
    # would never match the resolved audiences.
    $appDefinition = Get-Content -LiteralPath (Join-Path $Path 'definition.json') -Raw | ConvertFrom-Json
    $workspaceItems = Invoke-FabricRestCall "v1/workspaces/$WorkspaceId/items"
    $refMap = Build-LogicalIdReferenceMap -AppDefinition $appDefinition -WorkspaceItems $workspaceItems -WorkspaceId $WorkspaceId

    # Deploy the OrgApp shell, resolving its 'elements' from Git logical ids to the real
    # workspace itemId + folderObjectId (wrapped in @() so a single element still serialises as
    # a JSON array).
    $appDefinition.elements = @(Resolve-ElementReferenceList -References $appDefinition.elements `
        -RefMap $refMap -Context "App '$appName'")
    $appParts = Get-DefinitionParts -ItemPath $Path -Overrides @{ 'definition.json' = ($appDefinition | ConvertTo-Json -Depth 20) }
    $appId = Set-OrgAppItem -WorkspaceId $WorkspaceId -Collection 'orgApps' -Kind 'Org App' -DisplayName $appName -Parts $appParts -FolderId $folderId

    if (-not $appId) {
        Write-Host "Org App '$appName' not deployed (WhatIf) - skipping audiences."
        return
    }
    Write-Host "Org App '$appName' deployed with id $appId"

    if ($SkipAudiences) {
        Write-Host "SkipAudiences set - not deploying audiences."
        return
    }

    $childrenPath = Join-Path $Path '.children'
    if (-not (Test-Path -LiteralPath $childrenPath)) {
        Write-Host "No '.children' folder - no audiences to deploy."
        return
    }

    $audienceFolders = Get-ChildItem -LiteralPath $childrenPath -Directory |
        Where-Object { $_.Name -like '*.OrgAppAudience' }

    # Submit every audience create/update first (-NoWait), collecting the long-running
    # operations, then await them all together below. The operations run concurrently in
    # Fabric, so this is far faster than awaiting each before submitting the next.
    $pendingOps = [System.Collections.Generic.List[object]]::new()
    foreach ($folder in $audienceFolders) {
        $audiencePlatform = Get-Content -LiteralPath (Join-Path $folder.FullName '.platform') -Raw | ConvertFrom-Json
        $audienceName = $audiencePlatform.metadata.displayName

        # Rewrite parentAppId (the app's Git logicalId) to the deployed OrgApp id, and resolve
        # each element reference from its logical id to the real target-workspace item id.
        $defPath = Join-Path $folder.FullName 'definition.json'
        $definition = Get-Content -LiteralPath $defPath -Raw | ConvertFrom-Json
        $definition.parentAppId = $appId
        # Wrap in @() so a single resolved reference still serialises as a JSON array (the
        # OrgAppAudience API rejects a lone object for 'elementReferences').
        $definition.elementReferences = @(Resolve-ElementReferenceList -References $definition.elementReferences `
            -RefMap $refMap -Context "Audience '$audienceName'")
        $definitionJson = $definition | ConvertTo-Json -Depth 20

        $audienceParts = Get-DefinitionParts -ItemPath $folder.FullName -Overrides @{ 'definition.json' = $definitionJson }
        $op = Set-OrgAppItem -WorkspaceId $WorkspaceId -Collection 'orgAppAudiences' -Kind 'Org App Audience' -DisplayName $audienceName -Parts $audienceParts -NoWait
        if ($op -and $op.PSObject.TypeNames -contains 'Fabric.PendingOperation') {
            $op | Add-Member -NotePropertyName Name -NotePropertyValue $audienceName -Force
            $pendingOps.Add($op)
        }
    }

    # Await every submitted operation. Each is waited to a terminal state before its result is
    # judged, and all are awaited even if one fails, so a single bad audience does not leave the
    # others un-awaited; any failures are aggregated and thrown together at the end.
    Write-Host "Awaiting $($pendingOps.Count) audience operation(s)..."
    $failures = [System.Collections.Generic.List[string]]::new()
    foreach ($op in $pendingOps) {
        try {
            Wait-FabricLongRunningOperation -OperationUrl $op.OperationUrl -RetryAfter $op.RetryAfter -Headers $op.Headers | Out-Null
            Write-Host "  Audience '$($op.Name)' completed."
        }
        catch {
            Write-Host -ForegroundColor Red "  Audience '$($op.Name)' failed: $($_.Exception.Message)"
            $failures.Add("$($op.Name): $($_.Exception.Message)")
        }
    }
    if ($failures.Count -gt 0) {
        throw "One or more org app audiences failed to deploy:`n - $($failures -join "`n - ")"
    }

    Write-Host "✅ Org App '$appName' deployment completed ($($audienceFolders.Count) audience(s))."
}
