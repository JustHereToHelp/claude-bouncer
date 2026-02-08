# Recommended CLAUDE.md Security Rules

Add these rules to your project or global `CLAUDE.md` file to reinforce the hook-based protections with behavioral guardrails.

---

## File Delivery Rule

When any file is completed (document, report, analysis, spreadsheet, etc.):
- **ASK the user before opening any file.** Say: "File ready: [path] -- want me to open it?"
- **NEVER auto-open files** with the `open` command without explicit user confirmation.
- This applies to ALL completed files across ALL projects.

## Destructive Git Operations

- NEVER run destructive git commands (`push --force`, `reset --hard`, `checkout .`, `restore .`, `clean -f`, `branch -D`) unless the user explicitly requests these actions.
- NEVER skip hooks (`--no-verify`, `--no-gpg-sign`, etc.) unless the user explicitly requests it.
- NEVER force push to main/master -- warn the user if they request it.
- Always create NEW commits rather than amending, unless the user explicitly requests `git amend`.

## Sensitive Files

- NEVER read, display, or include contents of `.env` files, private keys, or credential files in responses.
- If a task requires environment variables, ask the user to provide the specific values needed rather than reading them from files.

## External Commands

- Do not use `sudo` for any operation.
- Do not pipe `curl` or `wget` output to shell interpreters.
- Do not modify system-level configs (`crontab`, `launchctl`, `defaults write`) without explicit user direction.
