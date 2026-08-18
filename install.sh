#!/bin/sh
# PLAUD Shopify Theme Matrix — one-command installer (macOS / Linux / WSL / Git Bash)
#
#   curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --ref v0.3.2
#
# Written in strict POSIX sh on purpose: `curl … | sh` IGNORES the shebang, so
# this file is executed by dash on Linux and by bash-in-POSIX-mode on macOS.
# No arrays, no [[ ]], no pipefail, no process substitution.
#
# Truncation safety: every statement lives inside a function and the only
# top-level action is the `main "$@"` call on the very last line. A curl
# transfer that dies halfway therefore feeds `sh` a file with no invocation in
# it — nothing runs at all. (`curl | sh` cannot report curl's exit status, so
# "do nothing when truncated" is the only defence available.)

set -eu

if [ -n "${ZSH_VERSION-}" ]; then
  emulate -L sh 2>/dev/null || true
  setopt shwordsplit 2>/dev/null || true
fi

INSTALLER_VERSION="1.0.0"
PACKAGE_NAME="plaud-theme-matrix"
DEFAULT_REPO="https://github.com/chovizzz/plaud-theme-matrix"
MARKER_NAME=".plaud-installed-ref"
INPROGRESS_NAME=".plaud-install-inprogress"
SKILL_PREFIX="plaud-theme-"
# Superseded single skill. Installing the matrix beside it produces routing
# competition: one task matches two different specs.
LEGACY_SKILLS="plaud-shopify-theme"
# Skills this package ships that do NOT carry the plaud-theme- prefix (bundled
# tool skills, see MATRIX.md). They are installed like any other skill; this list
# exists only so --check can still spot them as STALE after a rollback to a tag
# that predates them -- the prefix scan alone would never look at them, and the
# marker gets rewritten by that very rollback. Add a name here whenever a
# non-prefixed skill is added to the package root.
BUNDLED_SKILLS="yidian-draft-pr"
CLIENT_NAMES="cursor claude codex agents"

# --------------------------------------------------------------- usage

usage() {
  cat <<'EOF'
plaud-theme-matrix installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh
  curl -fsSL https://raw.githubusercontent.com/chovizzz/plaud-theme-matrix/main/install.sh | sh -s -- --ref v0.3.2
  ./install.sh --check

Content comes from a git TAG, downloaded as a tarball (no git required).
With no --clients, all four are used: cursor, claude, codex, agents.

Options:
  --ref TAG            Release tag to install (vMAJOR.MINOR.PATCH).
                       Default: the newest release tag of the repo. If that
                       cannot be resolved, the run FAILS — it never silently
                       falls back to a branch.
  --repo URL           Repo to install from. Default:
                       https://github.com/chovizzz/plaud-theme-matrix
                       A local path / file:// git repo is also accepted
                       (uses `git archive`; for mirrors and release rehearsal).
  --tarball FILE|URL   Install from an already-built tarball. Requires --ref
                       (recorded verbatim in the install marker).
  --source DIR         Install from a local checkout. Provenance is UNPROVEN
                       and is recorded as such in the marker.
  --clients LIST       Comma-separated subset of cursor,claude,codex,agents.
                       Narrowing this is how client drift happens.
  --create-missing LIST  Create the skills dir for the listed clients (or
                       `all`). Without it a client whose skills dir is absent
                       is SKIPPED and reported.
  --check              Verify what is installed instead of installing.
  --dry-run            Report every action, touch no install target.
  --retire-legacy      Archive -> verify -> remove superseded legacy skills
                       (plaud-shopify-theme), then install.
  --keep-legacy        Install alongside the legacy skill. Dual-spec, routing
                       ambiguous, UNSUPPORTED. Exits 3.
  --yes                Assume yes for prompts.
  -h, --help           This help.

--check reports, per client:
  * the tag / commit / install time recorded in .plaud-installed-ref
  * a file-by-file, CONTENT-level comparison against the ref's tree
  * skills that exist in the client but not in the ref — i.e. skills the
    release deleted and the client is still routing to
  * an interrupted install (a leftover .plaud-install-inprogress marker)

Exit codes:
  0  success
  1  usage error, or install/verify failure
  2  aborted: legacy skill present and not retired
  3  installed with --keep-legacy (dual-spec, unsupported)
  4  --check found a problem
EOF
}

# --------------------------------------------------------------- plumbing

say() { printf '%s\n' "$*"; }
# Progress goes to stderr, never stdout: acquire_tree() and friends return
# their result *on stdout*, so a say() inside one lands in the caller's
# command substitution and poisons the value (this broke every remote
# install: SRC_ROOT came back as "  fetching https://..." + the path).
progress() { printf '%s\n' "$*" >&2; }
warn() { printf '%s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

WORK=""
CLEANED=0
cleanup() {
  [ "$CLEANED" = 1 ] && return 0
  CLEANED=1
  # Release only the locks THIS process created. A lock left by another run is
  # never removed automatically — that is the whole point of it.
  if [ -n "$WORK" ] && [ -f "${WORK}/locks" ]; then
    while IFS= read -r _cl_l; do
      [ -n "$_cl_l" ] && rmdir "$_cl_l" 2>/dev/null || true
    done <"${WORK}/locks"
  fi
  if [ -n "$WORK" ] && [ -d "$WORK" ]; then rm -rf "$WORK" 2>/dev/null || true; fi
}
on_exit() { rc=$?; cleanup; exit "$rc"; }
on_signal() { cleanup; exit 130; }

need_tool() {
  command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"
}

ask_yes_no() {
  # `read` returns non-zero at EOF; under set -e that would kill the script
  # silently. An absent answer is always "no" — the safe direction.
  ans=""
  if ! read -r ans; then ans=""; say ""; fi
  case "$ans" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# ------------------------------------------------------------ path safety

# Every path this script creates into, extracts into or deletes from goes
# through here. "Contains the substring skills" is not good enough: the last
# component must be exactly `skills`, and NO ancestor may be a symlink — a
# symlinked ancestor lets a delete escape into a completely different tree.
validate_skills_dir() {
  d="$1"
  [ -n "$d" ] || { echo "empty path"; return 1; }
  [ "$d" != "/" ] || { echo "refusing the filesystem root"; return 1; }
  case "$d" in */) d="${d%/}" ;; esac
  [ -n "$d" ] || { echo "refusing the filesystem root"; return 1; }
  case "$d" in /*) : ;; *) echo "not an absolute path: $d"; return 1 ;; esac
  [ "$(basename "$d")" = "skills" ] || { echo "last path component must be exactly 'skills': $d"; return 1; }
  if [ -n "${HOME-}" ]; then
    [ "$d" != "${HOME%/}" ] || { echo "refusing the home directory: $d"; return 1; }
  fi
  walk="$d"
  while [ -n "$walk" ] && [ "$walk" != "/" ]; do
    if [ -L "$walk" ]; then
      echo "path traverses a symlink at '$walk': $d"; return 1
    fi
    up="$(dirname "$walk")"
    [ -n "$up" ] && [ "$up" != "$walk" ] || break
    walk="$up"
  done
  if [ -d "$d" ]; then
    real="$(cd -P "$d" 2>/dev/null && pwd -P)" || { echo "cannot resolve physical path of: $d"; return 1; }
    [ -n "$real" ] && [ "$real" != "/" ] || { echo "resolves to the filesystem root: $d"; return 1; }
    [ "$real" = "$d" ] || { echo "physical path differs from lexical path: $d -> $real"; return 1; }
  fi
  return 0
}

client_path() {
  case "$1" in
    cursor) printf '%s\n' "${HOME}/.cursor/skills" ;;
    claude) printf '%s\n' "${HOME}/.claude/skills" ;;
    codex)  printf '%s\n' "${HOME}/.codex/skills" ;;
    agents) printf '%s\n' "${HOME}/.agents/skills" ;;
    *) printf '%s\n' "" ;;
  esac
}

# ------------------------------------------------------------- tree snapshot

# Writes a canonical inventory of DIR to OUT, one entry per line:
#     d <relpath>
#     f- <relpath>      regular file
#     fx <relpath>      regular file, executable
#
# Fails closed on anything that is not a regular file or a directory
# (symlink, fifo, device, socket) and on paths containing a newline. `find`'s
# own exit status is checked outside any pipeline: a permission error that
# hides part of the tree must NOT be able to produce a "matching" inventory.
snapshot_tree() {
  _st_dir="$1"; _st_out="$2"; _st_label="${3:-$1}"
  _st_raw="${WORK}/snap.raw.$$"
  : >"$_st_out"
  ( cd "$_st_dir" 2>/dev/null && find . -print ) >"$_st_raw" 2>"${_st_raw}.err" || {
    warn "FAILED: cannot inventory $_st_label"
    sed 's/^/          /' <"${_st_raw}.err" >&2 || true
    rm -f "$_st_raw" "${_st_raw}.err"
    return 1
  }
  if [ -s "${_st_raw}.err" ]; then
    warn "FAILED: inventory of $_st_label reported errors (unreadable entries hide stale files)"
    sed 's/^/          /' <"${_st_raw}.err" >&2
    rm -f "$_st_raw" "${_st_raw}.err"
    return 1
  fi
  rm -f "${_st_raw}.err"
  _st_rc=0
  while IFS= read -r _st_p; do
    [ "$_st_p" = "." ] && continue
    # A newline inside a path would have split the line; the fragments then
    # (almost certainly) do not exist. Fail closed rather than mis-compare.
    if [ ! -e "${_st_dir}/${_st_p}" ]; then
      warn "FAILED: unreadable or newline-containing path in $_st_label: $_st_p"
      _st_rc=1; break
    fi
    if [ -L "${_st_dir}/${_st_p}" ]; then
      warn "FAILED: symlink not allowed in a skill tree ($_st_label): $_st_p"
      _st_rc=1; break
    elif [ -d "${_st_dir}/${_st_p}" ]; then
      printf 'd %s\n' "$_st_p" >>"$_st_out"
    elif [ -f "${_st_dir}/${_st_p}" ]; then
      if [ -x "${_st_dir}/${_st_p}" ]; then
        printf 'fx %s\n' "$_st_p" >>"$_st_out"
      else
        printf 'f- %s\n' "$_st_p" >>"$_st_out"
      fi
    else
      warn "FAILED: not a regular file or directory in $_st_label: $_st_p"
      _st_rc=1; break
    fi
  done <"$_st_raw"
  rm -f "$_st_raw"
  [ "$_st_rc" = 0 ] || return 1
  LC_ALL=C sort -o "$_st_out" "$_st_out" || return 1
  return 0
}

# Structural equality of two trees (paths + types + exec bit). Prints a diff.
compare_inventories() {
  _ci_a="$1"; _ci_b="$2"
  if cmp -s "$_ci_a" "$_ci_b"; then return 0; fi
  diff "$_ci_a" "$_ci_b" 2>/dev/null | sed 's/^/          /' >&2 || true
  return 1
}

# Byte-for-byte equality of every regular file listed in inventory INV.
compare_contents() {
  _cc_src="$1"; _cc_dst="$2"; _cc_inv="$3"
  _cc_rc=0
  while IFS= read -r _cc_line; do
    case "$_cc_line" in
      f*) _cc_p="${_cc_line#* }" ;;
      *) continue ;;
    esac
    if ! cmp -s "${_cc_src}/${_cc_p}" "${_cc_dst}/${_cc_p}"; then
      warn "          content differs: ${_cc_p}"
      _cc_rc=1
    fi
  done <"$_cc_inv"
  return "$_cc_rc"
}

# ------------------------------------------------------------- acquisition

# Owner/repo out of a GitHub URL.
repo_slug() {
  _rs="$1"
  _rs="${_rs%/}"
  _rs="${_rs%.git}"
  _rs="${_rs##*github.com/}"
  _rs="${_rs##*github.com:}"
  printf '%s\n' "$_rs"
}

is_local_repo() {
  case "$1" in
    file://*) return 0 ;;
    /*) [ -d "$1" ] && return 0; return 1 ;;
    *) return 1 ;;
  esac
}

local_repo_path() {
  case "$1" in file://*) printf '%s\n' "${1#file://}" ;; *) printf '%s\n' "$1" ;; esac
}

valid_ref() {
  case "$1" in
    v[0-9]*.[0-9]*.[0-9]*)
      printf '%s' "$1" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'
      ;;
    *) return 1 ;;
  esac
}

# Largest vMAJOR.MINOR.PATCH on stdin. Deliberately NOT `sort -V`: BSD sort on
# stock macOS has no -V, and lexical sort puts v0.10.0 before v0.2.0.
max_semver_tag() {
  awk '
    /^v[0-9]+\.[0-9]+\.[0-9]+$/ {
      t = substr($0, 2); n = split(t, a, ".")
      if (n != 3) next
      if (best == "" || a[1] > b1 || (a[1] == b1 && (a[2] > b2 || (a[2] == b2 && a[3] > b3)))) {
        best = $0; b1 = a[1] + 0; b2 = a[2] + 0; b3 = a[3] + 0
      }
    }
    END { if (best != "") print best }
  '
}

resolve_latest_tag() {
  _rlt_repo="$1"
  if is_local_repo "$_rlt_repo"; then
    need_tool git
    git ls-remote --tags --refs "$(local_repo_path "$_rlt_repo")" 2>/dev/null \
      | sed 's:.*refs/tags/::' | max_semver_tag
    return 0
  fi
  _slug="$(repo_slug "$_rlt_repo")"
  # 1) the newest published Release (a deliberate publication act)
  _t="$(curl -fsSL "https://api.github.com/repos/${_slug}/releases/latest" 2>/dev/null \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)"
  if [ -n "$_t" ] && valid_ref "$_t"; then printf '%s\n' "$_t"; return 0; fi
  # 2) fall back to the tag list
  curl -fsSL "https://api.github.com/repos/${_slug}/tags?per_page=100" 2>/dev/null \
    | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | max_semver_tag
  return 0
}

resolve_commit() {
  _rc_repo="$1"; _rc_ref="$2"
  if is_local_repo "$_rc_repo"; then
    git -C "$(local_repo_path "$_rc_repo")" rev-parse "${_rc_ref}^{commit}" 2>/dev/null && return 0
    printf '%s\n' "unknown(local-rev-parse-failed)"; return 0
  fi
  _slug="$(repo_slug "$_rc_repo")"
  _sha="$(curl -fsSL "https://api.github.com/repos/${_slug}/commits/${_rc_ref}" 2>/dev/null \
          | sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,40\}\)".*/\1/p' | head -1 || true)"
  if [ -n "$_sha" ]; then printf '%s\n' "$_sha"; else printf '%s\n' "unknown(api-unreachable)"; fi
}

# Fetch a tarball to $2. Handles http(s) via curl and plain paths via cp.
fetch_tarball() {
  _ft_url="$1"; _ft_out="$2"
  case "$_ft_url" in
    http://*|https://*|file://*|ftp://*)
      need_tool curl
      curl -fsSL --retry 2 -o "$_ft_out" "$_ft_url" || return 1
      ;;
    *)
      [ -f "$_ft_url" ] || { warn "tarball not found: $_ft_url"; return 1; }
      cp "$_ft_url" "$_ft_out" || return 1
      ;;
  esac
  [ -s "$_ft_out" ] || { warn "downloaded tarball is empty: $_ft_url"; return 1; }
  return 0
}

# Unpack $1 into a fresh dir and echo the single top-level directory inside it.
# The top-level name is `<repo>-<ref>` for codeload and `<prefix>` for
# git archive — never hard-coded, always discovered.
unpack_tarball() {
  _up_tar="$1"; _up_into="$2"
  mkdir -p "$_up_into" || return 1
  # Refuse absolute paths and any `..` component before extracting anywhere.
  _up_list="${WORK}/tarlist.$$"
  tar -tzf "$_up_tar" >"$_up_list" 2>/dev/null || { warn "cannot read tarball (corrupt or truncated download)"; return 1; }
  [ -s "$_up_list" ] || { warn "tarball is empty"; return 1; }
  if grep -q -e '^/' -e '^\.\./' -e '/\.\./' "$_up_list"; then
    warn "tarball contains an escaping path (absolute or ..) — refusing to extract"
    return 1
  fi
  tar -C "$_up_into" -xzf "$_up_tar" || { warn "extract failed"; return 1; }
  _up_top=""
  for _up_d in "$_up_into"/*; do
    [ -d "$_up_d" ] || continue
    if [ -n "$_up_top" ]; then warn "tarball has more than one top-level directory"; return 1; fi
    _up_top="$_up_d"
  done
  [ -n "$_up_top" ] || { warn "tarball has no top-level directory"; return 1; }
  printf '%s\n' "$_up_top"
  return 0
}

# Materialise the tree for REF into $WORK/trees/<ref> and echo the path.
# Cached: --check may need several refs but should fetch each only once.
acquire_tree() {
  _at_ref="$1"
  _at_dest="${WORK}/trees/${_at_ref}"
  if [ -d "${_at_dest}/tree" ]; then
    printf '%s\n' "$(cat "${_at_dest}/root")"
    return 0
  fi
  mkdir -p "$_at_dest" || return 1
  _at_tar="${_at_dest}/pkg.tar.gz"

  if [ -n "$OPT_SOURCE" ]; then
    [ -d "$OPT_SOURCE" ] || { warn "--source is not a directory: $OPT_SOURCE"; return 1; }
    _at_root="$(cd "$OPT_SOURCE" && pwd -P)" || return 1
    mkdir -p "${_at_dest}/tree"
    printf '%s\n' "$_at_root" >"${_at_dest}/root"
    printf '%s\n' "$_at_root"
    return 0
  fi

  if [ -n "$OPT_TARBALL" ]; then
    fetch_tarball "$OPT_TARBALL" "$_at_tar" || return 1
  elif is_local_repo "$OPT_REPO"; then
    need_tool git
    git -C "$(local_repo_path "$OPT_REPO")" archive --format=tar.gz \
      --prefix="${PACKAGE_NAME}-${_at_ref}/" -o "$_at_tar" "$_at_ref" 2>/dev/null \
      || { warn "git archive failed for ref ${_at_ref} in $OPT_REPO"; return 1; }
  else
    _slug="$(repo_slug "$OPT_REPO")"
    _url="https://codeload.github.com/${_slug}/tar.gz/refs/tags/${_at_ref}"
    progress "  fetching $_url"
    fetch_tarball "$_url" "$_at_tar" || {
      warn "download failed for ref ${_at_ref}."
      warn "  Check the tag exists: https://github.com/${_slug}/tags"
      return 1
    }
  fi

  _at_root="$(unpack_tarball "$_at_tar" "${_at_dest}/tree")" || return 1
  printf '%s\n' "$_at_root" >"${_at_dest}/root"
  printf '%s\n' "$_at_root"
  return 0
}

# Root-level directories holding a SKILL.md, one name per line. Dot-prefixed
# names are skipped so a .plaud-legacy-backup-* dir is never treated as a skill.
list_skills() {
  _ls_root="$1"
  for _ls_d in "$_ls_root"/*; do
    [ -d "$_ls_d" ] || continue
    _ls_n="$(basename "$_ls_d")"
    case "$_ls_n" in .*) continue ;; esac
    [ -f "$_ls_d/SKILL.md" ] || continue
    printf '%s\n' "$_ls_n"
  done
}

# ------------------------------------------------------------------ marker

marker_field() {
  # marker_field FILE KEY
  sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -1
}

marker_skills() {
  sed -n 's/^skill:[[:space:]]*//p' "$1" 2>/dev/null
}

write_marker() {
  _wm_dir="$1"; _wm_list="$2"
  _wm_f="${_wm_dir%/}/${MARKER_NAME}"
  _wm_tmp="${_wm_f}.tmp.$$"
  {
    printf '# %s install marker — written by install.sh %s\n' "$PACKAGE_NAME" "$INSTALLER_VERSION"
    printf '# Do not edit. --check treats this as a claim, never as proof;\n'
    printf '# the tree itself is always re-verified against the ref.\n'
    printf 'schema: 1\n'
    printf 'package: %s\n' "$PACKAGE_NAME"
    printf 'ref: %s\n' "$REF"
    printf 'commit: %s\n' "$COMMIT"
    printf 'source: %s\n' "$PROVENANCE"
    printf 'installed_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'installer_version: %s\n' "$INSTALLER_VERSION"
    printf 'skills_count: %s\n' "$(grep -c . "$_wm_list" 2>/dev/null || echo 0)"
    while IFS= read -r _wm_s; do
      [ -n "$_wm_s" ] || continue
      printf 'skill: %s\n' "$_wm_s"
    done <"$_wm_list"
  } >"$_wm_tmp" || return 1
  mv "$_wm_tmp" "$_wm_f" || return 1
  return 0
}

# ------------------------------------------------------------------ legacy

LEGACY_FOUND=""
LEGACY_LINKS=""

scan_legacy() {
  LEGACY_FOUND=""; LEGACY_LINKS=""
  while IFS= read -r _sl_t; do
    [ -n "$_sl_t" ] || continue
    for _sl_l in $LEGACY_SKILLS; do
      _sl_p="${_sl_t%/}/${_sl_l}"
      if [ -L "$_sl_p" ]; then
        LEGACY_LINKS="${LEGACY_LINKS}${_sl_p}
"
      elif [ -d "$_sl_p" ]; then
        LEGACY_FOUND="${LEGACY_FOUND}${_sl_p}
"
      fi
    done
  done <"$TARGETS_FILE"
}

legacy_total() {
  printf '%s%s' "$LEGACY_FOUND" "$LEGACY_LINKS" | grep -c . || true
}

report_legacy() {
  [ "$(legacy_total)" -eq 0 ] && return 0
  say ""
  say "################################################################"
  say "#  BLOCKING: superseded legacy skill(s) detected                #"
  say "################################################################"
  say ""
  say "This matrix REPLACES the single skill 'plaud-shopify-theme'."
  printf '%s' "$LEGACY_FOUND" | while IFS= read -r p; do [ -n "$p" ] && say "  - $p"; done
  printf '%s' "$LEGACY_LINKS" | while IFS= read -r p; do [ -n "$p" ] && say "  - $p   (symlink)"; done
  say ""
  say "Installing beside them means one Plaud theme task matches two different"
  say "specs. That is exactly what splitting the matrix removed, so this"
  say "installer refuses to install into a client that still has the old skill."
  say ""
  say "How to proceed:"
  say "  1. Retire them (archive -> verify -> remove), then install:"
  say "       install.sh --retire-legacy --yes"
  say "  2. Symlinks are never followed or deleted here; remove them by hand."
  say "  3. Knowingly accept a dual-spec, UNSUPPORTED environment:"
  say "       install.sh --keep-legacy"
  say ""
}

retire_legacy() {
  [ -n "$LEGACY_FOUND" ] || return 0
  printf '%s' "$LEGACY_FOUND" >"${WORK}/legacy.list"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    parent="$(dirname "$p")"
    name="$(basename "$p")"
    if ! why="$(validate_skills_dir "$parent")"; then
      say "  SKIP $p — parent is not a validated skills dir ($why)"; continue
    fi
    _is_legacy=0
    for l in $LEGACY_SKILLS; do [ "$name" = "$l" ] && _is_legacy=1; done
    [ "$_is_legacy" = 1 ] || { say "  SKIP $p — not in the legacy allowlist"; continue; }
    [ -L "$p" ] && { say "  SKIP $p — symlink"; continue; }
    real_parent="$(cd -P "$parent" 2>/dev/null && pwd -P)" || real_parent=""
    if [ -z "$real_parent" ] || [ "$real_parent" != "$parent" ]; then
      say "  SKIP $p — path resolves through a symlink"; continue
    fi
    backup_root="${parent}/.plaud-legacy-backup-${TIMESTAMP}"
    archive="${backup_root}/${name}.tar.gz"
    say "  archive: $p  ->  $archive"
    if [ "$OPT_DRY_RUN" = 1 ]; then
      say "  [dry-run] tar -czf then verify then rm -rf $p"; continue
    fi
    [ -e "$archive" ] && { warn "  SKIP $p — backup destination exists: $archive"; continue; }
    mkdir -p "$backup_root" || { warn "  SKIP $p — cannot create $backup_root"; continue; }
    if ! tar -C "$parent" -czf "$archive" "$name"; then
      warn "  ARCHIVE FAILED for $p — left in place, nothing removed."; continue
    fi
    if ! tar -tzf "$archive" >"${WORK}/arch.list" 2>/dev/null; then
      warn "  BACKUP VERIFICATION FAILED for $p (unreadable archive) — left in place."; continue
    fi
    if ! grep -q "^${name}/SKILL.md$" "${WORK}/arch.list"; then
      warn "  BACKUP VERIFICATION FAILED for $p (no SKILL.md) — left in place."; continue
    fi
    ( cd "$parent" && find "$name" -print ) | sed 's:/$::' | LC_ALL=C sort -u >"${WORK}/disk.list"
    sed 's:/$::' "${WORK}/arch.list" | LC_ALL=C sort -u >"${WORK}/arch.sorted"
    if [ -n "$(comm -13 "${WORK}/arch.sorted" "${WORK}/disk.list")" ]; then
      warn "  BACKUP VERIFICATION FAILED for $p (paths missing from archive) — left in place."; continue
    fi
    rm -rf "$p" || { warn "  REMOVE FAILED for $p"; continue; }
    say "  retired: $p  (restore: tar -C \"$parent\" -xzf \"$archive\")"
  done <"${WORK}/legacy.list"
  say ""
}

EXIT_UNSUPPORTED=0

legacy_gate() {
  [ "$(legacy_total)" -eq 0 ] && return 0
  if [ "$OPT_KEEP_LEGACY" = 1 ]; then
    say "--keep-legacy given: continuing anyway. Routing is now ambiguous and"
    say "the result is UNSUPPORTED. Fix later: install.sh --retire-legacy --yes"
    say ""
    EXIT_UNSUPPORTED=1
    return 0
  fi
  if [ "$OPT_RETIRE_LEGACY" != 1 ]; then
    if [ -t 0 ] && [ "$OPT_YES" != 1 ] && [ "$OPT_DRY_RUN" != 1 ]; then
      printf 'Archive and retire the legacy skill(s) now, then install? [y/N] '
      if ask_yes_no; then
        OPT_RETIRE_LEGACY=1; OPT_YES=1
      else
        say ""; say "ABORTED — nothing installed, nothing deleted."; exit 2
      fi
    else
      say "ABORTED — nothing installed, nothing deleted."
      [ "$OPT_DRY_RUN" = 1 ] && say "(dry run: a real run aborts here too, exit code 2)"
      exit 2
    fi
  fi
  if [ "$OPT_DRY_RUN" = 1 ]; then
    retire_legacy
    say "Dry run: retirement would run first, then the matrix would install."
    return 0
  fi
  retire_legacy
  scan_legacy
  if [ "$(legacy_total)" -gt 0 ]; then
    say "ABORTED — legacy skill(s) still present after retirement; nothing installed."
    exit 2
  fi
  return 0
}

# ----------------------------------------------------------------- install

# Copy SRC into DST via a temp archive file.
#
# Deliberately NOT `tar -cf - . | tar -xf -`: the receiving tar exits at the
# end-of-archive marker while the sender is still writing padding blocks, so
# the sender takes EPIPE and the pipeline reports failure on a perfectly good
# extract (reproducible on stock macOS bsdtar). A temp archive gives both ends
# an honest exit code — which is the whole point, since a genuinely failed
# extract must never be reported as installed.
copy_tree() {
  _ct_src="$1"; _ct_dst="$2"
  _ct_tar="$(mktemp "${WORK}/skill.XXXXXX")" || { warn "FAILED: cannot create temp archive"; return 1; }
  if ! tar -C "$_ct_src" \
      --exclude './install.sh' --exclude './install.ps1' \
      --exclude './install-macos-linux.sh' --exclude './install-windows.ps1' \
      -cf "$_ct_tar" . ; then
    rm -f "$_ct_tar"; warn "FAILED: cannot archive $_ct_src"; return 1
  fi
  if ! tar -C "$_ct_dst" -xf "$_ct_tar"; then
    rm -f "$_ct_tar"; warn "FAILED: extract into $_ct_dst failed"; return 1
  fi
  rm -f "$_ct_tar"
  return 0
}

# Install every skill into one client, as a transaction:
#   stage (nothing live is touched)  ->  verify staged trees
#   ->  mark in-progress  ->  swap  ->  verify live trees  ->  marker  ->  unmark
# A failure while staging leaves the client completely untouched. A failure or
# an uncatchable kill during the swap leaves .plaud-install-inprogress behind,
# and --check reports that client as an interrupted install rather than "ok".
install_client() {
  _ic_dir="$1"
  if ! why="$(validate_skills_dir "$_ic_dir")"; then
    warn "Refusing unsafe install target ($why)"; return 1
  fi

  if [ "$OPT_DRY_RUN" = 1 ]; then
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      if [ -e "${_ic_dir%/}/$s" ]; then say "  [dry-run] replace ${_ic_dir%/}/$s (stage, rm -rf, swap)"
      else say "  [dry-run] create  ${_ic_dir%/}/$s"; fi
    done <"$SKILLS_FILE"
    say "  [dry-run] write   ${_ic_dir%/}/${MARKER_NAME}"
    return 0
  fi

  # Two concurrent installs of different refs would interleave their swaps and
  # trample each other's in-progress marker. `mkdir` is atomic on every POSIX
  # filesystem, so it is the lock. A lock we did not create is NEVER removed
  # automatically: an abandoned lock has to be looked at by a human, because
  # the alternative is silently resuming on top of an unknown half-state.
  _ic_lock="${_ic_dir%/}/.plaud-install-lock"
  if ! mkdir "$_ic_lock" 2>/dev/null; then
    if [ -e "$_ic_lock" ]; then
      warn "FAILED: another install is running (or crashed) in $_ic_dir"
      warn "        Lock: $_ic_lock"
      warn "        If no installer is running, inspect the directory, then: rmdir \"$_ic_lock\""
    else
      warn "FAILED: cannot create the install lock in $_ic_dir"
    fi
    return 1
  fi
  printf '%s\n' "$_ic_lock" >>"${WORK}/locks"

  # Staging lives INSIDE the skills dir: same filesystem, so the swap is a
  # rename, not a second copy that can half-fail. Dot-prefixed so no client
  # ever scans it as a skill.
  _ic_stage="${_ic_dir%/}/.plaud-staging-${TIMESTAMP}-$$"
  rm -rf "$_ic_stage" 2>/dev/null || true
  mkdir -p "$_ic_stage" || { warn "FAILED: cannot create staging dir in $_ic_dir"; return 1; }

  _ic_rc=0
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    mkdir -p "${_ic_stage}/$s" || { warn "FAILED: cannot stage $s"; _ic_rc=1; break; }
    copy_tree "${SRC_ROOT}/$s" "${_ic_stage}/$s" || { _ic_rc=1; break; }
    snapshot_tree "${SRC_ROOT}/$s" "${WORK}/inv.src" "source/$s" || { _ic_rc=1; break; }
    grep -v -e ' \./install\.sh$' -e ' \./install\.ps1$' \
            -e ' \./install-macos-linux\.sh$' -e ' \./install-windows\.ps1$' \
            "${WORK}/inv.src" >"${WORK}/inv.src.f" || true
    snapshot_tree "${_ic_stage}/$s" "${WORK}/inv.stg" "staged/$s" || { _ic_rc=1; break; }
    if ! compare_inventories "${WORK}/inv.src.f" "${WORK}/inv.stg"; then
      warn "FAILED: staged $s does not match the package"; _ic_rc=1; break
    fi
    if ! compare_contents "${SRC_ROOT}/$s" "${_ic_stage}/$s" "${WORK}/inv.stg"; then
      warn "FAILED: staged $s differs in content from the package"; _ic_rc=1; break
    fi
  done <"$SKILLS_FILE"

  if [ "$_ic_rc" != 0 ]; then
    rm -rf "$_ic_stage" 2>/dev/null || true
    warn "Nothing was changed in $_ic_dir (failure happened before any live directory was touched)."
    return 1
  fi

  _ic_prog="${_ic_dir%/}/${INPROGRESS_NAME}"
  printf 'ref: %s\nstarted_at: %s\npid: %s\n' "$REF" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$$" >"$_ic_prog" \
    || { warn "FAILED: cannot write $_ic_prog"; rm -rf "$_ic_stage"; return 1; }

  while IFS= read -r s; do
    [ -n "$s" ] || continue
    _ic_dest="${_ic_dir%/}/$s"
    if [ -e "$_ic_dest" ] || [ -L "$_ic_dest" ]; then
      if [ -L "$_ic_dest" ]; then
        warn "FAILED: $_ic_dest is a symlink; refusing to touch it"; _ic_rc=1; break
      fi
      # The exit status of rm -rf is checked, and the removal is re-verified.
      # Historical failure: a chmod 500 parent made the delete fail, the script
      # still printed "Installed" and exited 0, and a reference deleted by the
      # new version survived and kept being routed to.
      if ! rm -rf "$_ic_dest"; then
        warn "FAILED: cannot remove $_ic_dest (read-only mount, wrong owner, chflags uchg, MDM lock?)"
        warn "        Refusing to overlay: a partial overlay leaves stale files from the old version."
        _ic_rc=1; break
      fi
      if [ -e "$_ic_dest" ]; then
        warn "FAILED: $_ic_dest still exists after rm -rf; refusing to overlay it"; _ic_rc=1; break
      fi
    fi
    if ! mv "${_ic_stage}/$s" "$_ic_dest"; then
      warn "FAILED: cannot move staged $s into place"; _ic_rc=1; break
    fi
    snapshot_tree "${SRC_ROOT}/$s" "${WORK}/inv.src" "source/$s" || { _ic_rc=1; break; }
    grep -v -e ' \./install\.sh$' -e ' \./install\.ps1$' \
            -e ' \./install-macos-linux\.sh$' -e ' \./install-windows\.ps1$' \
            "${WORK}/inv.src" >"${WORK}/inv.src.f" || true
    snapshot_tree "$_ic_dest" "${WORK}/inv.dst" "$_ic_dest" || { _ic_rc=1; break; }
    # "SKILL.md exists" cannot tell a fresh extract from a survivor of the
    # previous version. Compare the whole inventory instead: anything present
    # only in the destination is a stale leftover that keeps being routed to.
    if ! compare_inventories "${WORK}/inv.src.f" "${WORK}/inv.dst"; then
      warn "FAILED: $_ic_dest does not match the package after install."
      _ic_rc=1; break
    fi
    say "  installed $s"
  done <"$SKILLS_FILE"

  if [ "$_ic_rc" != 0 ]; then
    rm -rf "$_ic_stage" 2>/dev/null || true
    warn "PARTIAL INSTALL in $_ic_dir — $_ic_prog left in place as evidence."
    warn "  Re-run the installer after fixing the cause; --check reports this client as interrupted."
    return 1
  fi

  write_marker "$_ic_dir" "$SKILLS_FILE" || { warn "FAILED: cannot write install marker in $_ic_dir"; return 1; }
  rm -rf "$_ic_stage" 2>/dev/null || true
  rm -f "$_ic_prog" || { warn "FAILED: cannot clear $_ic_prog"; return 1; }
  return 0
}

# ------------------------------------------------------------------- check

check_client() {
  _ck_name="$1"; _ck_dir="$2"
  say ""
  say "── ${_ck_name}  (${_ck_dir})"
  if [ ! -d "$_ck_dir" ]; then
    say "   skills dir absent — matrix not installed"
    return 1
  fi
  if ! why="$(validate_skills_dir "$_ck_dir")"; then
    warn "   UNSAFE PATH: $why"
    return 1
  fi

  _ck_rc=0
  _ck_marker="${_ck_dir%/}/${MARKER_NAME}"
  # `-e || -L` on purpose, not `-f`: replacing the marker with a directory or a
  # dangling symlink must not read as "no interrupted install".
  if [ -e "${_ck_dir%/}/${INPROGRESS_NAME}" ] || [ -L "${_ck_dir%/}/${INPROGRESS_NAME}" ]; then
    say "   INTERRUPTED INSTALL: ${INPROGRESS_NAME} is still present"
    [ -f "${_ck_dir%/}/${INPROGRESS_NAME}" ] && sed 's/^/     /' "${_ck_dir%/}/${INPROGRESS_NAME}"
    _ck_rc=1
  fi
  # A leftover staging dir means a run died between staging and the swap — the
  # window where no in-progress marker exists yet.
  for _ck_sd in "${_ck_dir%/}"/.plaud-staging-*; do
    [ -e "$_ck_sd" ] || continue
    say "   INTERRUPTED INSTALL: leftover staging dir $(basename "$_ck_sd")"
    _ck_rc=1
  done
  if [ -e "${_ck_dir%/}/.plaud-install-lock" ]; then
    say "   LOCK PRESENT:  an install is running here, or one crashed and left"
    say "                  ${_ck_dir%/}/.plaud-install-lock behind"
    _ck_rc=1
  fi

  _ck_marker_ref=""
  if [ -e "$_ck_marker" ] || [ -L "$_ck_marker" ]; then
    if [ ! -f "$_ck_marker" ] || [ -L "$_ck_marker" ]; then
      say "   marker:        NOT A REGULAR FILE — unusable, provenance unproven"
      _ck_rc=1
    elif [ ! -r "$_ck_marker" ] || [ ! -s "$_ck_marker" ]; then
      say "   marker:        UNREADABLE OR EMPTY — provenance unproven"
      _ck_rc=1
    else
      _ck_marker_ref="$(marker_field "$_ck_marker" ref)"
      _ck_marker_commit="$(marker_field "$_ck_marker" commit)"
      say "   marker ref:    ${_ck_marker_ref:-<unset>}"
      say "   marker commit: ${_ck_marker_commit:-<unset>}"
      say "   installed at:  $(marker_field "$_ck_marker" installed_at)"
      say "   source:        $(marker_field "$_ck_marker" source)"
      if [ -z "$_ck_marker_ref" ]; then
        say "   marker:        HAS NO ref: FIELD — unusable, provenance unproven"
        _ck_rc=1
      elif [ "$_ck_marker_ref" = "local" ] && [ -n "$OPT_SOURCE" ]; then
        # Local-source rehearsal (RELEASING.md step 2). `local` is a reserved word,
        # not a ref: nothing is fetched for it and the marker never selects the
        # baseline — the operator did, on this command line. A forged `ref: local`
        # therefore buys nothing without --source, and any other non-tag ref still
        # fails below, so ba0cc41's "marker cannot pick a branch" boundary holds.
        :
      elif ! valid_ref "$_ck_marker_ref"; then
        # Without this, editing the marker to say `main` would make --check
        # fetch a branch and hold the client to it — exactly the "not a release"
        # boundary the installer refuses everywhere else.
        say "   marker ref:    NOT A RELEASE TAG (${_ck_marker_ref}) — refusing to compare against it"
        _ck_marker_ref=""
        _ck_rc=1
      fi
    fi
  else
    say "   marker:        MISSING — provenance unproven (installed by hand, or an older installer)"
    _ck_rc=1
  fi

  # Which ref do we hold this client to? An explicit --ref wins; otherwise the
  # client's own claim. A marker is a claim, never proof: the tree below is
  # re-verified byte for byte either way, so a hand-edited marker cannot make
  # a wrong tree pass.
  _ck_local_mode=0
  if [ -n "$OPT_SOURCE" ]; then
    _ck_local_mode=1
    _ck_ref="local"
    say "   LOCAL SOURCE CHECK — UNVERIFIED; compared against the CLI source"
    say "                  $(cd "$OPT_SOURCE" && pwd -P), not a release."
  fi
  [ "$_ck_local_mode" = 1 ] || _ck_ref="$OPT_REF"
  if [ "$_ck_local_mode" = 0 ] && [ -z "$_ck_ref" ]; then
    _ck_ref="$_ck_marker_ref"
    if [ -z "$_ck_ref" ]; then
      _ck_ref="$LATEST_TAG"
      [ -n "$_ck_ref" ] || { say "   cannot pick a ref to compare against; pass --ref"; return 1; }
      say "   comparing against latest tag ${_ck_ref} (no marker to go by)"
    fi
  fi
  if [ "$_ck_local_mode" = 0 ] && [ -n "$OPT_REF" ] && [ -n "$_ck_marker_ref" ] && [ "$OPT_REF" != "$_ck_marker_ref" ]; then
    say "   REF MISMATCH: client claims ${_ck_marker_ref}, you asked about ${OPT_REF}"
    _ck_rc=1
  fi
  if [ "$_ck_local_mode" = 0 ] && [ -z "$OPT_REF" ] && [ -n "$LATEST_TAG" ] && [ -n "$_ck_marker_ref" ] && [ "$_ck_marker_ref" != "$LATEST_TAG" ]; then
    say "   BEHIND: ${_ck_marker_ref} installed, ${LATEST_TAG} is the newest tag"
  fi

  # The marker's commit is a claim too. Compare it with the commit the tag
  # actually points at: a moved tag, or a hand-edited marker, shows up here.
  if [ "$_ck_local_mode" = 1 ]; then
    # The question local mode answers is "does this client equal the directory you
    # just named?", not "has that directory never moved". Report the drift, do not
    # overturn a byte-for-byte match with it.
    _ck_src_head="$(git -C "$OPT_SOURCE" rev-parse HEAD 2>/dev/null || true)"
    case "${_ck_marker_commit-}" in
      ""|unknown*) : ;;
      *)
        if [ -n "$_ck_src_head" ] && [ "$_ck_src_head" != "$_ck_marker_commit" ]; then
          say "   SOURCE REVISION CHANGED: marker says ${_ck_marker_commit}, source HEAD is ${_ck_src_head}"
          say "                  (not a failure in local mode — the file comparison below is the verdict)"
        fi
        ;;
    esac
  elif [ -n "$_ck_marker_ref" ] && [ -n "${_ck_marker_commit-}" ]; then
    case "$_ck_marker_commit" in
      unknown*) : ;;
      *)
        _ck_real_commit="$(resolve_commit "$OPT_REPO" "$_ck_marker_ref" 2>/dev/null || true)"
        case "$_ck_real_commit" in
          ""|unknown*) say "   commit check:  skipped (cannot resolve ${_ck_marker_ref} right now)" ;;
          *)
            if [ "$_ck_real_commit" != "$_ck_marker_commit" ]; then
              say "   COMMIT MISMATCH: marker says ${_ck_marker_commit}, ${_ck_marker_ref} now points at ${_ck_real_commit}"
              say "                    (a moved tag, a forged marker, or a different repo)"
              _ck_rc=1
            fi
            ;;
        esac
        ;;
    esac
  fi

  _ck_root="$(acquire_tree "$_ck_ref")" || { warn "   cannot obtain the tree for ${_ck_ref}"; return 1; }
  list_skills "$_ck_root" >"${WORK}/ref.skills" || true
  [ -s "${WORK}/ref.skills" ] || { warn "   ref ${_ck_ref} contains no skills"; return 1; }

  _ck_mismatch=0
  _ck_total=0
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    _ck_total=$((_ck_total + 1))
    _ck_dest="${_ck_dir%/}/$s"
    if [ -L "$_ck_dest" ]; then
      say "   ${s}: SYMLINK — a skill directory must be a real directory"
      _ck_mismatch=$((_ck_mismatch + 1)); continue
    fi
    if [ ! -d "$_ck_dest" ]; then
      say "   ${s}: MISSING"
      _ck_mismatch=$((_ck_mismatch + 1)); continue
    fi
    if ! snapshot_tree "${_ck_root}/$s" "${WORK}/inv.src" "ref/$s"; then
      _ck_mismatch=$((_ck_mismatch + 1)); continue
    fi
    grep -v -e ' \./install\.sh$' -e ' \./install\.ps1$' \
            -e ' \./install-macos-linux\.sh$' -e ' \./install-windows\.ps1$' \
            "${WORK}/inv.src" >"${WORK}/inv.src.f" || true
    if ! snapshot_tree "$_ck_dest" "${WORK}/inv.dst" "$_ck_dest"; then
      _ck_mismatch=$((_ck_mismatch + 1)); continue
    fi
    _ck_bad=0
    if ! compare_inventories "${WORK}/inv.src.f" "${WORK}/inv.dst"; then
      say "   ${s}: TREE DIFFERS (see diff above; '>' lines are stale leftovers)"
      _ck_bad=1
    elif ! compare_contents "${_ck_root}/$s" "$_ck_dest" "${WORK}/inv.dst"; then
      say "   ${s}: CONTENT DIFFERS (same filenames, different bytes)"
      _ck_bad=1
    fi
    [ "$_ck_bad" = 1 ] && _ck_mismatch=$((_ck_mismatch + 1))
  done <"${WORK}/ref.skills"

  say "   tree diff:     ${_ck_mismatch}/${_ck_total} mismatched vs ${_ck_ref}"
  [ "$_ck_mismatch" = 0 ] || _ck_rc=1

  # Stale skills: present in the client, absent from the ref. Two independent
  # sources, because either alone has a hole.
  #   1. what the marker says we installed  (catches a renamed/undeclared skill)
  #   2. anything named plaud-theme-* or on the legacy list (catches a missing
  #      or hand-deleted marker)
  # Skills belonging to other packages (reddit-*, lark-*, …) are never touched
  # and never reported.
  : >"${WORK}/stale.cand"
  [ -f "$_ck_marker" ] && marker_skills "$_ck_marker" >>"${WORK}/stale.cand"
  for _ck_d in "${_ck_dir%/}"/*; do
    [ -d "$_ck_d" ] || continue
    _ck_n="$(basename "$_ck_d")"
    case "$_ck_n" in
      ${SKILL_PREFIX}*) printf '%s\n' "$_ck_n" >>"${WORK}/stale.cand" ;;
      *)
        _ck_hit=0
        for l in $LEGACY_SKILLS $BUNDLED_SKILLS; do
          [ "$_ck_n" = "$l" ] && { printf '%s\n' "$_ck_n" >>"${WORK}/stale.cand"; _ck_hit=1; }
        done
        # Third source: the directory NAME can be changed, the skill's declared
        # `name:` cannot without breaking the skill. Renaming a dropped skill to
        # something outside the plaud-theme-* prefix would otherwise slip past
        # both the marker list and the prefix scan and keep being routed to.
        if [ "$_ck_hit" = 0 ] && [ -f "${_ck_d}/SKILL.md" ]; then
          _ck_decl="$(sed -n 's/^name:[[:space:]]*//p' "${_ck_d}/SKILL.md" 2>/dev/null | head -1 | tr -d '\r"'"'")"
          case "$_ck_decl" in
            ${SKILL_PREFIX}*) printf '%s\n' "$_ck_n" >>"${WORK}/stale.cand" ;;
            *) for b in $BUNDLED_SKILLS; do
                 [ "$_ck_decl" = "$b" ] && printf '%s\n' "$_ck_n" >>"${WORK}/stale.cand"
               done ;;
          esac
        fi
        ;;
    esac
  done
  LC_ALL=C sort -u "${WORK}/stale.cand" -o "${WORK}/stale.cand"
  LC_ALL=C sort -u "${WORK}/ref.skills" -o "${WORK}/ref.sorted"
  _ck_stale=0
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    if ! grep -qx "$s" "${WORK}/ref.sorted"; then
      if [ -d "${_ck_dir%/}/$s" ] || [ -L "${_ck_dir%/}/$s" ]; then
        say "   STALE SKILL:   ${s} — not in ${_ck_ref}, still installed and still routable"
        _ck_stale=$((_ck_stale + 1))
      fi
    fi
  done <"${WORK}/stale.cand"
  if [ "$_ck_stale" -gt 0 ]; then
    say "   ${_ck_stale} stale skill(s). Remove by hand: rm -rf \"${_ck_dir%/}/<name>\""
    _ck_rc=1
  fi

  [ "$_ck_rc" = 0 ] && say "   OK"
  return "$_ck_rc"
}

do_check() {
  say "${PACKAGE_NAME} — install check"
  say "repo: ${OPT_REPO}"
  LATEST_TAG=""
  if [ -z "$OPT_REF" ] && [ -z "$OPT_SOURCE" ] && [ -z "$OPT_TARBALL" ]; then
    LATEST_TAG="$(resolve_latest_tag "$OPT_REPO" || true)"
    [ -n "$LATEST_TAG" ] && say "newest tag: ${LATEST_TAG}"
  fi
  bad=0; total=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    c="${line%%|*}"; p="${line#*|}"
    total=$((total + 1))
    check_client "$c" "$p" || bad=$((bad + 1))
  done <"$CHECK_LIST"
  say ""
  if [ "$bad" -eq 0 ]; then
    say "All ${total} client(s) consistent."
    return 0
  fi
  say "PROBLEMS in ${bad} of ${total} client(s). See above."
  say "A 'BEHIND' line alone is informational; TREE/CONTENT DIFFERS, STALE SKILL,"
  say "MISSING marker and INTERRUPTED INSTALL are all real defects."
  return 4
}

# -------------------------------------------------------------------- main

OPT_REF=""
OPT_REPO="$DEFAULT_REPO"
OPT_TARBALL=""
OPT_SOURCE=""
OPT_CLIENTS=""
OPT_CREATE_MISSING=""
OPT_CHECK=0
OPT_DRY_RUN=0
OPT_RETIRE_LEGACY=0
OPT_KEEP_LEGACY=0
OPT_YES=0

REF=""
COMMIT=""
PROVENANCE=""
SRC_ROOT=""
LATEST_TAG=""
TIMESTAMP=""
TARGETS_FILE=""
SKILLS_FILE=""
CHECK_LIST=""

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --ref) OPT_REF="${2-}"; [ -n "$OPT_REF" ] || die "--ref needs a value"; shift 2 ;;
      --repo) OPT_REPO="${2-}"; [ -n "$OPT_REPO" ] || die "--repo needs a value"; shift 2 ;;
      --tarball) OPT_TARBALL="${2-}"; [ -n "$OPT_TARBALL" ] || die "--tarball needs a value"; shift 2 ;;
      --source) OPT_SOURCE="${2-}"; [ -n "$OPT_SOURCE" ] || die "--source needs a value"; shift 2 ;;
      --clients) OPT_CLIENTS="${2-}"; [ -n "$OPT_CLIENTS" ] || die "--clients needs a value"; shift 2 ;;
      --create-missing) OPT_CREATE_MISSING="${2-}"; [ -n "$OPT_CREATE_MISSING" ] || die "--create-missing needs a value"; shift 2 ;;
      --check) OPT_CHECK=1; shift ;;
      --dry-run) OPT_DRY_RUN=1; shift ;;
      --retire-legacy) OPT_RETIRE_LEGACY=1; shift ;;
      --keep-legacy) OPT_KEEP_LEGACY=1; shift ;;
      --yes|-y) OPT_YES=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) warn "Unknown option: $1"; usage >&2; exit 1 ;;
    esac
  done
}

resolve_ref() {
  if [ -n "$OPT_SOURCE" ]; then
    REF="${OPT_REF:-local}"
    PROVENANCE="local-checkout:${OPT_SOURCE} (UNVERIFIED PROVENANCE)"
    COMMIT="unknown(local-checkout)"
    if command -v git >/dev/null 2>&1 && [ -d "${OPT_SOURCE}/.git" ]; then
      COMMIT="$(git -C "$OPT_SOURCE" rev-parse HEAD 2>/dev/null || echo unknown)"
      if [ -n "$(git -C "$OPT_SOURCE" status --porcelain 2>/dev/null)" ]; then
        COMMIT="${COMMIT}-dirty"
      fi
    fi
    return 0
  fi
  if [ -n "$OPT_TARBALL" ]; then
    [ -n "$OPT_REF" ] || die "--tarball requires --ref (it is recorded in the install marker)"
    valid_ref "$OPT_REF" || die "--ref must look like vMAJOR.MINOR.PATCH: $OPT_REF"
    REF="$OPT_REF"
    PROVENANCE="tarball:${OPT_TARBALL}"
    COMMIT="unknown(tarball)"
    return 0
  fi
  if [ -n "$OPT_REF" ]; then
    valid_ref "$OPT_REF" || die "--ref must be a release tag vMAJOR.MINOR.PATCH: $OPT_REF"
    REF="$OPT_REF"
  else
    say "Resolving the newest release tag of ${OPT_REPO} …"
    REF="$(resolve_latest_tag "$OPT_REPO" || true)"
    if [ -z "$REF" ]; then
      # Never silently install a branch: an unreviewed main is not a release.
      die "could not resolve the newest release tag (offline, rate-limited, or no tags).
       Pass an explicit tag, e.g.:  --ref v0.3.2
       Tags: ${OPT_REPO}/tags"
    fi
    valid_ref "$REF" || die "resolved tag is not a release tag: $REF"
    say "Newest release tag: ${REF}"
  fi
  PROVENANCE="${OPT_REPO}"
  COMMIT="$(resolve_commit "$OPT_REPO" "$REF")"
  return 0
}

discover_targets() {
  : >"$TARGETS_FILE"
  : >"${WORK}/skipped"
  clients="$OPT_CLIENTS"
  [ -n "$clients" ] || clients="cursor,claude,codex,agents"
  oldifs="$IFS"; IFS=','
  for c in $clients; do
    IFS="$oldifs"
    c="$(printf '%s' "$c" | tr -d ' ')"
    [ -n "$c" ] || { IFS=','; continue; }
    p="$(client_path "$c")"
    if [ -z "$p" ]; then warn "Unknown client: $c"; IFS=','; continue; fi
    if [ -d "$p" ]; then
      printf '%s\n' "$p" >>"$TARGETS_FILE"
    elif should_create "$c"; then
      if [ "$OPT_DRY_RUN" = 1 ]; then
        say "  [dry-run] mkdir -p $p"
        printf '%s\n' "$p" >>"$TARGETS_FILE"
      else
        mkdir -p "$p" || die "cannot create $p"
        printf '%s\n' "$p" >>"$TARGETS_FILE"
      fi
    else
      printf '%s|%s\n' "$c" "$p" >>"${WORK}/skipped"
    fi
    IFS=','
  done
  IFS="$oldifs"
}

should_create() {
  case ",${OPT_CREATE_MISSING}," in
    *",all,"*) return 0 ;;
    *",$1,"*) return 0 ;;
  esac
  return 1
}

build_check_list() {
  : >"$CHECK_LIST"
  clients="$OPT_CLIENTS"
  [ -n "$clients" ] || clients="cursor,claude,codex,agents"
  oldifs="$IFS"; IFS=','
  for c in $clients; do
    IFS="$oldifs"
    c="$(printf '%s' "$c" | tr -d ' ')"
    [ -n "$c" ] || { IFS=','; continue; }
    p="$(client_path "$c")"
    [ -n "$p" ] && printf '%s|%s\n' "$c" "$p" >>"$CHECK_LIST"
    IFS=','
  done
  IFS="$oldifs"
}

main() {
  trap on_exit EXIT
  trap on_signal INT TERM HUP

  parse_args "$@"

  [ -n "${HOME-}" ] || die "HOME is not set; cannot locate any client skills directory."
  need_tool tar
  need_tool find
  need_tool sed
  need_tool awk
  need_tool cmp
  need_tool sort

  WORK="$(mktemp -d "${TMPDIR:-/tmp}/plaud-install.XXXXXX")" \
    || die "cannot create a temp directory (TMPDIR unset, full, or read-only?)"
  TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
  TARGETS_FILE="${WORK}/targets"
  SKILLS_FILE="${WORK}/skills"
  CHECK_LIST="${WORK}/checklist"

  if [ "$OPT_CHECK" = 1 ]; then
    build_check_list
    do_check
    exit $?
  fi

  say "${PACKAGE_NAME} installer ${INSTALLER_VERSION}"
  [ "$OPT_DRY_RUN" = 1 ] && say "*** DRY RUN — no install target is touched ***"
  resolve_ref
  say "ref:    ${REF}"
  say "commit: ${COMMIT}"
  say "source: ${PROVENANCE}"
  say ""

  SRC_ROOT="$(acquire_tree "$REF")" || die "cannot obtain the package tree for ${REF}"
  list_skills "$SRC_ROOT" >"$SKILLS_FILE" || true
  [ -s "$SKILLS_FILE" ] || die "no skill directories (dirs holding SKILL.md) found in ${REF}"

  say "Skills in ${REF} ($(grep -c . "$SKILLS_FILE")):"
  while IFS= read -r s; do [ -n "$s" ] && say "  - $s"; done <"$SKILLS_FILE"
  say ""

  discover_targets
  if [ ! -s "$TARGETS_FILE" ]; then
    say "No install targets found."
    if [ -s "${WORK}/skipped" ]; then
      say "These clients have no skills dir yet — re-run with --create-missing all:"
      while IFS= read -r l; do say "  - ${l%%|*}  ->  ${l#*|}"; done <"${WORK}/skipped"
    fi
    exit 1
  fi
  say "Install targets:"
  while IFS= read -r t; do say "  - $t"; done <"$TARGETS_FILE"
  if [ -s "${WORK}/skipped" ]; then
    say ""
    say "SKIPPED — skills dir does not exist (pass --create-missing all):"
    while IFS= read -r l; do say "  - ${l%%|*}  ->  ${l#*|}"; done <"${WORK}/skipped"
    say "These clients will NOT get the matrix. This is the main reason for"
    say "'I thought I installed it'."
  fi
  say ""

  scan_legacy
  report_legacy
  legacy_gate

  ok=0; total=0
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    total=$((total + 1))
    say "→ $t"
    if install_client "$t"; then ok=$((ok + 1)); fi
  done <"$TARGETS_FILE"

  say ""
  if [ "$OPT_DRY_RUN" = 1 ]; then
    say "Dry run complete. ${ok} of ${total} client(s) would be installed."
    exit 0
  fi

  # Counted per fully committed CLIENT, not per copied skill: a client whose
  # marker did not land is not a successful install even if every skill copied.
  if [ "$ok" -ne "$total" ]; then
    say "FAILED: ${ok} of ${total} clients installed ($((total - ok)) failed)."
    say "Do NOT treat this as a completed install. Fix the cause, re-run, then"
    say "verify with:  install.sh --check"
    exit 1
  fi

  say "Done. ${PACKAGE_NAME} ${REF} installed to ${ok} client(s)."
  say "Verify any time with:  install.sh --check"

  if [ "$EXIT_UNSUPPORTED" = 1 ]; then
    say ""
    say "UNSUPPORTED STATE — the legacy skill was kept alongside the matrix."
    say "Two specs now match the same task. Resolve with: install.sh --retire-legacy --yes"
    exit 3
  fi
  exit 0
}

main "$@"
# --- end of install.sh (if this line is missing, the download was truncated) ---
