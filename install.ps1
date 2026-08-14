# PLAUD Shopify Theme Matrix — one-command installer (Windows PowerShell)
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -Ref v0.3.0
#
# `irm ... | iex` CANNOT pass parameters. Use the scriptblock form above.
#
# Truncation safety: PowerShell parses the entire script before executing any
# of it, so a half-downloaded file fails to parse and nothing runs. (The sh
# port gets the same property by keeping `main "$@"` on the last line.)
#
# Parameter names are deliberately the same as the sh port's long options:
#   -Ref / -Repo / -Clients / -CreateMissing / -Check / -DryRun
#
# !! VERIFICATION STATUS !!
# This file has NEVER been executed on Windows. It is a static port of
# install.sh, which IS fully exercised on macOS. Before trusting it on a real
# machine, run `-DryRun` first and then `-Check`. See README "已知限制".

[CmdletBinding()]
param(
  [string]$Ref = "",
  [string]$Repo = "https://github.com/chovizzz/plaud-theme-matrix",
  [string]$Tarball = "",   # .zip only on this port (Expand-Archive); the sh port takes .tar.gz
  [string]$Source = "",
  [string]$Clients = "",
  [string]$CreateMissing = "",
  [switch]$Check,
  [switch]$DryRun,
  [switch]$RetireLegacy,
  [switch]$KeepLegacy,
  [switch]$Yes,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$InstallerVersion = '1.0.0'
$PackageName      = 'plaud-theme-matrix'
$MarkerName       = '.plaud-installed-ref'
$InProgressName   = '.plaud-install-inprogress'
$SkillPrefix      = 'plaud-theme-'
$LegacySkills     = @('plaud-shopify-theme')
$ClientNames      = @('cursor', 'claude', 'codex', 'agents')

# NOTE (v0.3.0): this port itself is UNVERIFIED on Windows (see README's known
# limitations — it has never been executed there, not even parsed). Separately, and
# independently of that: the matrix's ChangeSet identity forensics (ObjectFormat /
# ThemeTreeOid / ChangeSetScopeFingerprint) are NOT supported on Windows at all. Git on
# Windows defaults to core.fileMode=false + core.autocrlf=true, which trips both
# byte-fidelity gates, so the forensic commands halt by design. Run them on macOS/Linux.

function Show-Usage {
  @"
$PackageName installer $InstallerVersion (Windows)

  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.ps1))) -Ref v0.3.0

NOTE: this port is UNVERIFIED on Windows — run -DryRun first, then -Check, before any
real install. Separately: v0.3.0 ChangeSet identity forensics are NOT supported on
Windows (Git for Windows defaults trip both byte-fidelity gates) — run those on
macOS/Linux.

Parameters (same names and meaning as the sh port's long options):
  -Ref TAG             Release tag (vMAJOR.MINOR.PATCH). Default: newest tag.
                       If that cannot be resolved the run FAILS; it never
                       silently falls back to a branch.
  -Repo URL            Repo to install from.
  -Tarball PATH|URL    Install from a prepared .ZIP (requires -Ref). This port
                       uses Expand-Archive, so .tar.gz is NOT accepted here;
                       the sh port takes .tar.gz and not .zip.
  -Source DIR          Install from a local checkout (provenance UNPROVEN).
  -Clients LIST        Comma-separated: cursor,claude,codex,agents.
  -CreateMissing LIST  Create absent skills dirs ('all' accepted).
  -Check               Verify what is installed instead of installing.
  -DryRun              Report every action, touch no install target.
  -RetireLegacy        Archive -> verify -> remove plaud-shopify-theme first.
  -KeepLegacy          Install alongside it. UNSUPPORTED. Exits 3.
  -Yes                 Assume yes for prompts.

Exit codes: 0 ok | 1 failure | 2 legacy blocked | 3 dual-spec | 4 check failed
"@ | Write-Host
}

if ($Help) { Show-Usage; exit 0 }

# --------------------------------------------------------------- plumbing

function Say  { param([string]$m) Write-Host $m }
function Warn { param([string]$m) Write-Host $m -ForegroundColor Yellow }
function Die  { param([string]$m) Write-Host "Error: $m" -ForegroundColor Red; exit 1 }

function Get-HomeDir {
  if ($env:USERPROFILE) { return $env:USERPROFILE }
  if ($env:HOME) { return $env:HOME }
  Die "neither USERPROFILE nor HOME is set; cannot locate any client skills directory."
}

# ------------------------------------------------------------ path safety

# A reparse point (symlink, junction, mount point) anywhere in the chain would
# let a delete escape into a different tree. The sh port rejects symlinked
# ancestors the same way; this is the Windows equivalent, and it is checked on
# EVERY ancestor, not just the leaf.
function Test-NoReparsePointInChain {
  param([string]$Path)
  $p = $Path
  while ($p -and $p -ne [IO.Path]::GetPathRoot($p)) {
    if (Test-Path -LiteralPath $p) {
      $item = Get-Item -LiteralPath $p -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        return "path traverses a reparse point (symlink/junction) at '$p': $Path"
      }
    }
    $parent = Split-Path -Parent $p
    if (-not $parent -or $parent -eq $p) { break }
    $p = $parent
  }
  return $null
}

# The last path component must be exactly 'skills'. "Contains the substring
# skills" is not good enough.
function Test-SkillsDir {
  param([string]$Dir)
  if ([string]::IsNullOrWhiteSpace($Dir)) { return "empty path" }
  $d = $Dir.TrimEnd('\', '/')
  if (-not $d) { return "refusing the filesystem root" }
  if (-not [IO.Path]::IsPathRooted($d)) { return "not an absolute path: $d" }
  if ($d -eq [IO.Path]::GetPathRoot($d).TrimEnd('\')) { return "refusing a drive root: $d" }
  if ((Split-Path -Leaf $d) -ne 'skills') { return "last path component must be exactly 'skills': $d" }
  $home_ = (Get-HomeDir).TrimEnd('\', '/')
  if ($d -eq $home_) { return "refusing the home directory: $d" }
  $rp = Test-NoReparsePointInChain -Path $d
  if ($rp) { return $rp }
  return $null
}

function Get-ClientPath {
  param([string]$Client)
  $h = Get-HomeDir
  switch ($Client) {
    'cursor' { return (Join-Path $h '.cursor\skills') }
    'claude' { return (Join-Path $h '.claude\skills') }
    'codex'  { return (Join-Path $h '.codex\skills') }
    'agents' { return (Join-Path $h '.agents\skills') }
    default  { return $null }
  }
}

# ------------------------------------------------------------ tree snapshot

# Canonical inventory of a tree: relative path + kind + (for files) SHA-256.
# Fails closed on reparse points and on anything unreadable — a permission
# error that hides part of the tree must NOT be able to produce a "matching"
# inventory. This is the Windows twin of snapshot_tree() in install.sh.
function Get-TreeInventory {
  param([string]$Root, [string]$Label, [switch]$WithHash)
  if (-not (Test-Path -LiteralPath $Root)) { Warn "FAILED: missing tree: $Label"; return $null }
  $entries = @()
  try {
    $items = Get-ChildItem -LiteralPath $Root -Recurse -Force -ErrorAction Stop
  } catch {
    Warn "FAILED: cannot inventory ${Label}: $($_.Exception.Message)"
    return $null
  }
  $rootFull = (Get-Item -LiteralPath $Root -Force).FullName.TrimEnd('\')
  foreach ($i in $items) {
    if ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) {
      Warn "FAILED: reparse point not allowed in a skill tree (${Label}): $($i.FullName)"
      return $null
    }
    $rel = $i.FullName.Substring($rootFull.Length + 1) -replace '\\', '/'
    if ($i.PSIsContainer) {
      $entries += "d $rel"
    } else {
      # The installer scripts themselves are never part of a skill.
      if ($rel -in @('install.sh', 'install.ps1', 'install-macos-linux.sh', 'install-windows.ps1')) { continue }
      if ($WithHash) {
        try { $h = (Get-FileHash -LiteralPath $i.FullName -Algorithm SHA256).Hash } catch {
          Warn "FAILED: cannot hash ${Label}/${rel}: $($_.Exception.Message)"; return $null
        }
        $entries += "f $rel $h"
      } else {
        $entries += "f $rel"
      }
    }
  }
  return ($entries | Sort-Object)
}

function Compare-Inventory {
  param($Expected, $Actual, [string]$What)
  $diff = Compare-Object -ReferenceObject @($Expected) -DifferenceObject @($Actual)
  if (-not $diff) { return $true }
  foreach ($d in $diff) {
    $side = if ($d.SideIndicator -eq '=>') { 'only in destination (STALE)' } else { 'missing from destination' }
    Warn ("          {0}: {1}" -f $side, $d.InputObject)
  }
  return $false
}

# ------------------------------------------------------------- acquisition

function Get-RepoSlug {
  param([string]$Url)
  $u = $Url.TrimEnd('/')
  if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
  $i = $u.IndexOf('github.com')
  if ($i -ge 0) { $u = $u.Substring($i + 'github.com'.Length).TrimStart('/', ':') }
  return $u
}

function Test-ValidRef {
  param([string]$R)
  return ($R -match '^v[0-9]+\.[0-9]+\.[0-9]+$')
}

# Largest vMAJOR.MINOR.PATCH. Numeric per segment: a lexical sort puts
# v0.10.0 before v0.2.0.
function Get-MaxSemverTag {
  param([string[]]$Tags)
  $best = $null; $bv = $null
  foreach ($t in $Tags) {
    if (-not (Test-ValidRef $t)) { continue }
    $v = [version]$t.Substring(1)
    if (-not $bv -or $v -gt $bv) { $bv = $v; $best = $t }
  }
  return $best
}

function Resolve-LatestTag {
  param([string]$RepoUrl)
  $slug = Get-RepoSlug $RepoUrl
  try {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$slug/releases/latest" -UseBasicParsing -TimeoutSec 30
    if ($rel.tag_name -and (Test-ValidRef $rel.tag_name)) { return $rel.tag_name }
  } catch { }
  try {
    $tags = Invoke-RestMethod -Uri "https://api.github.com/repos/$slug/tags?per_page=100" -UseBasicParsing -TimeoutSec 30
    return (Get-MaxSemverTag ($tags | ForEach-Object { $_.name }))
  } catch { }
  return $null
}

function Resolve-CommitSha {
  param([string]$RepoUrl, [string]$R)
  $slug = Get-RepoSlug $RepoUrl
  try {
    $c = Invoke-RestMethod -Uri "https://api.github.com/repos/$slug/commits/$R" -UseBasicParsing -TimeoutSec 30
    if ($c.sha) { return $c.sha }
  } catch { }
  return 'unknown(api-unreachable)'
}

# Windows gets the .zip endpoint, not .tar.gz: Expand-Archive is built in on
# every supported PowerShell, while tar.exe only exists on Windows 10 1803+.
# The archive contents are byte-identical either way.
function Get-PackageTree {
  param([string]$R, [string]$WorkDir)
  $dest = Join-Path $WorkDir "trees\$R"
  if (Test-Path -LiteralPath (Join-Path $dest 'root.txt')) {
    return (Get-Content -LiteralPath (Join-Path $dest 'root.txt') -Raw).Trim()
  }
  New-Item -ItemType Directory -Force -Path $dest | Out-Null

  if ($Source) {
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { Die "-Source is not a directory: $Source" }
    $root = (Get-Item -LiteralPath $Source -Force).FullName
    Set-Content -LiteralPath (Join-Path $dest 'root.txt') -Value $root
    return $root
  }

  $zip = Join-Path $dest 'pkg.zip'
  if ($Tarball) {
    if ($Tarball -match '^https?://') {
      Invoke-WebRequest -Uri $Tarball -OutFile $zip -UseBasicParsing
    } else {
      if (-not (Test-Path -LiteralPath $Tarball)) { Die "tarball not found: $Tarball" }
      Copy-Item -LiteralPath $Tarball -Destination $zip
    }
  } else {
    $slug = Get-RepoSlug $Repo
    $url = "https://codeload.github.com/$slug/zip/refs/tags/$R"
    Say "  fetching $url"
    try {
      Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    } catch {
      Die "download failed for ref $R : $($_.Exception.Message)`n       Check the tag exists: $Repo/tags"
    }
  }
  if (-not (Test-Path -LiteralPath $zip) -or (Get-Item -LiteralPath $zip).Length -eq 0) {
    Die "downloaded archive is empty (truncated transfer?)"
  }

  $out = Join-Path $dest 'tree'
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  try {
    Expand-Archive -LiteralPath $zip -DestinationPath $out -Force
  } catch {
    Die "extract failed (corrupt or truncated archive): $($_.Exception.Message)"
  }
  # The top-level directory is <repo>-<ref>. Never hard-coded; always discovered.
  $tops = @(Get-ChildItem -LiteralPath $out -Directory -Force)
  if ($tops.Count -ne 1) { Die "archive has $($tops.Count) top-level directories, expected exactly 1" }
  $root = $tops[0].FullName
  Set-Content -LiteralPath (Join-Path $dest 'root.txt') -Value $root
  return $root
}

function Get-SkillNames {
  param([string]$Root)
  return @(Get-ChildItem -LiteralPath $Root -Directory -Force |
    Where-Object { -not $_.Name.StartsWith('.') -and (Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')) } |
    ForEach-Object { $_.Name } | Sort-Object)
}

# ------------------------------------------------------------------ marker

function Read-Marker {
  param([string]$SkillsDir)
  $f = Join-Path $SkillsDir $MarkerName
  if (-not (Test-Path -LiteralPath $f)) { return $null }
  $o = @{ ref = ''; commit = ''; installed_at = ''; source = ''; skills = @() }
  foreach ($line in (Get-Content -LiteralPath $f)) {
    if ($line -match '^ref:\s*(.+)$')          { $o.ref = $Matches[1].Trim() }
    elseif ($line -match '^commit:\s*(.+)$')   { $o.commit = $Matches[1].Trim() }
    elseif ($line -match '^installed_at:\s*(.+)$') { $o.installed_at = $Matches[1].Trim() }
    elseif ($line -match '^source:\s*(.+)$')   { $o.source = $Matches[1].Trim() }
    elseif ($line -match '^skill:\s*(.+)$')    { $o.skills += $Matches[1].Trim() }
  }
  return $o
}

function Write-Marker {
  param([string]$SkillsDir, [string[]]$Skills, [string]$R, [string]$Commit, [string]$Provenance)
  $f = Join-Path $SkillsDir $MarkerName
  $lines = @(
    "# $PackageName install marker — written by install.ps1 $InstallerVersion",
    "# Do not edit. -Check treats this as a claim, never as proof;",
    "# the tree itself is always re-verified against the ref.",
    "schema: 1",
    "package: $PackageName",
    "ref: $R",
    "commit: $Commit",
    "source: $Provenance",
    "installed_at: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
    "installer_version: $InstallerVersion",
    "skills_count: $($Skills.Count)"
  )
  foreach ($s in $Skills) { $lines += "skill: $s" }
  # Written to a temp file and moved into place, like the sh port: a marker
  # half-written by a crash would claim an install that did not finish.
  $tmp = "$f.tmp.$PID"
  Set-Content -LiteralPath $tmp -Value $lines -Encoding UTF8
  Move-Item -LiteralPath $tmp -Destination $f -Force
}

# ------------------------------------------------------------------ legacy

function Find-Legacy {
  param([string[]]$Targets)
  $found = @(); $links = @()
  foreach ($t in $Targets) {
    foreach ($l in $LegacySkills) {
      $p = Join-Path $t $l
      # -Force so a hidden or dangling reparse point is seen; Test-Path alone
      # returns $false for a broken link, which would let it slip past the gate.
      if ((Test-Path -LiteralPath $p) -or (Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue)) {
        $item = Get-Item -LiteralPath $p -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $links += $p }
        elseif ($item.PSIsContainer) { $found += $p }
      }
    }
  }
  return @{ found = $found; links = $links }
}

function Invoke-LegacyGate {
  param([string[]]$Targets)
  $leg = Find-Legacy -Targets $Targets
  $total = $leg.found.Count + $leg.links.Count
  if ($total -eq 0) { return 0 }

  Say ""
  Say "################################################################"
  Say "#  BLOCKING: superseded legacy skill(s) detected                #"
  Say "################################################################"
  Say "This matrix REPLACES the single skill 'plaud-shopify-theme'."
  foreach ($p in $leg.found) { Say "  - $p" }
  foreach ($p in $leg.links) { Say "  - $p   (symlink/junction)" }
  Say "Installing beside them means one Plaud theme task matches two specs."
  Say ""

  if ($KeepLegacy) {
    Warn "-KeepLegacy given: routing is now ambiguous, the result is UNSUPPORTED."
    return 3
  }
  if (-not $RetireLegacy) {
    Say "ABORTED — nothing installed, nothing deleted."
    Say "  Retire them:   install.ps1 -RetireLegacy -Yes"
    Say "  Or knowingly:  install.ps1 -KeepLegacy   (UNSUPPORTED)"
    exit 2
  }
  if ($DryRun) { Say "[dry-run] would archive, verify, then remove the legacy skill(s)."; return 0 }

  $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
  foreach ($p in $leg.found) {
    $parent = Split-Path -Parent $p
    $why = Test-SkillsDir -Dir $parent
    if ($why) { Warn "  SKIP $p — parent is not a validated skills dir ($why)"; continue }
    $name = Split-Path -Leaf $p
    if ($name -notin $LegacySkills) { Warn "  SKIP $p — not in the legacy allowlist"; continue }
    $backupRoot = Join-Path $parent ".plaud-legacy-backup-$stamp"
    $archive = Join-Path $backupRoot "$name.zip"
    if (Test-Path -LiteralPath $archive) { Warn "  SKIP $p — backup destination exists"; continue }
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    try { Compress-Archive -Path (Join-Path $p '*') -DestinationPath $archive -Force } catch {
      Warn "  ARCHIVE FAILED for $p — left in place, nothing removed."; continue
    }
    # Verify by set comparison before deleting anything: every file on disk
    # must appear in the archive. A surplus of entries cannot mask a missing file.
    $onDisk = @(Get-ChildItem -LiteralPath $p -Recurse -File -Force |
                ForEach-Object { $_.FullName.Substring($p.Length + 1) -replace '\\', '/' } | Sort-Object)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $za = [IO.Compression.ZipFile]::OpenRead($archive)
    try { $inZip = @($za.Entries | Where-Object { $_.Name } | ForEach-Object { $_.FullName -replace '\\', '/' } | Sort-Object) }
    finally { $za.Dispose() }
    $missing = @($onDisk | Where-Object { $_ -notin $inZip })
    if ($missing.Count -gt 0) {
      Warn "  BACKUP VERIFICATION FAILED for $p (missing: $($missing -join ', ')) — left in place."
      continue
    }
    try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } catch {
      Warn "  REMOVE FAILED for $p"; continue
    }
    Say "  retired: $p  (restore: Expand-Archive '$archive')"
  }
  $leg2 = Find-Legacy -Targets $Targets
  if (($leg2.found.Count + $leg2.links.Count) -gt 0) {
    Say "ABORTED — legacy skill(s) still present after retirement; nothing installed."
    exit 2
  }
  return 0
}

# ----------------------------------------------------------------- install

# Install every skill into one client as a transaction:
#   stage (nothing live is touched) -> verify staged -> mark in-progress
#   -> swap -> verify live -> marker -> unmark
# A failure while staging leaves the client completely untouched. A failure or
# a kill during the swap leaves .plaud-install-inprogress behind, and -Check
# reports that client as interrupted rather than "ok".
function Install-Client {
  param([string]$SkillsDir, [string]$SrcRoot, [string[]]$Skills,
        [string]$R, [string]$Commit, [string]$Provenance)

  $why = Test-SkillsDir -Dir $SkillsDir
  if ($why) { Warn "Refusing unsafe install target ($why)"; return $false }

  if ($DryRun) {
    foreach ($s in $Skills) {
      $d = Join-Path $SkillsDir $s
      if (Test-Path -LiteralPath $d) { Say "  [dry-run] replace $d (stage, remove, swap)" }
      else { Say "  [dry-run] create  $d" }
    }
    Say "  [dry-run] write   $(Join-Path $SkillsDir $MarkerName)"
    return $true
  }

  # Staging lives INSIDE the skills dir: same volume, so the swap is a move,
  # not a second copy that can half-fail.
  # Two concurrent installs would interleave their swaps and trample each
  # other's in-progress marker. New-Item -ItemType Directory FAILS when the
  # directory already exists, which makes it the atomic test-and-set. A lock we
  # did not create is NEVER removed automatically: an abandoned lock has to be
  # looked at by a human, because the alternative is silently resuming on top
  # of an unknown half-state.
  $lock = Join-Path $SkillsDir '.plaud-install-lock'
  try {
    New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null
  } catch {
    Warn "FAILED: another install is running (or crashed) in $SkillsDir"
    Warn "        Lock: $lock"
    Warn "        If no installer is running, inspect the directory, then: Remove-Item '$lock'"
    return $false
  }
  try {

  $stage = Join-Path $SkillsDir (".plaud-staging-" + (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + "-$PID")
  if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
  try { New-Item -ItemType Directory -Force -Path $stage | Out-Null } catch {
    Warn "FAILED: cannot create staging dir in $SkillsDir : $($_.Exception.Message)"; return $false
  }

  $ok = $true
  foreach ($s in $Skills) {
    $src = Join-Path $SrcRoot $s
    $dst = Join-Path $stage $s
    try { Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force -ErrorAction Stop } catch {
      Warn "FAILED: cannot stage $s : $($_.Exception.Message)"; $ok = $false; break
    }
    $iSrc = Get-TreeInventory -Root $src -Label "source/$s" -WithHash
    $iStg = Get-TreeInventory -Root $dst -Label "staged/$s" -WithHash
    if (-not $iSrc -or -not $iStg) { $ok = $false; break }
    if (-not (Compare-Inventory -Expected $iSrc -Actual $iStg -What $s)) {
      Warn "FAILED: staged $s does not match the package"; $ok = $false; break
    }
  }
  if (-not $ok) {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Warn "Nothing was changed in $SkillsDir (failure happened before any live directory was touched)."
    return $false
  }

  $prog = Join-Path $SkillsDir $InProgressName
  try {
    Set-Content -LiteralPath $prog -Encoding UTF8 -Value @(
      "ref: $R", "started_at: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))", "pid: $PID")
  } catch {
    Warn "FAILED: cannot write $prog"; Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue; return $false
  }

  foreach ($s in $Skills) {
    $dest = Join-Path $SkillsDir $s
    if (Test-Path -LiteralPath $dest) {
      $item = Get-Item -LiteralPath $dest -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Warn "FAILED: $dest is a reparse point; refusing to touch it"; $ok = $false; break
      }
      # The removal's success is checked AND re-verified. Historical failure:
      # the delete silently failed, the script still reported "Installed", and
      # a reference deleted by the new version survived and kept being routed to.
      try { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction Stop } catch {
        Warn "FAILED: cannot remove $dest ($($_.Exception.Message))"
        Warn "        Refusing to overlay: a partial overlay leaves stale files from the old version."
        $ok = $false; break
      }
      if (Test-Path -LiteralPath $dest) {
        Warn "FAILED: $dest still exists after removal; refusing to overlay it"; $ok = $false; break
      }
    }
    try { Move-Item -LiteralPath (Join-Path $stage $s) -Destination $dest -ErrorAction Stop } catch {
      Warn "FAILED: cannot move staged $s into place: $($_.Exception.Message)"; $ok = $false; break
    }
    # "SKILL.md exists" cannot tell a fresh copy from a survivor of the previous
    # version. Compare the whole inventory: anything only in the destination is
    # a stale leftover that keeps being routed to.
    $iSrc = Get-TreeInventory -Root (Join-Path $SrcRoot $s) -Label "source/$s" -WithHash
    $iDst = Get-TreeInventory -Root $dest -Label $dest -WithHash
    if (-not $iSrc -or -not $iDst -or -not (Compare-Inventory -Expected $iSrc -Actual $iDst -What $s)) {
      Warn "FAILED: $dest does not match the package after install."; $ok = $false; break
    }
    Say "  installed $s"
  }

  if (-not $ok) {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Warn "PARTIAL INSTALL in $SkillsDir — $prog left in place as evidence."
    return $false
  }

  Write-Marker -SkillsDir $SkillsDir -Skills $Skills -R $R -Commit $Commit -Provenance $Provenance
  Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $prog -Force
  return $true
  } finally {
    # Only ever removes the lock this call created.
    Remove-Item -LiteralPath $lock -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# ------------------------------------------------------------------- check

function Invoke-Check {
  param([string]$WorkDir, [string[]]$ClientList)
  Say "$PackageName — install check"
  Say "repo: $Repo"
  $latest = $null
  if (-not $Ref -and -not $Source -and -not $Tarball) {
    $latest = Resolve-LatestTag -RepoUrl $Repo
    if ($latest) { Say "newest tag: $latest" }
  }

  $bad = 0; $total = 0
  foreach ($c in $ClientList) {
    $dir = Get-ClientPath $c
    $total++
    Say ""
    Say "-- $c  ($dir)"
    if (-not (Test-Path -LiteralPath $dir)) { Say "   skills dir absent — matrix not installed"; $bad++; continue }
    $why = Test-SkillsDir -Dir $dir
    if ($why) { Warn "   UNSAFE PATH: $why"; $bad++; continue }

    $clientBad = $false
    # Test-Path, not Test-Path -PathType Leaf: replacing the marker with a
    # directory or a reparse point must not read as "no interrupted install".
    if (Test-Path -LiteralPath (Join-Path $dir $InProgressName)) {
      Say "   INTERRUPTED INSTALL: $InProgressName is still present"
      $clientBad = $true
    }
    $leftoverStage = @(Get-ChildItem -LiteralPath $dir -Directory -Force -Filter '.plaud-staging-*' -ErrorAction SilentlyContinue)
    foreach ($st in $leftoverStage) {
      Say "   INTERRUPTED INSTALL: leftover staging dir $($st.Name)"
      $clientBad = $true
    }
    if (Test-Path -LiteralPath (Join-Path $dir '.plaud-install-lock')) {
      Say "   LOCK PRESENT:  an install is running here, or one crashed"
      $clientBad = $true
    }

    $mf = Join-Path $dir $MarkerName
    if ((Test-Path -LiteralPath $mf) -and -not (Test-Path -LiteralPath $mf -PathType Leaf)) {
      Say "   marker:        NOT A REGULAR FILE — unusable, provenance unproven"
      $clientBad = $true
    }
    $m = Read-Marker -SkillsDir $dir
    if ($m -and -not $m.ref) {
      Say "   marker:        HAS NO ref: FIELD — unusable, provenance unproven"
      $clientBad = $true; $m = $null
    }
    if ($m -and -not (Test-ValidRef $m.ref)) {
      # Without this, editing the marker to say `main` would make -Check fetch
      # a branch and hold the client to it.
      Say "   marker ref:    NOT A RELEASE TAG ($($m.ref)) — refusing to compare against it"
      $clientBad = $true; $m = $null
    }
    if ($m) {
      Say "   marker ref:    $($m.ref)"
      Say "   marker commit: $($m.commit)"
      Say "   installed at:  $($m.installed_at)"
      Say "   source:        $($m.source)"
    } else {
      Say "   marker:        MISSING — provenance unproven"
      $clientBad = $true
    }

    # An explicit -Ref wins; otherwise the client's own claim. The marker is a
    # claim, never proof: the tree below is re-verified by hash either way, so
    # a hand-edited marker cannot make a wrong tree pass.
    $useRef = $Ref
    if (-not $useRef) { $useRef = if ($m) { $m.ref } else { $latest } }
    if (-not $useRef) { Say "   cannot pick a ref to compare against; pass -Ref"; $bad++; continue }
    if ($Ref -and $m -and $m.ref -and $m.ref -ne $Ref) {
      Say "   REF MISMATCH: client claims $($m.ref), you asked about $Ref"; $clientBad = $true
    }
    if (-not $Ref -and $latest -and $m -and $m.ref -and $m.ref -ne $latest) {
      Say "   BEHIND: $($m.ref) installed, $latest is the newest tag"
    }

    # The marker's commit is a claim too. A moved tag or a forged marker shows
    # up as a mismatch against what the tag actually points at now.
    if ($m -and $m.commit -and -not $m.commit.StartsWith('unknown')) {
      $realCommit = Resolve-CommitSha -RepoUrl $Repo -R $m.ref
      if ($realCommit -and -not $realCommit.StartsWith('unknown') -and $realCommit -ne $m.commit) {
        Say "   COMMIT MISMATCH: marker says $($m.commit), $($m.ref) now points at $realCommit"
        $clientBad = $true
      }
    }

    $root = Get-PackageTree -R $useRef -WorkDir $WorkDir
    $refSkills = Get-SkillNames -Root $root
    if ($refSkills.Count -eq 0) { Warn "   ref $useRef contains no skills"; $bad++; continue }

    $mismatch = 0
    foreach ($s in $refSkills) {
      $dest = Join-Path $dir $s
      if (-not (Test-Path -LiteralPath $dest)) { Say "   ${s}: MISSING"; $mismatch++; continue }
      if ((Get-Item -LiteralPath $dest -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Say "   ${s}: REPARSE POINT — a skill directory must be a real directory"; $mismatch++; continue
      }
      $iSrc = Get-TreeInventory -Root (Join-Path $root $s) -Label "ref/$s" -WithHash
      $iDst = Get-TreeInventory -Root $dest -Label $dest -WithHash
      if (-not $iSrc -or -not $iDst) { $mismatch++; continue }
      if (-not (Compare-Inventory -Expected $iSrc -Actual $iDst -What $s)) {
        Say "   ${s}: DIFFERS (paths or content)"; $mismatch++
      }
    }
    Say "   tree diff:     $mismatch/$($refSkills.Count) mismatched vs $useRef"
    if ($mismatch -gt 0) { $clientBad = $true }

    # Stale skills: in the client, absent from the ref. Two independent
    # sources, because either alone has a hole: (1) what the marker says was
    # installed, (2) anything named plaud-theme-* or on the legacy list (covers
    # a hand-deleted marker). Other packages' skills are never touched.
    $cand = @()
    if ($m) { $cand += $m.skills }
    foreach ($d in (Get-ChildItem -LiteralPath $dir -Directory -Force)) {
      if ($d.Name.StartsWith($SkillPrefix) -or ($d.Name -in $LegacySkills)) { $cand += $d.Name; continue }
      # Third source: the directory NAME can be changed, the skill's declared
      # `name:` cannot without breaking the skill. Renaming a dropped skill out
      # of the plaud-theme-* prefix would otherwise slip past both the marker
      # list and the prefix scan and keep being routed to.
      $sk = Join-Path $d.FullName 'SKILL.md'
      if (Test-Path -LiteralPath $sk -PathType Leaf) {
        $decl = (Select-String -LiteralPath $sk -Pattern '^name:\s*(.+)$' -List).Matches.Groups[1].Value
        if ($decl -and $decl.Trim().Trim('"',"'").StartsWith($SkillPrefix)) { $cand += $d.Name }
      }
    }
    $stale = @($cand | Sort-Object -Unique | Where-Object { $_ -and ($_ -notin $refSkills) -and (Test-Path -LiteralPath (Join-Path $dir $_)) })
    foreach ($s in $stale) {
      Say "   STALE SKILL:   $s — not in $useRef, still installed and still routable"
    }
    if ($stale.Count -gt 0) {
      Say "   $($stale.Count) stale skill(s). Remove by hand: Remove-Item -Recurse '$dir\<name>'"
      $clientBad = $true
    }

    if ($clientBad) { $bad++ } else { Say "   OK" }
  }

  Say ""
  if ($bad -eq 0) { Say "All $total client(s) consistent."; return 0 }
  Say "PROBLEMS in $bad of $total client(s). See above."
  return 4
}

# -------------------------------------------------------------------- main

$work = Join-Path ([IO.Path]::GetTempPath()) ("plaud-install-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
  # The sh port also accepts a local git repo for -Repo (via `git archive`).
  # This port has no such path, so reject it loudly instead of building a
  # nonsense codeload URL out of a filesystem path.
  if ($Repo -notmatch '^https?://') {
    Die "-Repo must be an https URL here. Installing from a local git repo is a sh-port-only feature; use -Source DIR or -Tarball FILE instead."
  }
  $clientList = if ($Clients) { @($Clients -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { $ClientNames }
  foreach ($c in $clientList) { if (-not (Get-ClientPath $c)) { Die "Unknown client: $c" } }

  if ($Check) { exit (Invoke-Check -WorkDir $work -ClientList $clientList) }

  Say "$PackageName installer $InstallerVersion"
  if ($DryRun) { Say "*** DRY RUN — no install target is touched ***" }

  # Resolve the ref. Never silently install a branch: an unreviewed main is
  # not a release.
  $provenance = $Repo
  $commit = ''
  if ($Source) {
    if (-not $Ref) { $Ref = 'local' }
    $provenance = "local-checkout:$Source (UNVERIFIED PROVENANCE)"
    $commit = 'unknown(local-checkout)'
  } elseif ($Tarball) {
    if (-not $Ref) { Die "-Tarball requires -Ref (it is recorded in the install marker)" }
    if (-not (Test-ValidRef $Ref)) { Die "-Ref must look like vMAJOR.MINOR.PATCH: $Ref" }
    $provenance = "tarball:$Tarball"
    $commit = 'unknown(tarball)'
  } else {
    if ($Ref) {
      if (-not (Test-ValidRef $Ref)) { Die "-Ref must be a release tag vMAJOR.MINOR.PATCH: $Ref" }
    } else {
      Say "Resolving the newest release tag of $Repo ..."
      $Ref = Resolve-LatestTag -RepoUrl $Repo
      if (-not $Ref) {
        Die "could not resolve the newest release tag (offline, rate-limited, or no tags).`n       Pass an explicit tag, e.g.:  -Ref v0.3.0`n       Tags: $Repo/tags"
      }
      Say "Newest release tag: $Ref"
    }
    $commit = Resolve-CommitSha -RepoUrl $Repo -R $Ref
  }
  Say "ref:    $Ref"
  Say "commit: $commit"
  Say "source: $provenance"
  Say ""

  $srcRoot = Get-PackageTree -R $Ref -WorkDir $work
  $skills = Get-SkillNames -Root $srcRoot
  if ($skills.Count -eq 0) { Die "no skill directories (dirs holding SKILL.md) found in $Ref" }
  Say "Skills in $Ref ($($skills.Count)):"
  foreach ($s in $skills) { Say "  - $s" }
  Say ""

  $targets = @(); $skipped = @()
  $createList = @($CreateMissing -split ',' | ForEach-Object { $_.Trim() })
  foreach ($c in $clientList) {
    $p = Get-ClientPath $c
    if (Test-Path -LiteralPath $p) { $targets += $p }
    elseif ($createList -contains 'all' -or $createList -contains $c) {
      if ($DryRun) { Say "  [dry-run] create $p" } else { New-Item -ItemType Directory -Force -Path $p | Out-Null }
      $targets += $p
    } else { $skipped += "$c -> $p" }
  }
  if ($targets.Count -eq 0) {
    Say "No install targets found. Re-run with -CreateMissing all"
    foreach ($s in $skipped) { Say "  - $s" }
    exit 1
  }
  Say "Install targets:"
  foreach ($t in $targets) { Say "  - $t" }
  if ($skipped.Count -gt 0) {
    Say ""
    Say "SKIPPED — skills dir does not exist (pass -CreateMissing all):"
    foreach ($s in $skipped) { Say "  - $s" }
    Say "These clients will NOT get the matrix. This is the main reason for"
    Say "'I thought I installed it'."
  }
  Say ""

  $unsupported = Invoke-LegacyGate -Targets $targets

  $ok = 0
  foreach ($t in $targets) {
    Say "-> $t"
    if (Install-Client -SkillsDir $t -SrcRoot $srcRoot -Skills $skills -R $Ref -Commit $commit -Provenance $provenance) { $ok++ }
  }

  Say ""
  if ($DryRun) { Say "Dry run complete. $ok of $($targets.Count) client(s) would be installed."; exit 0 }

  # Counted per fully committed CLIENT, not per copied skill: a client whose
  # marker did not land is not a successful install even if every skill copied.
  if ($ok -ne $targets.Count) {
    Say "FAILED: $ok of $($targets.Count) clients installed ($($targets.Count - $ok) failed)."
    Say "Do NOT treat this as a completed install. Fix the cause, re-run, then"
    Say "verify with:  install.ps1 -Check"
    exit 1
  }
  Say "Done. $PackageName $Ref installed to $ok client(s)."
  Say "Verify any time with:  install.ps1 -Check"
  if ($unsupported -eq 3) {
    Say ""
    Say "UNSUPPORTED STATE — the legacy skill was kept alongside the matrix."
    exit 3
  }
  exit 0
} finally {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
