#!/usr/bin/env bash
# PreToolUse safety hook for Bash. Reads JSON from stdin, denies destructive commands.
# Exit 2 + stderr blocks the tool call and feeds the message back to Claude.
#
# Philosophy (see .claude/rules/autonomy.md): this project runs in bypassPermissions
# so Claude can work unattended for hours. This hook is the ONLY command-level guardrail,
# so it blocks exactly one class of thing: commands that destroy the project, other
# files/folders, or system integrity. Everything else — builds, tests, installs, normal
# git, deleting build artifacts — is allowed without friction.
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

deny() {
  printf 'BLOCKED by validate-bash: %s\n' "$1" >&2
  printf 'If this was intentional and safe, run the step manually or narrow the command.\n' >&2
  exit 2
}

# --- Catastrophic filesystem deletion -------------------------------------------------
case "$cmd" in
  *"rm -rf /"*|*"rm -rf /*"*|*"rm -fr /"*|*"rm -rf ~"*|*"rm -rf \$HOME"*|*"rm -rf \"\$HOME\""*|*"rm -rf .."*|*"rm -rf /."*)
    deny "destructive rm targeting root, home, or a parent directory" ;;
esac
case "$cmd" in
  # Recursive rm on an absolute path is only allowed under the temp dirs.
  *"rm -rf /tmp/"*|*"rm -rf /var/folders/"*) ;;
  *"rm -rf /"*) deny "recursive rm on an absolute system path" ;;
esac

# --- Privilege escalation -------------------------------------------------------------
case "$cmd" in
  "sudo"|"sudo "*|*" sudo "*|*"|sudo "*|*"; sudo "*|*"&& sudo "*)
    deny "sudo escalation — run privileged steps yourself" ;;
esac

# --- Raw disk / filesystem writes -----------------------------------------------------
case "$cmd" in
  "dd "*|*" dd "*|*"|dd "*|*"; dd "*|*"&& dd "*) deny "raw dd disk write" ;;
esac
case "$cmd" in
  *"mkfs"*|*"fdisk"*|*"diskutil erase"*|*"diskutil reformat"*) deny "filesystem format / partition operation" ;;
esac

# --- Writes to device files (the harmless /dev/null|std*|tty|fd are allowed) -----------
case "$cmd" in
  *"> /dev/null"*|*">/dev/null"*|*"> /dev/std"*|*">/dev/std"*|*"> /dev/fd"*|*">/dev/fd"*|*"> /dev/tty"*|*">/dev/tty"*) ;;
  *"> /dev/"*|*">/dev/"*) deny "write to a device file" ;;
esac

# --- Fork bomb ------------------------------------------------------------------------
case "$cmd" in
  *":|:&"*|*":(){"*) deny "fork bomb" ;;
esac

# --- Recursive permission blow-out ----------------------------------------------------
case "$cmd" in
  *"chmod -R 777 /"*|*"chmod 777 -R /"*|*"chmod -R 777 ~"*|*"chmod -R 000 "*|*"chown -R "*" /"*)
    deny "recursive chmod/chown over a broad or system path" ;;
esac

# --- Remote-script-piped-to-shell (classic supply-chain vector) -----------------------
case "$cmd" in
  *"curl"*"| sh"*|*"curl"*"|sh"*|*"curl"*"| bash"*|*"curl"*"|bash"*|*"wget"*"| sh"*|*"wget"*"|sh"*|*"wget"*"| bash"*|*"wget"*"|bash"*)
    deny "piping a downloaded script straight into a shell — download, inspect, then run" ;;
esac

# --- Git history destruction ----------------------------------------------------------
case "$cmd" in
  *"git push"*"--force"*|*"git push"*" -f "*|*"git push -f"*|*"git push"*"--force-with-lease"*)
    case "$cmd" in
      *main*|*master*|*production*|*prod*|*release*)
        deny "force push to a protected branch" ;;
    esac ;;
esac
case "$cmd" in
  *"git push --mirror"*) deny "git push --mirror overwrites all remote refs" ;;
  *"git filter-branch"*|*"git filter-repo"*) deny "history rewrite across the whole repo" ;;
  *"git reset --hard"*|*"git clean -fdx"*|*"git clean -fdX"*|*"git checkout -- ."*|*"git checkout ."*|*"git restore ."*)
    deny "discards uncommitted work across the tree — commit/stash first, or scope to specific paths" ;;
esac

exit 0
