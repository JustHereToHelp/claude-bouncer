# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
