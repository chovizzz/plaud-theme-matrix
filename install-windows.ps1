# Install every skill in the PLAUD Shopify Theme matrix to global agent skills directories.
# Windows PowerShell — run from the package root.
#
# Legacy retirement: this matrix REPLACES the single skill 'plaud-shopify-theme'.
# Installers only add and overwrite, never delete, so a superseded skill left in
# a client's skills dir keeps being routed to and competes with this matrix.
# -RetireLegacy archives it, verifies the archive, and only then removes it.
# Without that switch nothing is deleted.

param(
    [string]$Target = "",
    [string]$Clients = "",
    [switch]$AllKnown,
    [string]$CreateMissing = "",
    [switch]$IncludeWorkspace,
    [switch]$RetireLegacy,
    [switch]$KeepLegacy,
    [string]$BackupDir = "",
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$PackageName = "plaud-shopify-theme-matrix"
$PackageVersion = "v0.2.1"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Skills this matrix supersedes.
$LegacySkills = @("plaud-shopify-theme")
$ClientNames = @("cursor", "claude", "codex", "agents")

function Show-Usage {
    @"
$PackageName $PackageVersion installer (Windows PowerShell)

Usage: .\install-windows.ps1 [OPTIONS]

Installs every root-level directory containing SKILL.md as an individual skill
into `$HOME\.<client>\skills\<skill-name>\. With no options, all four clients
are used: cursor, claude, codex, agents.

Replacement is total, not a merge: an existing skill directory with the same
name is removed before the new content is copied, so no stale files survive
inside a skill. The installer never deletes skills it did not install — except
via the explicit -RetireLegacy switch described below.

Options:
  -Target DIR          Install only to DIR. DIR must be a skills directory:
                       its last path component has to be exactly "skills".
  -Clients LIST        Comma-separated subset: cursor,claude,codex,agents
                       (NOT recommended — narrowing this is how client drift
                       happens: two clients on one spec, two on another)
  -CreateMissing LIST  Create the skills dir for the listed clients.
                       Without this, a client whose skills dir does not exist
                       is SILENTLY SKIPPED (it is reported at the end).
  -AllKnown            Install to all known client dirs, creating missing ones
                       (prompts unless -Yes)
  -IncludeWorkspace    Also search upward for .cursor\skills or .claude\skills
  -RetireLegacy        Archive and REMOVE superseded legacy skills
                       ($($LegacySkills -join ', ')) from every install target,
                       then install. Destructive, but the archive is verified
                       before anything is deleted.
  -KeepLegacy          Knowingly install ALONGSIDE the old skill. Dual-spec,
                       routing is ambiguous, result is UNSUPPORTED. Prints a
                       loud warning and exits with status 3.
  -BackupDir DIR       Base directory for -RetireLegacy archives. A unique
                       subdirectory is always appended. Default base is the
                       target skills dir, giving
                       <skills-dir>\.plaud-legacy-backup-<timestamp>\
  -DryRun              Print every action without touching install targets,
                       backup locations, or any skill.
  -Yes                 Skip confirmation prompts
  -Help                Show this help

Legacy retirement is a PRECONDITION, not an option:
  This matrix replaces the single skill 'plaud-shopify-theme'. If both are
  installed, the same Plaud theme task matches two different specs and routing
  becomes ambiguous - the exact problem the matrix exists to remove.

  So this installer FAILS CLOSED. If any target still has the old skill:

    - interactive console : you are asked whether to retire it and continue;
                            declining aborts with status 2, nothing installed
    - non-interactive/-Yes: aborts with status 2 unless -RetireLegacy is also
                            given; nothing installed, nothing deleted
    - -RetireLegacy       : archive -> verify -> remove, then install. If any
                            legacy path survives, the install still aborts
    - -KeepLegacy         : installs anyway and exits 3 (UNSUPPORTED)

  A legacy path that is a link/junction is never followed or deleted. It
  blocks the install and must be removed by hand.

Exit codes:
  0  success
  1  usage / configuration error
  2  aborted: legacy skill present and not retired
  3  installed with -KeepLegacy (dual-spec, unsupported)

Examples:
  .\install-windows.ps1
  .\install-windows.ps1 -DryRun
  .\install-windows.ps1 -RetireLegacy -Yes
  .\install-windows.ps1 -KeepLegacy
  .\install-windows.ps1 -CreateMissing cursor,claude,codex,agents
"@ | Write-Host
}

if ($Help) { Show-Usage; exit 0 }

$HomeDir = if ($HOME) { $HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { "" }
if (-not $HomeDir -and -not $Target) {
    Write-Error "Cannot determine home directory. Set `$HOME or USERPROFILE, or pass -Target explicitly."
}

# Built only when a home directory is known. In -Target mode with no home,
# nothing here is needed.
$ClientPaths = [ordered]@{}
if ($HomeDir) {
    $ClientPaths["cursor"] = Join-Path $HomeDir ".cursor\skills"
    $ClientPaths["claude"] = Join-Path $HomeDir ".claude\skills"
    $ClientPaths["codex"]  = Join-Path $HomeDir ".codex\skills"
    $ClientPaths["agents"] = Join-Path $HomeDir ".agents\skills"
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$script:SkippedClients = [System.Collections.Generic.List[string]]::new()

function Resolve-InstallPath($Path) {
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($expanded)
}

# One validator used by BOTH install and legacy retirement. Every path this
# script creates into, copies into, or deletes from must pass it. "Contains the
# substring skills" is not good enough: the last component must be exactly
# `skills`.
function Test-PathIsRootish($Path) {
    if (-not $Path) { return $true }
    # "C:\" trims to "C:", and "\\server\share" has no meaningful parent.
    if ($Path -match '^[A-Za-z]:$') { return $true }
    if ($Path -eq '\' -or $Path -eq '/') { return $true }
    # UNC share root: \\server\share has no meaningful parent either.
    if ($Path -match '^\\\\[^\\]+\\[^\\]+$') { return $true }
    return $false
}

function Test-SkillsDir($Path) {
    if (-not $Path) { return "empty path" }
    $d = $Path.TrimEnd('\', '/')
    if (Test-PathIsRootish $d) { return "refusing the filesystem root: $Path" }
    $leaf = Split-Path $d -Leaf
    if ($leaf -ne "skills") { return "last path component must be exactly 'skills': $d" }
    $parent = Split-Path $d -Parent
    if (-not $parent -or $parent -eq $d) { return "cannot resolve parent of: $d" }
    if ($HomeDir -and ($d -eq $HomeDir.TrimEnd('\', '/'))) { return "refusing home directory: $d" }
    if ($d -eq $ScriptDir.TrimEnd('\', '/')) { return "refusing the package root itself: $d" }
    # Lexical checks are not enough: a junction/symlink on the skills dir or any
    # ancestor would let a delete escape into a different tree.
    $walk = $d
    while ($walk) {
        if (Test-Path -LiteralPath $walk) {
            $item = Get-Item -LiteralPath $walk -Force -ErrorAction SilentlyContinue
            if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                return "path traverses a link/junction at '$walk': $d"
            }
        }
        $up = Split-Path $walk -Parent
        if (-not $up -or $up -eq $walk) { break }
        $walk = $up
    }
    return $null   # valid
}

function Get-SkillSources {
    # Get-ChildItem without -Force skips hidden directories, and dot-prefixed
    # names are filtered explicitly, so a .plaud-legacy-backup-* folder can
    # never be picked up as a skill source.
    $sources = Get-ChildItem -LiteralPath $ScriptDir -Directory | Where-Object {
        ($_.Name -notlike ".*") -and (Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md"))
    }
    if (-not $sources -or @($sources).Count -eq 0) {
        Write-Error "No root-level skill directories found in $ScriptDir"
    }
    return @($sources)
}

function Get-InstallTargets {
    $found = [System.Collections.Generic.List[string]]::new()

    function Add-Target($Candidate) {
        $t = $Candidate.TrimEnd('\', '/')
        $why = Test-SkillsDir $t
        if ($why) {
            Write-Host "Refusing unsafe install target: $why"
            return $false
        }
        if (-not $found.Contains($t)) { $found.Add($t) }
        return $true
    }

    if ($Target) {
        $t = (Resolve-InstallPath $Target).TrimEnd('\', '/')
        # Accept "<client-root>" only when "<client-root>\skills" exists.
        if ((Split-Path $t -Leaf) -ne "skills") {
            $nested = Join-Path $t "skills"
            if (Test-Path -LiteralPath $nested) { $t = $nested }
        }
        if (-not (Add-Target $t)) {
            Write-Error "-Target rejected. Pass a directory whose last component is 'skills'."
        }
        return @($found)
    }

    $clientList = if ($Clients) {
        $Clients -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } else {
        $ClientNames
    }

    $createList = $CreateMissing -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    foreach ($c in $clientList) {
        $path = $ClientPaths[$c]
        if (-not $path) {
            Write-Warning "Unknown client: $c"
            continue
        }
        if (Test-Path -LiteralPath $path) {
            [void](Add-Target $path)
        } elseif ($AllKnown -or ($createList -contains $c)) {
            if ($AllKnown -and -not $Yes -and -not $DryRun) {
                if (-not (Read-YesNo "Create $path? [y/N]")) { continue }
            }
            if (Add-Target $path) {
                if ($DryRun) {
                    Write-Host "  [dry-run] New-Item -ItemType Directory -Force -Path `"$path`""
                } else {
                    New-Item -ItemType Directory -Force -Path $path | Out-Null
                }
            }
        } else {
            $script:SkippedClients.Add("$c|$path")
        }
    }

    if ($IncludeWorkspace) {
        $dir = $ScriptDir
        for ($i = 0; $i -lt 5; $i++) {
            foreach ($sub in @(".cursor\skills", ".claude\skills")) {
                $p = Join-Path $dir $sub
                if (Test-Path -LiteralPath $p) { [void](Add-Target $p) }
            }
            $parent = Split-Path $dir -Parent
            if (-not $parent -or $parent -eq $dir) { break }
            $dir = $parent
        }
    }

    return @($found)
}

# Returns a hashtable with two lists:
#   Dirs  - real directories; can be archived and retired automatically
#   Links - reparse points; BLOCK the install but are never followed or deleted
function Get-LegacyInstalls($Targets) {
    $dirs = [System.Collections.Generic.List[string]]::new()
    $links = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $Targets) {
        if (-not (Test-Path -LiteralPath $t)) { continue }
        # Enumerate by name: Test-Path resolves the target, so a dangling
        # symlink/junction would report $false and slip past the gate, only to
        # resurface as a second spec once its target comes back.
        $present = @(Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue)
        foreach ($legacy in $LegacySkills) {
            $entry = $present | Where-Object { $_.Name -eq $legacy } | Select-Object -First 1
            if (-not $entry) { continue }
            $p = Join-Path $t $legacy
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $links.Add($p)
            } elseif ($entry.PSIsContainer) {
                $dirs.Add($p)
            } else {
                # A file where a skill dir is expected: still ambiguous, block.
                $links.Add($p)
            }
        }
    }
    return @{ Dirs = @($dirs); Links = @($links); All = @($dirs) + @($links) }
}

function Test-BackupDir($LegacyPaths) {
    if (-not $BackupDir) { return }
    $base = (Resolve-InstallPath $BackupDir).TrimEnd('\', '/')
    if (Test-PathIsRootish $base) { Write-Error "-BackupDir must not be the filesystem root: $BackupDir" }
    if ($HomeDir -and ($base -eq $HomeDir.TrimEnd('\', '/'))) { Write-Error "-BackupDir must not be the home directory itself" }
    foreach ($p in $LegacyPaths) {
        # Windows paths are case-insensitive; compare that way.
        if ($base -ieq $p -or $base.StartsWith("$p\", [StringComparison]::OrdinalIgnoreCase)) {
            Write-Error "-BackupDir must not live inside the skill being retired: $p"
        }
    }
}

# A unique timestamped subdirectory is ALWAYS appended, even under -BackupDir,
# so two targets can never collide on one destination.
function Get-BackupRoot($LegacyPath) {
    $parent = Split-Path $LegacyPath -Parent
    if ($BackupDir) {
        $base = (Resolve-InstallPath $BackupDir).TrimEnd('\', '/')
        $clientTag = Split-Path (Split-Path $parent -Parent) -Leaf
        return (Join-Path (Join-Path $base ".plaud-legacy-backup-$Timestamp") $clientTag)
    }
    # Hidden-by-convention directory: skipped by this installer's source scan.
    return (Join-Path $parent ".plaud-legacy-backup-$Timestamp")
}

function Show-LegacyWarning($Legacy) {
    if ($Legacy.All.Count -eq 0) { return }

    Write-Host ""
    Write-Host "################################################################"
    Write-Host "#  BLOCKING: superseded legacy skill(s) detected                #"
    Write-Host "################################################################"
    Write-Host ""
    Write-Host "This matrix REPLACES the single skill 'plaud-shopify-theme'."
    Write-Host "Found $($Legacy.All.Count) legacy install(s):"
    $Legacy.Dirs  | ForEach-Object { Write-Host "  - $_" }
    $Legacy.Links | ForEach-Object { Write-Host "  - $_   (link/junction)" }
    Write-Host ""
    Write-Host "Installing the matrix alongside them produces ROUTING COMPETITION: the"
    Write-Host "same Plaud theme task matches both the old single skill and this matrix,"
    Write-Host "so two different specs run against one project. That is exactly what"
    Write-Host "splitting the matrix was meant to eliminate, so this installer will NOT"
    Write-Host "install into a client that still has the old skill."
    Write-Host ""
}

function Show-LegacyRemedies($Legacy) {
    $n = 1
    Write-Host "How to proceed:"
    Write-Host ""
    if ($Legacy.Dirs.Count -gt 0) {
        Write-Host "  $n. Retire them (archive -> verify -> remove), then install:"
        Write-Host "         .\install-windows.ps1 -RetireLegacy -Yes"
        Write-Host ""
        $n++
    }
    if ($Legacy.Links.Count -gt 0) {
        Write-Host "  $n. The link(s) below CANNOT be retired automatically - this script"
        Write-Host "     never follows or deletes a link/junction. Remove them by hand:"
        foreach ($p in $Legacy.Links) {
            Write-Host "         Remove-Item -LiteralPath `"$p`" -Force"
        }
        Write-Host ""
        $n++
    }
    Write-Host "  $n. Knowingly keep the old skill and accept a dual-spec, unsupported"
    Write-Host "     environment (NOT recommended):"
    Write-Host "         .\install-windows.ps1 -KeepLegacy"
    Write-Host ""
}

function Test-ArchiveContents($ArchivePath, $SourcePath) {
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        try {
            $rootName = Split-Path $SourcePath -Leaf
            # Entries with a Name are files; directory entries have an empty Name.
            # Compress-Archive may or may not include the top-level folder in the
            # entry path depending on the PowerShell version, so normalise both.
            $entryPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            foreach ($e in $zip.Entries) {
                if (-not $e.Name) { continue }
                $rel = $e.FullName -replace '\\', '/'
                if ($rel.StartsWith("$rootName/", [StringComparison]::OrdinalIgnoreCase)) {
                    $rel = $rel.Substring($rootName.Length + 1)
                }
                [void]$entryPaths.Add($rel)
            }
            if (-not ($entryPaths | Where-Object { $_ -eq "SKILL.md" -or $_ -like "*/SKILL.md" })) {
                return "no SKILL.md in archive"
            }
            # Every file on disk must be present in the archive. A surplus of
            # archive entries must never mask a missing source file.
            $prefix = $SourcePath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            $missing = @()
            foreach ($f in Get-ChildItem -LiteralPath $SourcePath -Recurse -File -Force) {
                $rel = ($f.FullName.Substring($prefix.Length)) -replace '\\', '/'
                if (-not $entryPaths.Contains($rel)) { $missing += $rel }
            }
            if ($missing.Count -gt 0) {
                return "missing from archive: $(($missing | Select-Object -First 5) -join ', ')"
            }
            return $null
        } finally {
            $zip.Dispose()
        }
    } catch {
        return "cannot read archive: $($_.Exception.Message)"
    }
}

function Invoke-LegacyRetirement($LegacyPaths) {
    if (@($LegacyPaths).Count -eq 0) { return }

    foreach ($p in $LegacyPaths) {
        $parent = Split-Path $p -Parent
        $name = Split-Path $p -Leaf

        # Re-assert every safety property immediately before the destructive step.
        $why = Test-SkillsDir $parent
        if ($why) {
            Write-Warning "SKIP $p - parent is not a validated skills dir ($why)"
            continue
        }
        if ($LegacySkills -notcontains $name) {
            Write-Warning "SKIP $p - name is not in the legacy allowlist"
            continue
        }

        $backupRoot = Get-BackupRoot $p
        $archive = Join-Path $backupRoot "$name.zip"

        Write-Host "  archive: $p  ->  $archive"
        if ($DryRun) {
            Write-Host "  [dry-run] New-Item -ItemType Directory -Force -Path `"$backupRoot`""
            Write-Host "  [dry-run] Compress-Archive -LiteralPath `"$p`" -DestinationPath `"$archive`""
            Write-Host "  [dry-run] verify archive contains SKILL.md and the full file count, then Remove-Item `"$p`""
            continue
        }

        if (Test-Path -LiteralPath $archive) {
            Write-Warning "SKIP $p - backup destination already exists: $archive"
            continue
        }
        New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
        try {
            Compress-Archive -LiteralPath $p -DestinationPath $archive
        } catch {
            Write-Warning "ARCHIVE FAILED for $p - left in place, nothing removed. $($_.Exception.Message)"
            continue
        }

        $problem = Test-ArchiveContents $archive $p
        if ($problem) {
            Write-Warning "BACKUP VERIFICATION FAILED for $p ($problem) - left in place, nothing removed."
            continue
        }

        # Final re-check, immediately before the only destructive call: the path
        # must still exist, still not be a link/junction, and its parent must
        # still validate. This closes the window between scan and delete.
        $legacyItem = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        if (-not $legacyItem) {
            Write-Warning "SKIP $p - disappeared after archiving; nothing removed."
            continue
        }
        if ($legacyItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Warning "SKIP $p - became a link/junction; nothing removed."
            continue
        }
        $whyNow = Test-SkillsDir (Split-Path $p -Parent)
        if ($whyNow) {
            Write-Warning "SKIP $p - parent no longer validates ($whyNow); nothing removed."
            continue
        }
        Remove-Item -LiteralPath $p -Recurse -Force
        Write-Host "  retired: $p  (restore: Expand-Archive -LiteralPath `"$archive`" -DestinationPath `"$parent`")"
    }
    Write-Host ""
}

# ------------------------------------------------------------- legacy gate

# Exit codes:
#   0  success
#   1  usage / configuration error
#   2  aborted: legacy skill present and not retired (fail closed)
#   3  installed with -KeepLegacy: dual-spec, UNSUPPORTED environment
$script:ExitUnsupported = $false

function Test-Interactive {
    if ([Environment]::UserInteractive -eq $false) { return $false }
    try { if ([Console]::IsInputRedirected) { return $false } } catch { return $false }
    # A host started with -NonInteractive still looks "user interactive" and has
    # a console, but Read-Host throws there. Detect the switch explicitly.
    try {
        foreach ($a in [Environment]::GetCommandLineArgs()) {
            if ($a -match '^-+NonI') { return $false }
        }
    } catch { }
    return $true
}

# Read-Host raises a terminating error in non-interactive hosts, and
# $ErrorActionPreference = 'Stop' would turn that into a bare exit 1 instead of
# the documented exit 2. Always treat a failed prompt as "no".
function Read-YesNo($Prompt) {
    try {
        $ans = Read-Host $Prompt
    } catch {
        Write-Host ""
        return $false
    }
    return ($ans -match '^[Yy]')
}

# Fail closed. Reaching the install loop with a legacy skill still on disk is
# only possible via the explicit -KeepLegacy escape hatch.
function Invoke-LegacyGate($Legacy, $Targets) {
    if ($Legacy.All.Count -eq 0) { return $Legacy }

    if ($KeepLegacy) {
        Write-Host "-KeepLegacy given: continuing anyway."
        Write-Host ""
        Write-Host "!!  This leaves the old single skill and the matrix installed side by"
        Write-Host "!!  side. Routing is now ambiguous and the result is UNSUPPORTED."
        Write-Host "!!  Fix it later with:  .\install-windows.ps1 -RetireLegacy -Yes"
        Write-Host ""
        $script:ExitUnsupported = $true
        return $Legacy
    }

    $doRetire = $RetireLegacy
    if ($doRetire -and -not $Yes -and -not $DryRun) {
        # Destructive confirmation. Non-interactive hosts cannot confirm, so
        # they must pass -Yes explicitly; otherwise fail closed.
        if (Test-Interactive) {
            if (-not (Read-YesNo "Archive and remove the $($Legacy.All.Count) legacy install(s) listed above? [y/N]")) {
                Write-Host ""
                Write-Host "ABORTED - nothing installed, nothing deleted."
                Write-Host ""
                Show-LegacyRemedies $Legacy
                exit 2
            }
        } else {
            Write-Host "ABORTED - nothing installed, nothing deleted."
            Write-Host "(non-interactive run: -RetireLegacy is destructive and must be"
            Write-Host " confirmed with -Yes)"
            Write-Host ""
            Show-LegacyRemedies $Legacy
            exit 2
        }
    }
    if (-not $doRetire) {
        if ((Test-Interactive) -and -not $Yes -and -not $DryRun) {
            if (Read-YesNo "Archive and retire the legacy skill(s) now, then install? [y/N]") {
                $doRetire = $true
            } else {
                Write-Host ""
                Write-Host "ABORTED - nothing installed, nothing deleted."
                Write-Host ""
                Show-LegacyRemedies $Legacy
                exit 2
            }
        } else {
            Write-Host "ABORTED - nothing installed, nothing deleted."
            if ($DryRun) {
                Write-Host "(dry run: a real run would abort here too, with exit code 2)"
            } else {
                Write-Host "(non-interactive run: retirement must be requested explicitly)"
            }
            Write-Host ""
            Show-LegacyRemedies $Legacy
            exit 2
        }
    }

    if ($DryRun) {
        Invoke-LegacyRetirement $Legacy.Dirs
        Write-Host "Dry run: the retirement above would run first, then the matrix would install."
        return $Legacy
    }

    Invoke-LegacyRetirement $Legacy.Dirs

    # Re-scan: anything that survived (verification failure, pre-existing
    # archive, link) still blocks. Never install over a survivor.
    $after = Get-LegacyInstalls $Targets
    if ($after.All.Count -gt 0) {
        Write-Host "ABORTED - legacy skill(s) still present after retirement; nothing installed."
        $after.All | ForEach-Object { Write-Host "  - $_" }
        Write-Host ""
        Show-LegacyRemedies $after
        exit 2
    }
    return $after
}

function Copy-SkillContents($SourceDir, $DestDir) {
    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    Get-ChildItem -LiteralPath $SourceDir -Force | Where-Object {
        $_.Name -ne "install.sh" -and
        $_.Name -ne "install.ps1" -and
        $_.Name -ne "install-macos-linux.sh" -and
        $_.Name -ne "install-windows.ps1"
    } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $DestDir -Recurse -Force
    }
}

function Install-OneSkill($Source, $SkillsDir) {
    $why = Test-SkillsDir $SkillsDir
    if ($why) {
        Write-Warning "Skip unsafe path ($why)"
        return $false
    }

    $skillName = Split-Path $Source.FullName -Leaf
    $dest = Join-Path $SkillsDir $skillName

    $srcResolved = (Resolve-Path -LiteralPath $Source.FullName -ErrorAction SilentlyContinue)
    if ($srcResolved -and (Test-Path -LiteralPath $dest) -and
        ((Resolve-Path -LiteralPath $dest -ErrorAction SilentlyContinue).Path -eq $srcResolved.Path)) {
        Write-Warning "Skip source directory: $dest"
        return $false
    }

    if ($DryRun) {
        if (Test-Path -LiteralPath $dest) {
            Write-Host "  [dry-run] replace $dest (remove then copy)"
        } else {
            Write-Host "  [dry-run] create  $dest"
        }
        return $true
    }

    New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
    if (Test-Path -LiteralPath $dest) {
        Write-Host "Overwriting existing install at $dest"
        Remove-Item -LiteralPath $dest -Recurse -Force
    }
    Copy-SkillContents $Source.FullName $dest

    if (Test-Path -LiteralPath (Join-Path $dest "SKILL.md")) {
        Write-Host "Installed $skillName to $dest"
        return $true
    }
    Write-Error "Install verification failed for $dest"
}

function Get-DeclaredVersion($SkillsDir) {
    $manifest = Join-Path $SkillsDir "plaud-theme-shared\references\version-manifest.md"
    $fallback = Join-Path $SkillsDir "plaud-theme-shared\SKILL.md"
    $file = if (Test-Path -LiteralPath $manifest) { $manifest }
            elseif (Test-Path -LiteralPath $fallback) { $fallback }
            else { $null }
    if (-not $file) { return "(not installed)" }
    $versions = Select-String -LiteralPath $file -Pattern 'v\d+\.\d+\.\d+' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | Select-Object -Unique
    if (-not $versions) { return "(no version string)" }
    return ($versions | Sort-Object { [version]($_.TrimStart('v')) } | Select-Object -Last 1)
}

function Show-VersionCheck($Targets) {
    Write-Host ""
    if ($Target) {
        Write-Host "Version check (declared version of plaud-theme-shared in the target):"
        foreach ($t in $Targets) {
            Write-Host ("  {0,-18} {1}" -f (Get-DeclaredVersion $t), $t)
        }
    } else {
        Write-Host "Version check (declared version of plaud-theme-shared per client):"
        foreach ($c in $ClientNames) {
            $path = $ClientPaths[$c]
            $v = if ($path -and (Test-Path -LiteralPath $path)) { Get-DeclaredVersion $path } else { "(skills dir absent)" }
            Write-Host ("  {0,-8} {1,-18} {2}" -f $c, $v, $path)
        }
    }
    Write-Host ""
    Write-Host "Expected for this package: $PackageVersion"
    Write-Host "A declared version is only a declaration. The real proof the copy"
    Write-Host "landed is a tree comparison of each plaud-theme-* directory against"
    Write-Host "the installed copy."
}

# --------------------------------------------------------------------- main

$sources = Get-SkillSources
$targets = Get-InstallTargets

if (-not $targets -or @($targets).Count -eq 0) {
    Write-Error "No install targets found. Use -Target or -CreateMissing cursor,claude,codex,agents"
}

Write-Host "$PackageName $PackageVersion"
if ($DryRun) { Write-Host "*** DRY RUN - install targets, backups and skills are left untouched ***" }
Write-Host ""
Write-Host "Skill sources ($(@($sources).Count)):"
$sources | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host ""
Write-Host "Install targets ($(@($targets).Count)):"
$targets | ForEach-Object { Write-Host "  - $_" }

if ($script:SkippedClients.Count -gt 0) {
    Write-Host ""
    Write-Host "SKIPPED - skills dir does not exist (pass -CreateMissing to create):"
    foreach ($line in $script:SkippedClients) {
        $parts = $line -split '\|', 2
        Write-Host "  - $($parts[0])  ->  $($parts[1])"
    }
    Write-Host ""
    Write-Host "These clients will NOT get the matrix. This is the main reason for"
    Write-Host "'I thought I installed it'."
}
Write-Host ""

$legacy = Get-LegacyInstalls $targets
Test-BackupDir $legacy.Dirs
Show-LegacyWarning $legacy
$legacy = Invoke-LegacyGate $legacy $targets

$ok = 0
foreach ($t in $targets) {
    foreach ($source in $sources) {
        if (Install-OneSkill $source $t) { $ok++ }
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry run complete. $ok skill copy/copies would be installed."
} else {
    Write-Host "Done. Installed $ok skill copy/copies from $PackageName $PackageVersion."
    Show-VersionCheck $targets
}

if ($script:ExitUnsupported) {
    Write-Host ""
    Write-Host "################################################################"
    Write-Host "#  UNSUPPORTED STATE - legacy skill kept alongside the matrix   #"
    Write-Host "################################################################"
    Write-Host "The old 'plaud-shopify-theme' is still installed. Two specs now"
    Write-Host "match the same task. Exiting with status 3 so callers and CI can"
    Write-Host "detect this. Resolve with: .\install-windows.ps1 -RetireLegacy -Yes"
    exit 3
}
