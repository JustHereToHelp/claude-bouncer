# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0-alpha] - 2026-02-10

### Added

- Interactive macOS dialogs for override decisions (Block / Allow Once / Trust Session)
- Trust Session feature — auto-allows a pattern for the rest of the Claude Code session, scoped to parent PID, resets on restart
- Hard-block tier for catastrophic operations (fork bombs, disk wipes, base64 evasion) — no override possible
- Audit logging to `~/.claude_bouncer/audit.log` with timestamps and decision types
- `block-sensitive-dirs` hook — protects browser credential stores, SSH/GPG keys, personal comms, dev auth tokens, system auth files
- `block-password-managers` hook — hard-blocks 1Password CLI, Bitwarden CLI, macOS Keychain access, vault data directories
- Input sanitization for osascript dialog strings (prevents injection)
- POSIX-compatible locking (mkdir-based, replaces flock which isn't on macOS)
- Stale session file auto-cleanup on each hook invocation
- Test suites for sensitive-dirs and password-managers hooks
- Updated test suite for dangerous-commands with hard-block and session trust coverage

### Changed

- `block-dangerous-commands` now uses three-tier system: hard-block, prompt (dialog), allow
- `block-env-read` now shows interactive dialog instead of silent block
- Moved fork bombs, `diskutil eraseDisk`, `dd` to disk devices, and base64-to-bash from regular blocks to hard-block tier

## [0.1.0-alpha] - 2026-02-08

### Added

- `block-dangerous-commands` PreToolUse hook with 11 blocking categories:
  - Destructive operations
  - Privilege escalation
  - Exotic bypasses
  - Write + execute combos
  - Data exfiltration
  - Credential access
  - macOS system commands
  - Git destructive operations
  - Git remote tampering
  - Fork bombs
  - Dangerous misc
- `block-env-read` hook covering Bash and native Read tool for `.env` files
- `claude-safe` wrapper that strips sensitive env vars before launching Claude
- Test suite with 55+ test cases across all categories
- Example `settings.json` with `acceptEdits` mode and ~30 scoped Bash allows
- Example `CLAUDE.md` behavioral guardrails
- Honest threat model and documented known bypasses in README
