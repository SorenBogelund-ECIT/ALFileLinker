# UTF-8 with BOM

# ── Private config helpers ──────────────────────────────────────────────────

function Get-ALFileLinkerConfigPath {
    Join-Path $env:USERPROFILE '.alfilelinker\config.json'
}

function Read-ALFileLinkerConfig {
    $path = Get-ALFileLinkerConfigPath
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            $ht = @{}
            if ($json.CentralFileLinkFolder)        { $ht['CentralFileLinkFolder']        = $json.CentralFileLinkFolder }
            if ($json.RepoDestinationParentFolder)   { $ht['RepoDestinationParentFolder']   = $json.RepoDestinationParentFolder }
            return $ht
        } catch {
            Write-Warning "Failed to read ALFileLinker config: $($_.Exception.Message)"
            return @{}
        }
    }
    return @{}
}

function Resolve-ALFileLinkerDefault {
    <#
    .SYNOPSIS
        Returns the explicit parameter value if given, otherwise falls back to the
        stored default from config.json.  Throws if neither is available.
    #>
    param(
        [string]$Value,
        [string]$ConfigKey,
        [string]$ParameterName
    )

    if (-not [string]::IsNullOrWhiteSpace($Value)) { return $Value }

    $config = Read-ALFileLinkerConfig
    $default = $config[$ConfigKey]

    if ([string]::IsNullOrWhiteSpace($default)) {
        throw "Parameter -$ParameterName was not specified and no default has been configured. Run Set-ALFileLinkerDefaults first."
    }

    Write-Verbose "Using default $ParameterName from config: $default"
    return $default
}

# ── Exported: default-value management ──────────────────────────────────────

function Set-ALFileLinkerDefaults {
    <#
    .SYNOPSIS
        Saves default values for CentralFileLinkFolder and/or RepoDestinationParentFolder
        to a per-user JSON config file (~\.alfilelinker\config.json).
    .EXAMPLE
        Set-ALFileLinkerDefaults -CentralFileLinkFolder 'D:\Central\ALFileLinks'
    .EXAMPLE
        Set-ALFileLinkerDefaults -CentralFileLinkFolder 'D:\Central\ALFileLinks' -RepoDestinationParentFolder 'D:\Repos'
    #>
    [CmdletBinding()]
    param(
        [string]$CentralFileLinkFolder,
        [string]$RepoDestinationParentFolder
    )

    if ([string]::IsNullOrWhiteSpace($CentralFileLinkFolder) -and
        [string]::IsNullOrWhiteSpace($RepoDestinationParentFolder)) {
        throw 'Specify at least one of -CentralFileLinkFolder or -RepoDestinationParentFolder.'
    }

    # Validate paths
    if (-not [string]::IsNullOrWhiteSpace($CentralFileLinkFolder)) {
        if (-not (Test-Path -LiteralPath $CentralFileLinkFolder -PathType Container)) {
            throw "CentralFileLinkFolder path not found: $CentralFileLinkFolder"
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($RepoDestinationParentFolder)) {
        if (-not (Test-Path -LiteralPath $RepoDestinationParentFolder -PathType Container)) {
            throw "RepoDestinationParentFolder path not found: $RepoDestinationParentFolder"
        }
    }

    # Read existing config, merge, write
    $config = Read-ALFileLinkerConfig

    if (-not [string]::IsNullOrWhiteSpace($CentralFileLinkFolder)) {
        $config['CentralFileLinkFolder'] = (Resolve-Path -LiteralPath $CentralFileLinkFolder).Path
    }
    if (-not [string]::IsNullOrWhiteSpace($RepoDestinationParentFolder)) {
        $config['RepoDestinationParentFolder'] = (Resolve-Path -LiteralPath $RepoDestinationParentFolder).Path
    }

    $configPath = Get-ALFileLinkerConfigPath
    $configDir  = Split-Path $configPath -Parent
    if (-not (Test-Path -LiteralPath $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8

    Write-Host "ALFileLinker defaults saved to: $configPath" -ForegroundColor Green
    Get-ALFileLinkerDefaults
}

function Get-ALFileLinkerDefaults {
    <#
    .SYNOPSIS
        Displays the currently configured default values for ALFileLinker.
    .EXAMPLE
        Get-ALFileLinkerDefaults
    #>
    [CmdletBinding()]
    param()

    $config     = Read-ALFileLinkerConfig
    $configPath = Get-ALFileLinkerConfigPath

    [pscustomobject]@{
        CentralFileLinkFolder      = if ($config['CentralFileLinkFolder'])      { $config['CentralFileLinkFolder'] }      else { '(not set)' }
        RepoDestinationParentFolder = if ($config['RepoDestinationParentFolder']) { $config['RepoDestinationParentFolder'] } else { '(not set)' }
        ConfigPath                 = $configPath
    } | Format-List
}

# ── Private helpers ─────────────────────────────────────────────────────────

function Resolve-CentralSubfolder {
    <#
    .SYNOPSIS
        Resolves a subfolder inside the central file-link folder.
        If the default name does not exist, prompts the user to pick one.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CentralDir,

        [Parameter(Mandatory)]
        [string]$DefaultName,

        [Parameter(Mandatory)]
        [string]$Purpose,

        [switch]$Optional
    )

    $defaultPath = Join-Path $CentralDir $DefaultName
    if (Test-Path -LiteralPath $defaultPath -PathType Container) {
        return $defaultPath
    }

    # Default not found - list available subfolders and let the user pick
    $subDirs = @(Get-ChildItem -LiteralPath $CentralDir -Directory)
    if ($subDirs.Count -eq 0) {
        if ($Optional) {
            Write-Verbose "No subfolders found in '$CentralDir' for $Purpose - skipping."
            return $null
        }
        throw "No subfolders found in '$CentralDir' and default folder '$DefaultName' does not exist."
    }

    Write-Warning "Default $Purpose folder '$DefaultName' not found in: $CentralDir"
    Write-Host "Available folders:"

    # Try Out-GridView first (works in ISE / GUI sessions)
    $selected = $null
    try {
        $selected = $subDirs |
            Select-Object Name, FullName |
            Out-GridView -Title "Select the folder to use for $Purpose" -OutputMode Single
    } catch {
        # Out-GridView not available (e.g. console-only session) - fall back to numbered list
        $selected = $null
    }

    if ($null -eq $selected) {
        for ($i = 0; $i -lt $subDirs.Count; $i++) {
            Write-Host "  [$($i + 1)] $($subDirs[$i].Name)"
        }
        if ($Optional) {
            Write-Host "  [0] Skip (do not link $Purpose)"
        }

        do {
            $minVal = if ($Optional) { 0 } else { 1 }
            $input_raw = Read-Host "Enter number ($minVal-$($subDirs.Count)) for $Purpose"
            $choice = 0
            $valid = [int]::TryParse($input_raw, [ref]$choice) -and $choice -ge $minVal -and $choice -le $subDirs.Count
            if (-not $valid) {
                Write-Host "Invalid selection. Please try again."
            }
        } while (-not $valid)

        if ($choice -eq 0) {
            Write-Verbose "User chose to skip $Purpose."
            return $null
        }

        $selected = $subDirs[$choice - 1]
    }

    Write-Host "Using '$($selected.Name)' for $Purpose."
    return $selected.FullName
}

function Set-ALFileLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath,

        [string]$CentralFileLinkFolder,

        [string]$RepoGuidelinesRelPath = 'docs'
    )

    $CentralFileLinkFolder = Resolve-ALFileLinkerDefault -Value $CentralFileLinkFolder -ConfigKey 'CentralFileLinkFolder' -ParameterName 'CentralFileLinkFolder'

    $resolvedPath = (Resolve-Path -LiteralPath $RepoPath).Path
    $centralDir = (Resolve-Path -LiteralPath $CentralFileLinkFolder).Path

    if (-not (Test-Path -LiteralPath $centralDir -PathType Container)) {
        throw "Central folder not found: $centralDir"
    }

    # Auto-detect repo: if given path is not itself a Git repo, scan subdirectories
    if (Test-Path -LiteralPath (Join-Path $resolvedPath '.git')) {
        $repo = $resolvedPath
    } else {
        $childRepos = @(Get-ChildItem -LiteralPath $resolvedPath -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') })

        if ($childRepos.Count -eq 0) {
            throw "No Git repository found in '$resolvedPath' or its immediate subdirectories."
        } elseif ($childRepos.Count -eq 1) {
            $repo = $childRepos[0].FullName
            Write-Host "Found Git repository: $repo"
        } else {
            Write-Host "Multiple Git repositories found in: $resolvedPath"
            $selected = $null
            try {
                $selected = $childRepos |
                    Select-Object Name, FullName |
                    Out-GridView -Title "Select the Git repository to link" -OutputMode Single
            } catch {
                $selected = $null
            }

            if ($null -eq $selected) {
                for ($i = 0; $i -lt $childRepos.Count; $i++) {
                    Write-Host "  [$($i + 1)] $($childRepos[$i].Name)"
                }
                do {
                    $input_raw = Read-Host "Enter number (1-$($childRepos.Count))"
                    $choice = 0
                    $valid = [int]::TryParse($input_raw, [ref]$choice) -and $choice -ge 1 -and $choice -le $childRepos.Count
                    if (-not $valid) { Write-Host "Invalid selection. Please try again." }
                } while (-not $valid)
                $selected = $childRepos[$choice - 1]
            }

            $repo = $selected.FullName
            Write-Host "Using repository: $repo"
        }
    }

    # Resolve subfolder paths - prompt user if defaults are missing
    $codingGuidelinesDir = Resolve-CentralSubfolder `
        -CentralDir $centralDir `
        -DefaultName 'Coding Guidelines' `
        -Purpose 'Coding Guidelines'

    $psScriptsDir = Resolve-CentralSubfolder `
        -CentralDir $centralDir `
        -DefaultName 'PS_Scripts' `
        -Purpose 'PS Scripts' `
        -Optional

    # Find all .md files in Coding Guidelines folder
    $allMdFiles = Get-ChildItem -LiteralPath $codingGuidelinesDir -Filter '*.md' -File

    # Separate copilot-instructions.md from guidelines
    $copilotInstructions = $allMdFiles | Where-Object { $_.Name -eq 'copilot-instructions.md' }
    $guidelineMdFiles = $allMdFiles | Where-Object { $_.Name -ne 'copilot-instructions.md' }

    # Find PS Script subfolders (each subfolder contains a script and possibly config files)
    $psScriptSubDirs = @()
    if ($null -ne $psScriptsDir -and (Test-Path -LiteralPath $psScriptsDir -PathType Container)) {
        $psScriptSubDirs = @(Get-ChildItem -LiteralPath $psScriptsDir -Directory)
        Write-Verbose "Found $($psScriptSubDirs.Count) PS Script subfolder(s) in: $psScriptsDir"
    } else {
        Write-Verbose "PS Scripts folder not resolved or not found (skipping)"
    }

    # Validation
    if ($null -eq $copilotInstructions) {
        throw "Required file 'copilot-instructions.md' not found in: $codingGuidelinesDir"
    }
    if ($guidelineMdFiles.Count -eq 0) {
        throw "No guideline .md files found in: $codingGuidelinesDir (at least one .md file other than copilot-instructions.md is required)"
    }

    # Check for .code-workspace file
    $workspaceFile = Get-ChildItem -LiteralPath $repo -Filter '*.code-workspace' -File | Select-Object -First 1
    $targetBase = $repo

    if ($null -ne $workspaceFile) {
        Write-Verbose "Found workspace file: $($workspaceFile.Name)"
        try {
            $workspaceConfig = Get-Content -LiteralPath $workspaceFile.FullName -Raw | ConvertFrom-Json

            # Find first folder with app.json
            $appJsonFolder = $null
            foreach ($folder in $workspaceConfig.folders) {
                $folderPath = Join-Path $repo $folder.path
                $appJsonPath = Join-Path $folderPath 'app.json'

                if (Test-Path -LiteralPath $appJsonPath -PathType Leaf) {
                    $appJsonFolder = $folderPath
                    Write-Verbose "Found app.json in workspace folder: $folderPath"
                    break
                }
            }

            if ($null -ne $appJsonFolder) {
                $targetBase = (Resolve-Path -LiteralPath $appJsonFolder).Path
                Write-Host "Using workspace folder with app.json: $targetBase"
            } else {
                Write-Verbose "No app.json found in workspace folders, using repo root"
            }
        } catch {
            Write-Warning "Failed to parse workspace file, using repo root: $($_.Exception.Message)"
        }
    }

    # Fallback: if targetBase is still repo root (no workspace file, or workspace
    # file did not resolve to an app.json folder), scan for app.json in repo root
    # and immediate subdirectories
    if ($targetBase -eq $repo) {
        $appJsonInRoot = Join-Path $repo 'app.json'
        if (Test-Path -LiteralPath $appJsonInRoot -PathType Leaf) {
            Write-Verbose "app.json found in repo root, keeping targetBase as: $repo"
        } else {
            $appJsonSubDir = Get-ChildItem -LiteralPath $repo -Directory |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'app.json') -PathType Leaf } |
                Select-Object -First 1
            if ($null -ne $appJsonSubDir) {
                $targetBase = $appJsonSubDir.FullName
                Write-Host "Found app.json in subfolder: $targetBase"
            }
        }
    }

    # Create docs/GUIDELINES/ folder
    $docsFolder = Join-Path $targetBase $RepoGuidelinesRelPath
    $guidelinesFolder = Join-Path $docsFolder 'GUIDELINES'
    New-Item -ItemType Directory -Path $guidelinesFolder -Force | Out-Null

    # Clean up old guideline files before creating new links
    $existingGuidelineFiles = Get-ChildItem -LiteralPath $guidelinesFolder -Filter '*.md' -File -ErrorAction SilentlyContinue
    foreach ($oldFile in $existingGuidelineFiles) {
        Remove-Item -LiteralPath $oldFile.FullName -Force -ErrorAction SilentlyContinue
    }

    $docsFolder = $guidelinesFolder

    $linkKind = $null
    $linkedFiles = @()

    # Link all guideline .md files to docs/GUIDELINES/
    foreach ($mdFile in $guidelineMdFiles) {
        $centralFile = $mdFile.FullName
        $linkedFile = Join-Path $docsFolder $mdFile.Name

        if (Test-Path -LiteralPath $linkedFile) {
            Remove-Item -LiteralPath $linkedFile -Force
        }

        try {
            New-Item -ItemType HardLink -Path $linkedFile -Target $centralFile -ErrorAction Stop | Out-Null
            $linkKind = 'HardLink'
        } catch {
            New-Item -ItemType SymbolicLink -Path $linkedFile -Target $centralFile -ErrorAction Stop | Out-Null
            $linkKind = 'SymbolicLink'
        }

        $linkedFiles += [pscustomobject]@{
            CentralPath = $centralFile
            LinkedPath  = $linkedFile
            Name        = $mdFile.Name
        }
    }

    # Link copilot-instructions.md to Copilot_Instructions/ folder
    $copilotFolder = Join-Path $targetBase 'Copilot_Instructions'
    New-Item -ItemType Directory -Path $copilotFolder -Force | Out-Null

    # Clean up old copilot-instructions.md if it exists in wrong location
    $oldInstructionsPath = Join-Path $targetBase 'copilot-instructions.md'
    if (Test-Path -LiteralPath $oldInstructionsPath) {
        Remove-Item -LiteralPath $oldInstructionsPath -Force -ErrorAction SilentlyContinue
    }

    $instructions = Join-Path $copilotFolder 'copilot-instructions.md'
    $centralInstructionsPath = $copilotInstructions.FullName

    if (Test-Path -LiteralPath $instructions) {
        Remove-Item -LiteralPath $instructions -Force
    }

    try {
        New-Item -ItemType HardLink -Path $instructions -Target $centralInstructionsPath -ErrorAction Stop | Out-Null
    } catch {
        New-Item -ItemType SymbolicLink -Path $instructions -Target $centralInstructionsPath -ErrorAction Stop | Out-Null
    }

    # Link PS Scripts - mirror central subfolder structure into PS_Scripts/
    $psScriptsLinkedFiles = @()
    $psScriptsOutFolders = @()
    if ($psScriptSubDirs.Count -gt 0) {
        $psScriptsFolder = Join-Path $targetBase 'PS_Scripts'
        New-Item -ItemType Directory -Path $psScriptsFolder -Force | Out-Null

        # Clean up old flat files from previous module versions
        $existingPsFiles = Get-ChildItem -LiteralPath $psScriptsFolder -File -ErrorAction SilentlyContinue
        foreach ($oldFile in $existingPsFiles) {
            Remove-Item -LiteralPath $oldFile.FullName -Force -ErrorAction SilentlyContinue
        }

        foreach ($subDir in $psScriptSubDirs) {
            $scriptSubFolder = Join-Path $psScriptsFolder $subDir.Name
            New-Item -ItemType Directory -Path $scriptSubFolder -Force | Out-Null

            # Link all files in this subfolder
            $centralFiles = @(Get-ChildItem -LiteralPath $subDir.FullName -File)
            foreach ($psFile in $centralFiles) {
                $centralFile = $psFile.FullName
                $linkedFile = Join-Path $scriptSubFolder $psFile.Name

                if (Test-Path -LiteralPath $linkedFile) {
                    Remove-Item -LiteralPath $linkedFile -Force
                }

                try {
                    New-Item -ItemType HardLink -Path $linkedFile -Target $centralFile -ErrorAction Stop | Out-Null
                    $linkKind = 'HardLink'
                } catch {
                    New-Item -ItemType SymbolicLink -Path $linkedFile -Target $centralFile -ErrorAction Stop | Out-Null
                    $linkKind = 'SymbolicLink'
                }

                $psScriptsLinkedFiles += [pscustomobject]@{
                    CentralPath = $centralFile
                    LinkedPath  = $linkedFile
                    Name        = $psFile.Name
                }
            }

            # Detect if any script produces output files -> create out/
            $ps1Files = @($centralFiles | Where-Object { $_.Extension -eq '.ps1' })
            foreach ($ps1File in $ps1Files) {
                $scriptContent = Get-Content -LiteralPath $ps1File.FullName -Raw
                if ($scriptContent -match '\$[Oo]ut(File|Dir|put)|\bOut-File\b') {
                    $outFolder = Join-Path $scriptSubFolder 'out'
                    New-Item -ItemType Directory -Path $outFolder -Force | Out-Null
                    $psScriptsOutFolders += $outFolder
                    break
                }
            }
        }
        Write-Host "Linked $($psScriptsLinkedFiles.Count) PS Script file(s) to: $psScriptsFolder (mirroring $($psScriptSubDirs.Count) subfolders)"
    }

    # Update .git/info/exclude
    $excludeFile = Join-Path $repo '.git\info\exclude'
    if (-not (Test-Path -LiteralPath $excludeFile)) {
        throw "Not a git repo (missing $excludeFile)"
    }

    $excludeLines = @()
    if (Test-Path -LiteralPath $excludeFile) {
        $excludeLines = Get-Content -LiteralPath $excludeFile -ErrorAction SilentlyContinue
    }

    # Build list of files to exclude (relative to repo root)
    $toEnsure = @('# Local-only files (do not commit)')

    # Add copilot-instructions.md path relative to repo
    $instructionsRelPath = $instructions.Substring($repo.Length + 1) -replace '\\', '/'
    $toEnsure += $instructionsRelPath

    foreach ($linked in $linkedFiles) {
        $relPath = $linked.LinkedPath.Substring($repo.Length + 1) -replace '\\', '/'
        $toEnsure += $relPath
    }

    foreach ($linked in $psScriptsLinkedFiles) {
        $relPath = $linked.LinkedPath.Substring($repo.Length + 1) -replace '\\', '/'
        $toEnsure += $relPath
    }

    # Exclude out/ folders for scripts that produce output
    foreach ($outFolder in $psScriptsOutFolders) {
        $relPath = ($outFolder.Substring($repo.Length + 1) -replace '\\', '/') + '/'
        $toEnsure += $relPath
    }

    foreach ($line in $toEnsure) {
        if (-not ($excludeLines -contains $line)) {
            Add-Content -LiteralPath $excludeFile -Value $line
        }
    }

    # Mark as skip-worktree if tracked
    Push-Location -LiteralPath $repo
    try {
        # Handle copilot-instructions.md
        $instructionsRelPath = $instructions.Substring($repo.Length + 1) -replace '\\', '/'
        try {
            $null = git ls-files --error-unmatch $instructionsRelPath 2>&1
            if ($LASTEXITCODE -eq 0) {
                git update-index --skip-worktree $instructionsRelPath 2>&1 | Out-Null
            }
        } catch {
            # File not tracked, skip
        }

        # Handle guideline files
        foreach ($linked in $linkedFiles) {
            $relPath = $linked.LinkedPath.Substring($repo.Length + 1) -replace '\\', '/'
            try {
                $null = git ls-files --error-unmatch $relPath 2>&1
                if ($LASTEXITCODE -eq 0) {
                    git update-index --skip-worktree $relPath 2>&1 | Out-Null
                }
            } catch {
                # File not tracked, skip
            }
        }

        # Handle PS Script files
        foreach ($linked in $psScriptsLinkedFiles) {
            $relPath = $linked.LinkedPath.Substring($repo.Length + 1) -replace '\\', '/'
            try {
                $null = git ls-files --error-unmatch $relPath 2>&1
                if ($LASTEXITCODE -eq 0) {
                    git update-index --skip-worktree $relPath 2>&1 | Out-Null
                }
            } catch {
                # File not tracked, skip
            }
        }

        # Save config and install post-checkout hook so links survive branch switches
        $configFile = Join-Path $repo '.git\alfilelinker.json'
        $config = @{
            CentralFileLinkFolder = $centralDir
            RepoGuidelinesRelPath = $RepoGuidelinesRelPath
        } | ConvertTo-Json
        Set-Content -LiteralPath $configFile -Value $config -Encoding UTF8

        $hookFile = Join-Path $repo '.git\hooks\post-checkout'
        $hookDir = Split-Path $hookFile -Parent
        if (-not (Test-Path -LiteralPath $hookDir)) {
            New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
        }

        # Only install hook if not already present (don't overwrite user hooks)
        $installHook = $true
        if (Test-Path -LiteralPath $hookFile) {
            $existingHook = Get-Content -LiteralPath $hookFile -Raw -ErrorAction SilentlyContinue
            if ($existingHook -and $existingHook -notmatch 'ALFileLinker') {
                Write-Warning "A post-checkout hook already exists and was not created by ALFileLinker. Skipping hook installation."
                $installHook = $false
            }
        }

        if ($installHook) {
            $hookContent = @'
#!/bin/sh
# ALFileLinker post-checkout hook - re-creates hardlinks after branch switch
# $1 = previous HEAD, $2 = new HEAD, $3 = 1 if branch checkout (0 if file checkout)
if [ "$3" = "1" ]; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
        Import-Module ALFileLinker -ErrorAction SilentlyContinue
        $repo = (git rev-parse --show-toplevel) -replace "/", "\"
        $cfgPath = Join-Path $repo ".git\alfilelinker.json"
        if (Test-Path -LiteralPath $cfgPath) {
            $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
            Set-ALFileLinks -RepoPath $repo -CentralFileLinkFolder $cfg.CentralFileLinkFolder -RepoGuidelinesRelPath $cfg.RepoGuidelinesRelPath
            Write-Host "[ALFileLinker] File links restored after branch switch."
        }
    '
fi
'@
            # Write with LF line endings and no BOM so the #!/bin/sh shebang works on Windows
            $hookContent = $hookContent -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText($hookFile, $hookContent, [System.Text.UTF8Encoding]::new($false))
            Write-Host "Installed post-checkout hook: $hookFile"
        }

        [pscustomobject]@{
            RepoPath         = $repo
            TargetBase       = $targetBase
            LinkType         = $linkKind
            GuidelineFiles   = ($linkedFiles.Name -join ', ')
            GuidelineCount   = $linkedFiles.Count
            PSScriptFiles    = ($psScriptsLinkedFiles.Name -join ', ')
            PSScriptCount    = $psScriptsLinkedFiles.Count
            CentralFolder    = $centralDir
            GitStatus        = (git status --porcelain)
        }
    }
    finally {
        Pop-Location
    }
}

function Set-ALFileLinksForRepos {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [string]$CentralFileLinkFolder,

        [string]$RepoGuidelinesRelPath = 'docs',

        [string]$RepoNameLike = '*',

        [switch]$RequireAppJson,

        [ValidateRange(-1, 1000)]
        [int]$Levels = 2
    )

    $CentralFileLinkFolder = Resolve-ALFileLinkerDefault -Value $CentralFileLinkFolder -ConfigKey 'CentralFileLinkFolder' -ParameterName 'CentralFileLinkFolder'

    $root = (Resolve-Path -LiteralPath $RootPath).Path
    $centralDir = (Resolve-Path -LiteralPath $CentralFileLinkFolder).Path

    $excludeDirNames = @('.git', '.vs', '.vscode', 'node_modules', 'bin', 'obj', '.alpackages', '.idea', '.history')

    $queue = New-Object 'System.Collections.Generic.Queue[object]'
    $queue.Enqueue(@($root, 0))

    $repos = New-Object 'System.Collections.Generic.List[string]'

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        $current = [string]$item[0]
        $depth = [int]$item[1]

        if ((Split-Path -Leaf $current) -like $RepoNameLike) {
            if (Test-Path -LiteralPath (Join-Path $current '.git')) {
                if (-not $RequireAppJson -or (Test-Path -LiteralPath (Join-Path $current 'app.json') -PathType Leaf)) {
                    $repos.Add($current) | Out-Null
                }
            }
        }

        if (($Levels -ge 0) -and ($depth -ge $Levels)) {
            continue
        }

        $children = Get-ChildItem -LiteralPath $current -Directory -Force -ErrorAction SilentlyContinue
        foreach ($child in $children) {
            if ($excludeDirNames -contains $child.Name) { continue }
            $queue.Enqueue(@($child.FullName, ($depth + 1)))
        }
    }

    $repos = @($repos | Sort-Object -Unique)
    $total = $repos.Count
    if ($total -eq 0) {
        return @()
    }
    $i = 0

    $results = foreach ($repo in $repos) {
        $i++
        Write-Progress -Activity 'Linking AL coding guidelines' -Status "$i / $total : $repo" -PercentComplete ([int](($i / [double]$total) * 100))

        $action = "Link all guideline .md files and PS scripts from central folder and configure local ignore"
        if (-not $PSCmdlet.ShouldProcess($repo, $action)) {
            [pscustomobject]@{
                RepoPath  = $repo
                Skipped   = $true
                LinkType  = $null
            }
            continue
        }

        Write-Host "[$i/$total] Linking in: $repo"

        try {
            Set-ALFileLinks `
                -RepoPath $repo `
                -CentralFileLinkFolder $centralDir `
                -RepoGuidelinesRelPath $RepoGuidelinesRelPath
        } catch {
            [pscustomobject]@{
                RepoPath       = $repo
                LinkType       = $null
                GuidelineCount = 0
                Error          = $_.Exception.Message
            }
        }
    }

    Write-Progress -Activity 'Linking AL coding guidelines' -Completed
    $results
}

function Clone-RepoWithFileLinks {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$RepoUrl,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ -eq [System.IO.Path]::GetFileName($_) })]
        [string]$RepoDestinationSubFolder,

        [string]$RepoDestinationParentFolder,

        [string]$CentralFileLinkFolder,

        [string]$RepoFolderName,

        [string]$RepoGuidelinesRelPath = 'docs',

        [string]$Branch,

        [switch]$OpenInVSCode
    )

    $RepoDestinationParentFolder = Resolve-ALFileLinkerDefault -Value $RepoDestinationParentFolder -ConfigKey 'RepoDestinationParentFolder' -ParameterName 'RepoDestinationParentFolder'
    $CentralFileLinkFolder = Resolve-ALFileLinkerDefault -Value $CentralFileLinkFolder -ConfigKey 'CentralFileLinkFolder' -ParameterName 'CentralFileLinkFolder'

    $destParent = (Resolve-Path -LiteralPath $RepoDestinationParentFolder).Path
    $destSubFolder = Join-Path $destParent $RepoDestinationSubFolder

    if (-not (Test-Path -LiteralPath $destSubFolder -PathType Container)) {
        New-Item -ItemType Directory -Path $destSubFolder -Force | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($RepoFolderName)) {
        $name = ($RepoUrl.TrimEnd('/') -split '/')[(-1)]
        if ($name.EndsWith('.git')) {
            $name = $name.Substring(0, $name.Length - 4)
        }
        $RepoFolderName = $name
    }

    $dest = Join-Path $destSubFolder $RepoFolderName
    if (Test-Path -LiteralPath $dest) {
        throw "Destination already exists: $dest"
    }

    $cloneArgs = @('clone')
    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
        $cloneArgs += @('--branch', $Branch)
    }
    $cloneArgs += @($RepoUrl, $dest)

    if (-not $PSCmdlet.ShouldProcess($dest, "git $($cloneArgs -join ' ')") ) {
        return
    }

    try {
        $null = & git @cloneArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "git clone failed with exit code $LASTEXITCODE"
        }
    } catch {
        throw "git clone failed: $($_.Exception.Message)"
    }

    $result = Set-ALFileLinks -RepoPath $dest -CentralFileLinkFolder $CentralFileLinkFolder -RepoGuidelinesRelPath $RepoGuidelinesRelPath

    if ($OpenInVSCode) {
        $codeCmd = Get-Command -Name 'code' -ErrorAction SilentlyContinue
        if ($null -eq $codeCmd) {
            Write-Warning "VS Code CLI 'code' not found on PATH. Skipping open."
        } else {
            & $codeCmd.Source $dest
        }
    }

    $result
}

Export-ModuleMember -Function Set-ALFileLinks, Set-ALFileLinksForRepos, Clone-RepoWithFileLinks, Set-ALFileLinkerDefaults, Get-ALFileLinkerDefaults
