#!/usr/bin/env bash
# Install every skill in the PLAUD Shopify Theme matrix to global agent skills directories.
# macOS / Linux — compatible with bash 3.2+
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="plaud-shopify-theme-matrix"
PACKAGE_VERSION="v0.2.1"

# Skills that this matrix supersedes and that must not stay installed alongside it.
# Keeping the old single skill causes routing competition: two different specs
# match the same Plaud theme task.
LEGACY_SKILLS=("plaud-shopify-theme")

CLIENT_NAMES=(cursor claude codex agents)

usage() {
  cat <<EOF
${PACKAGE_NAME} ${PACKAGE_VERSION} installer (macOS / Linux)

Usage: $0 [OPTIONS]

Installs every root-level directory containing SKILL.md as an individual skill
into ~/.<client>/skills/<skill-name>/. With no options, all four clients are
used: cursor, claude, codex, agents.

Replacement is total, not a merge: an existing skill directory with the same
name is removed before the new content is extracted, so no stale files survive
inside a skill. The installer never deletes skills it did not install — except
via the explicit --retire-legacy switch described below.

Options:
  --target DIR          Install only to DIR. DIR must be a skills directory:
                        its last path component has to be exactly "skills".
  --clients LIST        Comma-separated subset: cursor,claude,codex,agents
                        (NOT recommended — narrowing this is how client drift
                        happens: two clients on one spec, two on another)
  --create-missing LIST Create the skills dir for the listed clients.
                        Without this, a client whose skills dir does not exist
                        is SILENTLY SKIPPED (it is reported at the end).
  --all-known           Install to all known client dirs, creating missing ones
                        (prompts unless --yes)
  --include-workspace   Also search upward for .cursor/skills or .claude/skills
  --retire-legacy       Archive and REMOVE superseded legacy skills
                        (${LEGACY_SKILLS[*]}) from every install target, then
                        install. Destructive, but the archive is verified
                        before anything is deleted.
  --keep-legacy         Knowingly install ALONGSIDE the old skill. Dual-spec,
                        routing is ambiguous, result is UNSUPPORTED. Prints a
                        loud warning and exits with status 3.
  --backup-dir DIR      Base directory for --retire-legacy archives. A unique
                        subdirectory is always appended. Default base is the
                        target skills dir, giving
                        <skills-dir>/.plaud-legacy-backup-<timestamp>/
  --dry-run             Print every action without touching install targets,
                        backup locations, or any skill.
  --yes                 Skip confirmation prompts
  -h, --help            Show this help

Legacy retirement is a PRECONDITION, not an option:
  This matrix replaces the single skill 'plaud-shopify-theme'. If both are
  installed, the same Plaud theme task matches two different specs and routing
  becomes ambiguous — the exact problem the matrix exists to remove.

  So this installer FAILS CLOSED. If any target still has the old skill:

    - interactive terminal : you are asked whether to retire it and continue;
                             declining aborts with status 2, nothing installed
    - non-interactive/--yes: aborts with status 2 unless --retire-legacy is
                             also given; nothing installed, nothing deleted
    - --retire-legacy      : archive -> verify -> remove, then install. If any
                             legacy path survives, the install still aborts
    - --keep-legacy        : installs anyway and exits 3 (UNSUPPORTED)

  A legacy path that is a symlink/junction is never followed or deleted. It
  blocks the install and must be removed by hand.

Exit codes:
  0  success
  1  usage / configuration error
  2  aborted: legacy skill present and not retired
  3  installed with --keep-legacy (dual-spec, unsupported)

Examples:
  $0                                        # install to all four clients
  $0 --dry-run                              # show what would happen, incl. aborts
  $0 --retire-legacy --yes                  # retire the old skill, then install
  $0 --keep-legacy                          # dual-spec install (unsupported)
  $0 --create-missing cursor,claude,codex,agents
EOF
}

TARGET=""
CLIENTS=""
ALL_KNOWN=0
CREATE_MISSING=""
INCLUDE_WORKSPACE=0
ASSUME_YES=0
RETIRE_LEGACY=0
KEEP_LEGACY=0
BACKUP_DIR=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --clients) CLIENTS="${2:-}"; shift 2 ;;
    --all-known) ALL_KNOWN=1; shift ;;
    --create-missing) CREATE_MISSING="${2:-}"; shift 2 ;;
    --include-workspace) INCLUDE_WORKSPACE=1; shift ;;
    --retire-legacy) RETIRE_LEGACY=1; shift ;;
    --keep-legacy) KEEP_LEGACY=1; shift ;;
    --backup-dir) BACKUP_DIR="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

HOME_DIR="${HOME:-}"
if [[ -z "$HOME_DIR" && -z "$TARGET" ]]; then
  echo "Error: cannot determine home directory. Set HOME or pass --target." >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

say() { echo "$@"; }
die() { echo "Error: $*" >&2; exit 1; }

# `read` returns non-zero at EOF, which under `set -e` would kill the script
# silently. Always treat a failed/absent answer as "no" — the safe direction.
ask_yes_no() {
  local prompt="$1" ans=""
  if ! read -r -p "$prompt" ans; then
    ans=""
    say ""
  fi
  [[ "$ans" =~ ^[Yy] ]]
}

client_path() {
  case "$1" in
    cursor) echo "${HOME_DIR}/.cursor/skills" ;;
    claude) echo "${HOME_DIR}/.claude/skills" ;;
    codex)  echo "${HOME_DIR}/.codex/skills" ;;
    agents) echo "${HOME_DIR}/.agents/skills" ;;
    *) echo "" ;;
  esac
}

should_create_missing() {
  local c="$1"
  if [[ "$ALL_KNOWN" == 1 ]]; then return 0; fi
  case ",${CREATE_MISSING}," in *",${c},"*) return 0 ;; esac
  return 1
}

# ------------------------------------------------------------ path safety

# A single validator, used by BOTH install and legacy retirement. Every path
# that this script will create into, extract into, or delete from must pass it.
# "Contains the substring skills" is not good enough: the last component has to
# be exactly `skills`.
validate_skills_dir() {
  local d="$1"
  [[ -n "$d" ]] || { echo "empty path" ; return 1; }
  [[ "$d" != "/" ]] || { echo "refusing the filesystem root"; return 1; }
  d="${d%/}"
  [[ -n "$d" ]] || { echo "refusing the filesystem root"; return 1; }
  [[ "$d" == /* ]] || { echo "not an absolute path: $d"; return 1; }
  [[ "$(basename "$d")" == "skills" ]] || { echo "last path component must be exactly 'skills': $d"; return 1; }
  [[ -z "$HOME_DIR" || "$d" != "${HOME_DIR%/}" ]] || { echo "refusing home directory: $d"; return 1; }
  [[ "$d" != "$SCRIPT_DIR" ]] || { echo "refusing the package root itself: $d"; return 1; }
  local parent
  parent="$(dirname "$d")"
  [[ -n "$parent" && "$parent" != "$d" ]] || { echo "cannot resolve parent of: $d"; return 1; }
  # Lexical checks are not enough: a symlinked `skills` dir (or a symlinked
  # ancestor) would let a delete escape to a completely different tree. Resolve
  # physically and require the resolved path to still look like a skills dir.
  if [[ -d "$d" ]]; then
    local real
    real="$(cd -P "$d" 2>/dev/null && pwd -P)" || { echo "cannot resolve physical path of: $d"; return 1; }
    [[ -n "$real" && "$real" != "/" ]] || { echo "resolves to the filesystem root: $d"; return 1; }
    [[ "$(basename "$real")" == "skills" ]] || { echo "resolves through a symlink to a non-skills dir: $d -> $real"; return 1; }
    [[ -z "$HOME_DIR" || "$real" != "${HOME_DIR%/}" ]] || { echo "resolves to the home directory: $d"; return 1; }
  fi
  return 0
}

# Root-level directories holding a SKILL.md. The glob is deliberately not
# dotglob-enabled, and dot-prefixed names are skipped explicitly, so a
# .plaud-legacy-backup-* directory is never picked up as a skill source.
SOURCES=()
discover_skill_sources() {
  local d name
  for d in "$SCRIPT_DIR"/*; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    case "$name" in .*) continue ;; esac
    [[ -f "$d/SKILL.md" ]] || continue
    SOURCES+=("$d")
  done
  if [[ "${#SOURCES[@]}" -eq 0 ]]; then
    die "no root-level skill directories found in $SCRIPT_DIR"
  fi
}

TARGETS=()
SKIPPED=()
add_target() {
  local t="$1"
  [[ "$t" == "/" ]] || t="${t%/}"
  local why
  if ! why="$(validate_skills_dir "$t")"; then
    say "Refusing unsafe install target: $why"
    return 1
  fi
  local existing
  for existing in ${TARGETS[@]+"${TARGETS[@]}"}; do
    [[ "$existing" == "$t" ]] && return 0
  done
  TARGETS+=("$t")
}

discover_targets() {
  if [[ -n "$TARGET" ]]; then
    local t="$TARGET"
    [[ "$t" == "/" ]] || t="${t%/}"
    # Accept "<client-root>" only when "<client-root>/skills" exists.
    if [[ "$(basename "$t")" != "skills" ]] && [[ -d "$t/skills" ]]; then
      t="$t/skills"
    fi
    add_target "$t" || die "--target rejected. Pass a directory whose last component is 'skills'."
    return
  fi

  local client_list="cursor,claude,codex,agents"
  [[ -n "$CLIENTS" ]] && client_list="$CLIENTS"

  local old_ifs="$IFS"
  IFS=','
  local c
  for c in $client_list; do
    IFS="$old_ifs"
    c="${c// /}"
    [[ -z "$c" ]] && { IFS=','; continue; }
    local path
    path="$(client_path "$c")"
    if [[ -z "$path" ]]; then
      say "Unknown client: $c"
      IFS=','
      continue
    fi
    if [[ -d "$path" ]]; then
      add_target "$path" || true
    elif should_create_missing "$c"; then
      if [[ "$ALL_KNOWN" == 1 ]] && [[ "$ASSUME_YES" != 1 ]] && [[ "$DRY_RUN" != 1 ]]; then
        if ! ask_yes_no "Create $path? [y/N] "; then IFS=','; continue; fi
      fi
      if add_target "$path"; then
        if [[ "$DRY_RUN" == 1 ]]; then
          say "  [dry-run] mkdir -p $path"
        else
          mkdir -p "$path"
        fi
      fi
    else
      SKIPPED+=("${c}|${path}")
    fi
    IFS=','
  done
  IFS="$old_ifs"

  if [[ "$INCLUDE_WORKSPACE" == 1 ]]; then
    local dir="$SCRIPT_DIR"
    local i=0
    local sub
    while [[ $i -lt 5 ]]; do
      for sub in .cursor/skills .claude/skills; do
        [[ -d "$dir/$sub" ]] && add_target "$dir/$sub" || true
      done
      [[ "$dir" == "/" ]] && break
      dir="$(dirname "$dir")"
      i=$((i + 1))
    done
  fi
}

# ---------------------------------------------------------------- legacy

# LEGACY_FOUND  — real directories; can be archived and retired automatically.
# LEGACY_LINKS  — symlinks/junctions; BLOCK the install but are never followed
#                 or deleted by this script. The user removes them by hand.
LEGACY_FOUND=()
LEGACY_LINKS=()

scan_legacy() {
  local skills_dir legacy p
  for skills_dir in ${TARGETS[@]+"${TARGETS[@]}"}; do
    for legacy in "${LEGACY_SKILLS[@]}"; do
      p="${skills_dir%/}/${legacy}"
      if [[ -L "$p" ]]; then
        LEGACY_LINKS+=("$p")
      elif [[ -d "$p" ]]; then
        LEGACY_FOUND+=("$p")
      fi
    done
  done
}

legacy_total() {
  echo $(( ${#LEGACY_FOUND[@]} + ${#LEGACY_LINKS[@]} ))
}

report_legacy() {
  [[ "$(legacy_total)" -eq 0 ]] && return 0

  say ""
  say "################################################################"
  say "#  BLOCKING: superseded legacy skill(s) detected                #"
  say "################################################################"
  say ""
  say "This matrix REPLACES the single skill 'plaud-shopify-theme'."
  say "Found $(legacy_total) legacy install(s):"
  local p
  for p in ${LEGACY_FOUND[@]+"${LEGACY_FOUND[@]}"}; do say "  - $p"; done
  for p in ${LEGACY_LINKS[@]+"${LEGACY_LINKS[@]}"}; do say "  - $p   (symlink/junction)"; done
  say ""
  say "Installing the matrix alongside them produces ROUTING COMPETITION: the"
  say "same Plaud theme task matches both the old single skill and this matrix,"
  say "so two different specs run against one project. That is exactly what"
  say "splitting the matrix was meant to eliminate, so this installer will NOT"
  say "install into a client that still has the old skill."
  say ""
}

# Prints the manual escape hatches. Called on every abort path.
print_legacy_remedies() {
  local p n=1
  say "How to proceed:"
  say ""
  if [[ "${#LEGACY_FOUND[@]}" -gt 0 ]]; then
    say "  ${n}. Retire them (archive -> verify -> remove), then install:"
    say "         $0 --retire-legacy --yes"
    say ""
    n=$((n + 1))
  fi
  if [[ "${#LEGACY_LINKS[@]}" -gt 0 ]]; then
    say "  ${n}. The symlink(s) below CANNOT be retired automatically — this script"
    say "     never follows or deletes a link. Remove them by hand first:"
    for p in "${LEGACY_LINKS[@]}"; do
      say "         rm \"$p\""
    done
    say ""
    n=$((n + 1))
  fi
  say "  ${n}. Knowingly keep the old skill and accept a dual-spec, unsupported"
  say "     environment (NOT recommended):"
  say "         $0 --keep-legacy"
  say ""
}

# Where an archive for $1 (a legacy skill path) goes. A unique timestamped
# subdirectory is ALWAYS appended, even under --backup-dir, so two targets can
# never collide on one destination.
validate_backup_dir() {
  [[ -n "$BACKUP_DIR" ]] || return 0
  [[ "$BACKUP_DIR" != "/" ]] || die "--backup-dir must not be the filesystem root"
  local base="${BACKUP_DIR%/}"
  [[ -n "$base" ]] || die "--backup-dir must not be the filesystem root"
  [[ "$base" == /* ]] || die "--backup-dir must be an absolute path: $BACKUP_DIR"
  [[ -z "$HOME_DIR" || "$base" != "${HOME_DIR%/}" ]] || die "--backup-dir must not be the home directory itself"
  local p
  for p in ${LEGACY_FOUND[@]+"${LEGACY_FOUND[@]}"}; do
    [[ "$base" != "$p" && "$base" != "$p"/* ]] || die "--backup-dir must not live inside the skill being retired: $p"
  done
}

backup_root_for() {
  local legacy_path="$1"
  local parent
  parent="$(dirname "$legacy_path")"
  if [[ -n "$BACKUP_DIR" ]]; then
    # client-scoped subdir keeps four targets from writing the same filename
    echo "${BACKUP_DIR%/}/.plaud-legacy-backup-${TIMESTAMP}/$(basename "$(dirname "$parent")")"
  else
    # Hidden directory: skipped by this installer's source scan.
    echo "${parent}/.plaud-legacy-backup-${TIMESTAMP}"
  fi
}

retire_legacy() {
  local count="${#LEGACY_FOUND[@]}"
  [[ "$count" -eq 0 ]] && return 0
  [[ "$RETIRE_LEGACY" == 1 ]] || return 0

  if [[ "$ASSUME_YES" != 1 ]] && [[ "$DRY_RUN" != 1 ]]; then
    if ! ask_yes_no "Archive and remove the $count legacy install(s) listed above? [y/N] "; then
      say "Skipped legacy retirement at user request."
      return 0
    fi
  fi

  local p parent name backup_root archive why
  for p in "${LEGACY_FOUND[@]}"; do
    parent="$(dirname "$p")"
    name="$(basename "$p")"

    # Re-assert every safety property immediately before the destructive step.
    if ! why="$(validate_skills_dir "$parent")"; then
      say "  SKIP $p — parent is not a validated skills dir ($why)"
      continue
    fi
    local is_legacy=0 l
    for l in "${LEGACY_SKILLS[@]}"; do [[ "$name" == "$l" ]] && is_legacy=1; done
    if [[ "$is_legacy" -ne 1 ]]; then
      say "  SKIP $p — name is not in the legacy allowlist"
      continue
    fi
    if [[ -L "$p" ]]; then
      say "  SKIP $p — symlink"
      continue
    fi
    # Stricter than the install path: for a DELETE, no link is tolerated
    # anywhere in the chain. If the physical path differs from the lexical one,
    # some ancestor is a symlink and the delete could land outside the tree the
    # user thinks they are touching.
    local real_parent
    real_parent="$(cd -P "$parent" 2>/dev/null && pwd -P)" || real_parent=""
    if [[ -z "$real_parent" || "$real_parent" != "$parent" ]]; then
      say "  SKIP $p — the path resolves through a symlink ($parent -> ${real_parent:-unresolvable})." >&2
      say "         Re-run with --target \"${real_parent:-<resolved path>}\" if that is really what you mean." >&2
      continue
    fi

    backup_root="$(backup_root_for "$p")"
    archive="${backup_root}/${name}.tar.gz"

    say "  archive: $p  ->  $archive"
    if [[ "$DRY_RUN" == 1 ]]; then
      say "  [dry-run] mkdir -p \"$backup_root\""
      say "  [dry-run] tar -C \"$parent\" -czf \"$archive\" \"$name\""
      say "  [dry-run] verify archive lists ${name}/SKILL.md, then rm -rf \"$p\""
      continue
    fi

    if [[ -e "$archive" ]]; then
      say "  SKIP $p — backup destination already exists: $archive" >&2
      continue
    fi
    mkdir -p "$backup_root"
    if ! tar -C "$parent" -czf "$archive" "$name"; then
      say "  ARCHIVE FAILED for $p — left in place, nothing removed." >&2
      continue
    fi
    # Verify the archive really contains the skill before deleting anything.
    # A count comparison is not enough (tar lists symlinks and specials too, so
    # a surplus could mask a missing regular file). Compare the actual path sets
    # and fail if anything on disk is absent from the archive.
    if ! tar -tzf "$archive" | grep -q "^${name}/SKILL.md$"; then
      say "  BACKUP VERIFICATION FAILED for $p (no SKILL.md in archive) — left in place." >&2
      continue
    fi
    local missing
    missing="$(comm -13 \
      <(tar -tzf "$archive" | sed 's:/$::' | LC_ALL=C sort -u) \
      <(cd "$parent" && find "$name" | sed 's:/$::' | LC_ALL=C sort -u) | head -5)"
    if [[ -n "$missing" ]]; then
      say "  BACKUP VERIFICATION FAILED for $p — these paths are missing from the archive:" >&2
      say "$missing" >&2
      say "  Left in place, nothing removed." >&2
      continue
    fi
    rm -rf "$p"
    say "  retired: $p  (restore: tar -C \"$parent\" -xzf \"$archive\")"
  done
  say ""
}

# ---------------------------------------------------------- legacy gate

# Exit codes:
#   0  success
#   1  usage / configuration error
#   2  aborted: legacy skill present and not retired (fail closed)
#   3  installed with --keep-legacy: dual-spec, UNSUPPORTED environment
EXIT_UNSUPPORTED=0

# Fail closed. Reaching the install loop with a legacy skill still on disk is
# only possible via the explicit --keep-legacy escape hatch.
legacy_gate() {
  [[ "$(legacy_total)" -eq 0 ]] && return 0

  if [[ "$KEEP_LEGACY" == 1 ]]; then
    say "--keep-legacy given: continuing anyway."
    say ""
    say "!!  This leaves the old single skill and the matrix installed side by"
    say "!!  side. Routing is now ambiguous and the result is UNSUPPORTED."
    say "!!  Fix it later with:  $0 --retire-legacy --yes"
    say ""
    EXIT_UNSUPPORTED=1
    return 0
  fi

  if [[ "$RETIRE_LEGACY" != 1 ]]; then
    # Interactive terminal: offer retirement. Anything else must be explicit.
    if [[ -t 0 && "$ASSUME_YES" != 1 && "$DRY_RUN" != 1 ]]; then
      if ask_yes_no "Archive and retire the legacy skill(s) now, then install? [y/N] "; then
        RETIRE_LEGACY=1
        ASSUME_YES=1   # the prompt above already is the confirmation
      else
        say ""
        say "ABORTED — nothing installed, nothing deleted."
        say ""
        print_legacy_remedies
        exit 2
      fi
    else
      say "ABORTED — nothing installed, nothing deleted."
      if [[ "$DRY_RUN" == 1 ]]; then
        say "(dry run: a real run would abort here too, with exit code 2)"
      else
        say "(non-interactive run: retirement must be requested explicitly)"
      fi
      say ""
      print_legacy_remedies
      exit 2
    fi
  fi

  # --retire-legacy path. In a dry run nothing is touched, so report and stop.
  if [[ "$DRY_RUN" == 1 ]]; then
    retire_legacy
    say "Dry run: the retirement above would run first, then the matrix would install."
    return 0
  fi

  retire_legacy

  # Re-scan: anything that survived (verification failure, pre-existing archive,
  # symlink, user declined) still blocks. Never install over a survivor.
  LEGACY_FOUND=()
  LEGACY_LINKS=()
  scan_legacy
  if [[ "$(legacy_total)" -gt 0 ]]; then
    say "ABORTED — legacy skill(s) still present after retirement; nothing installed."
    local p
    for p in ${LEGACY_FOUND[@]+"${LEGACY_FOUND[@]}"} ${LEGACY_LINKS[@]+"${LEGACY_LINKS[@]}"}; do
      say "  - $p"
    done
    say ""
    print_legacy_remedies
    exit 2
  fi
  return 0
}

# ------------------------------------------------------------------- install

install_one_skill() {
  local src="$1"
  local skills_dir="$2"
  local skill_name
  skill_name="$(basename "$src")"
  local dest="${skills_dir%/}/${skill_name}"
  local why

  if ! why="$(validate_skills_dir "$skills_dir")"; then
    say "Skip unsafe path ($why)" >&2
    return 1
  fi
  if [[ "$dest" == "$src" ]]; then
    say "Skip source directory: $dest" >&2
    return 1
  fi

  if [[ "$DRY_RUN" == 1 ]]; then
    if [[ -e "$dest" ]]; then
      say "  [dry-run] replace $dest (rm -rf then extract)"
    else
      say "  [dry-run] create  $dest"
    fi
    return 0
  fi

  mkdir -p "$skills_dir"
  if [[ -e "$dest" ]]; then
    say "Overwriting existing install at $dest"
    rm -rf "$dest"
  fi
  mkdir -p "$dest"
  tar -C "$src" \
    --exclude './install.sh' \
    --exclude './install.ps1' \
    --exclude './install-macos-linux.sh' \
    --exclude './install-windows.ps1' \
    -cf - . | tar -C "$dest" -xf -

  if [[ -f "$dest/SKILL.md" ]]; then
    say "Installed $skill_name to $dest"
    return 0
  fi
  say "Install verification failed for $dest" >&2
  return 1
}

# ------------------------------------------------------------------ verify

declared_version() {
  local skills_dir="$1"
  local manifest="${skills_dir%/}/plaud-theme-shared/references/version-manifest.md"
  local fallback="${skills_dir%/}/plaud-theme-shared/SKILL.md"
  local v=""
  if [[ -f "$manifest" ]]; then
    v="$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$manifest" | sort -t. -k1,1 -k2,2n -k3,3n | tail -1 || true)"
  fi
  if [[ -z "$v" && -f "$fallback" ]]; then
    v="$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$fallback" | tail -1 || true)"
  fi
  [[ -z "$v" ]] && v="(not installed)"
  echo "$v"
}

verify_versions() {
  say ""
  local c path v
  if [[ -n "$TARGET" ]]; then
    say "Version check (declared version of plaud-theme-shared in the target):"
    for path in "${TARGETS[@]}"; do
      printf "  %-18s %s\n" "$(declared_version "$path")" "$path"
    done
  else
    say "Version check (declared version of plaud-theme-shared per client):"
    for c in "${CLIENT_NAMES[@]}"; do
      path="$(client_path "$c")"
      if [[ -n "$path" && -d "$path" ]]; then
        v="$(declared_version "$path")"
      else
        v="(skills dir absent)"
      fi
      printf "  %-8s %-18s %s\n" "$c" "$v" "$path"
    done
  fi
  say ""
  say "Expected for this package: ${PACKAGE_VERSION}"
  say "A declared version is only a declaration. The real proof the copy landed"
  say "is a tree diff, e.g. from this package root:"
  say ""
  say "  for c in cursor claude codex agents; do"
  say "    d=0"
  say "    for s in \$(ls -d plaud-theme-*/ | xargs -n1 basename); do"
  say "      diff -rq \"\$s\" \"\$HOME/.\$c/skills/\$s\" >/dev/null 2>&1 || d=\$((d+1))"
  say "    done"
  say "    echo \"\$c : \$d/10 mismatched\""
  say "  done"
}

# --------------------------------------------------------------------- main

discover_skill_sources
discover_targets

if [[ "${#TARGETS[@]}" -eq 0 ]]; then
  die "no install targets found. Use --target DIR or --create-missing cursor,claude,codex,agents"
fi

say "${PACKAGE_NAME} ${PACKAGE_VERSION}"
[[ "$DRY_RUN" == 1 ]] && say "*** DRY RUN — install targets, backups and skills are left untouched ***"
say ""
say "Skill sources (${#SOURCES[@]}):"
for s in "${SOURCES[@]}"; do say "  - $(basename "$s")"; done
say ""
say "Install targets (${#TARGETS[@]}):"
for t in "${TARGETS[@]}"; do say "  - $t"; done

if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
  say ""
  say "SKIPPED — skills dir does not exist (pass --create-missing to create):"
  for line in "${SKIPPED[@]}"; do
    say "  - ${line%%|*}  ->  ${line#*|}"
  done
  say ""
  say "These clients will NOT get the matrix. This is the main reason for"
  say "'I thought I installed it'."
fi
say ""

scan_legacy
validate_backup_dir
report_legacy
legacy_gate

ok=0
for t in "${TARGETS[@]}"; do
  for s in "${SOURCES[@]}"; do
    install_one_skill "$s" "$t" && ok=$((ok + 1)) || true
  done
done

say ""
if [[ "$DRY_RUN" == 1 ]]; then
  say "Dry run complete. $ok skill copy/copies would be installed."
else
  say "Done. Installed $ok skill copy/copies from ${PACKAGE_NAME} ${PACKAGE_VERSION}."
  verify_versions
fi

if [[ "$EXIT_UNSUPPORTED" == 1 ]]; then
  say ""
  say "################################################################"
  say "#  UNSUPPORTED STATE — legacy skill kept alongside the matrix   #"
  say "################################################################"
  say "The old 'plaud-shopify-theme' is still installed. Two specs now"
  say "match the same task. Exiting with status 3 so callers and CI can"
  say "detect this. Resolve with: $0 --retire-legacy --yes"
  exit 3
fi
