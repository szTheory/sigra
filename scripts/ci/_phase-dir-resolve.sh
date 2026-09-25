# shellcheck shell=bash
#
# Resolve a phase directory that may have been archived by milestone close-out.
#
# /gsd-complete-milestone MOVES .planning/phases/<phase>/ to
# .planning/milestones/v<X.Y>-phases/<phase>/. Any CI guard that pins the live
# path breaks the moment its milestone is archived -- precisely when its subject
# becomes immutable history and the guard is most worth running.
#
# Usage: PHASE_DIR="$(resolve_phase_dir "$ROOT" 235-terminal-ratification-measured-not-read)"
#
# Prints the live path when it exists, else the newest archived bucket that has
# it, else the live path unchanged so the caller fails against the path it
# actually declares.
resolve_phase_dir() {
  local root="$1" phase="$2" live bucket
  live="$root/.planning/phases/$phase"
  if [ -d "$live" ]; then
    printf '%s\n' "$live"
    return 0
  fi
  while IFS= read -r bucket; do
    if [ -d "$bucket/$phase" ]; then
      printf '%s\n' "$bucket/$phase"
      return 0
    fi
  done < <(find "$root/.planning/milestones" -maxdepth 1 -type d -name 'v*-phases' 2>/dev/null | sort -r)
  printf '%s\n' "$live"
}
