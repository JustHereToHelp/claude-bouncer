# claude-bouncer

> **v0.2-alpha** — Safety guardrails for Claude Code. Not a sandbox. A bouncer.

PreToolUse hooks that check every tool use at the door before it runs. Blocks the stuff that can ruin your day — `rm -rf`, credential reads, data exfil, privilege escalation — while letting normal dev commands through untouched.

v0.2 adds interactive macOS dialogs, session-scoped trust, a hard-block tier for catastrophic commands, audit logging, and two new hooks for sensitive directories and password managers.

**This is a seatbelt, not an armored car.**

---

## Threat Model (Read This First)

**What claude-bouncer IS:**
- Guardrails against accidental destructive commands by an LLM
- A first-line filter that catches common foot-guns and obvious attack patterns
- A practical improvement over `Bash(*)` with `bypassPermissions` (which is no protection at all)

**What claude-bouncer is NOT:**
- A security boundary against adversarial attacks
- A sandbox, container, or isolation layer
- Protection against a determined attacker who knows your setup
- A replacement for proper environment isolation if you handle sensitive data

**Designed for:** Power users running Claude Code on their daily-driver machine who want to reduce the chance of Claude accidentally destroying files, leaking credentials, or running dangerous commands. If you need real isolation, use a container.

---

## The Problem

Claude Code with `Bash(*)` + `bypassPermissions` = unrestricted system access. Every file, every command, every credential in your environment variables.

Even scoped Bash allowlists aren't safe. [Formal's research](https://www.joinformal.com/blog/allowlisting-some-bash-commands-is-often-the-same-as-allowlisting-all-with-claude-code/) showed that when Write/Edit tools are also allowed, Claude can edit Makefiles or `package.json` to inject arbitrary commands through otherwise "safe" allowed commands.

The `deny` rules in `settings.json` have also been [historically](https://github.com/anthropics/claude-code/issues/6631) [buggy](https://github.com/anthropics/claude-code/issues/6699). **PreToolUse hooks are the only reliable enforcement mechanism** — they run your own code, so you can test and trust them.

Community consensus: **`acceptEdits` mode + PreToolUse hooks** is the sweet spot.

---

## How It Works (v0.2)

When a hook catches something suspicious, you get a native macOS dialog with three choices:

- **Block** (default) — Command rejected. Auto-blocks after 30 seconds if you don't respond.
- **Allow Once** — Let this specific command through. Logged and forgotten.
- **Trust Session** — Auto-allow this pattern for the rest of your Claude Code session. Scoped to your terminal's parent PID, so it resets when you restart Claude. No stale permissions hanging around.

Some commands skip the dialog entirely. Fork bombs, `diskutil eraseDisk`, `dd` targeting disk devices, and base64-piped-to-bash are **hard-blocked** — no override, no dialog, no discussion.

Every decision gets logged to `~/.claude_bouncer/audit.log` with a timestamp, the tool, the command, and what happened (HARD_BLOCKED, BLOCKED, ALLOWED_ONCE, TRUSTED_SESSION).

---

## What's Included

### 1. `hooks/block-dangerous-commands` — The Bouncer

Inspects every Bash command before it runs. Turns away troublemakers, waves through regulars.

**Hard-blocks (no override):**

- **Fork bombs** — `:(){ :|:& };:`
- **Disk destruction** — `diskutil eraseDisk`, `dd` targeting `/dev/disk*` or `/dev/sd*`
- **Base64 evasion** — `base64 -d | bash`, `base64 --decode | sh`

**Prompts (dialog with override):**

- **Destructive ops** — `rm -rf`, `rm -r -f` (split flags), `xargs rm`, `mkfs`, `find -delete`, `truncate`, recursive `chmod`
- **Privilege escalation** — `sudo`
- **Exotic bypasses** — `bash -c`, `sh -c`, `python -c` with dangerous imports, `node -e`, `find -exec`
- **Write + execute combos** — `curl | bash`, `wget | sh`, download-then-execute chains
- **Data exfiltration** — `curl POST/upload`, `netcat`, `curl` targeting `.env`/`.pem`/`.key`
- **Credential access** — `.env` files (read/source/export), SSH keys, `~/.aws/credentials`, `~/.netrc`
- **macOS system** — `osascript`, `defaults write`, `launchctl load`, `crontab`
- **Git destructive** — `push --force`, `reset --hard`, `clean -f`
- **Git remote tampering** — `remote add/set-url/rename/remove`

**Passes through:** `git status`, `npm install`, `python3 script.py`, `ls`, `grep`, `docker ps`, `brew install` — your normal workflow is untouched.

### 2. `hooks/block-env-read` — The .env Guardian

The bouncer catches Bash-based reads of `.env` files, but Claude also has a native `Read` tool that bypasses Bash entirely. This hook covers that gap for both tools. Dialog override available.

### 3. `hooks/block-sensitive-dirs` — The Locksmith

Blocks access to sensitive system directories across all Claude tools — Bash, Read, Edit, Write, and Glob. If Claude tries to poke around in any of these, it gets the dialog.

**Protects:**
- Browser credential stores — Chrome, Firefox, Safari, Arc, Brave, Edge, Opera (login data, cookies, local state)
- SSH and GPG keys — `~/.ssh`, `~/.gnupg`
- Personal communications — Messages, Mail databases
- Dev auth tokens — `~/.docker/config.json`, `~/.npmrc`, `~/.pypirc`
- System auth files — `/etc/shadow`, `/etc/master.passwd`

### 4. `hooks/block-password-managers` — The Vault Door

Hard-blocks all access to password manager data. No dialog, no override. There is no good reason for Claude to touch your vault.

**Covers:**
- 1Password CLI (`op`) and Bitwarden CLI (`bw`)
- macOS Keychain access — `security find-generic-password`, `security dump-keychain`, etc.
- Password manager data directories and browser extensions
- Process inspection targeting vault processes (`pgrep`, `ps aux | grep` for 1Password/Bitwarden)

### 5. `claude-safe` — The Clean Room

Strips sensitive environment variables before launching Claude. Type `claude-safe` instead of `claude`.

Scrubs: `AWS_*`, `GITHUB_TOKEN`, `NPM_TOKEN`, `SSH_AUTH_SOCK`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `STRIPE_*`, `TELEGRAM_*`, `DATABASE_URL`, and more. Your tools still work through their credential helpers — you just prevent Claude from reading tokens out of the environment.

### 6. Test Suites

150+ test cases across three hook-specific test files, including false-positive checks on safe commands. Run after any hook changes.

### 7. `example-settings.json` — Recommended Permissions

`acceptEdits` mode with ~30 scoped Bash allows. Common dev commands auto-approve; everything else prompts.

### 8. `example-claude-md-rules.md` — Behavioral Guardrails

CLAUDE.md rules that reinforce the technical controls: ask before opening files, no force push, no credential reads.

---

## Known Bypasses (Honest)

We tested adversarial bypass techniques. Some we caught and patched. Some we can't catch with regex. Here they are:

**Bypasses we CANNOT catch (fundamental regex limitations):**

| Technique | Example | Why it bypasses |
|-----------|---------|-----------------|
| Variable indirection | `cmd=rm; $cmd -rf /` | Regex sees variable assignment, not the resolved command |
| Generic pipe to shell | `echo "payload" \| sh` | Can't block all `echo X \| sh` without blocking legitimate pipes |
| Obfuscated Python | `python3 -c "__import__(chr(111)+chr(115))"` | Infinite ways to encode imports |
| Clean env shell spawn | `env -i bash` | Spawning a shell is sometimes legitimate |
| Makefile/package.json injection | Edit build file, then `make` | Fundamental issue with allowlists + Write access ([Formal](https://www.joinformal.com/blog/allowlisting-some-bash-commands-is-often-the-same-as-allowlisting-all-with-claude-code/)) |

**Why this is still useful:** These bypasses require *intentional evasion*. Claude doesn't accidentally use variable indirection or obfuscated Python imports. The bouncer catches the commands Claude actually generates when something goes wrong — which is the realistic threat for most users.

**If you need protection against intentional evasion:** Use a container, a separate macOS user account, or network egress controls (LuLu / Little Snitch). The bouncer is one layer, not the whole defense.

---

## What's NOT Included (and Why)

- **Path-based file access blocking** — Maintenance burden for multi-project workflows. The sensitive-dirs hook covers the high-value targets.
- **Full sandbox / VM** — Different threat model. This is guardrails for daily drivers.
- **PII scanner** — Too many false positives for financial/data work.
- **AST-level shell parser** — Would be more robust but dramatically more complex. Regex catches the 95% case. Parser-based mode is on the roadmap.

---

## Installation

### Step 1: Copy scripts

```bash
cp hooks/block-dangerous-commands ~/bin/
cp hooks/block-env-read ~/bin/
cp hooks/block-sensitive-dirs ~/bin/
cp hooks/block-password-managers ~/bin/
cp claude-safe ~/bin/
chmod +x ~/bin/block-dangerous-commands ~/bin/block-env-read ~/bin/block-sensitive-dirs ~/bin/block-password-managers ~/bin/claude-safe
```

### Step 2: Add hooks to settings.json

Add PreToolUse entries to your `~/.claude/settings.json` (see `example-settings.json` for the full config):

```json
"PreToolUse": [
  {
    "matcher": "",
    "hooks": [{ "type": "command", "command": "/path/to/bin/block-dangerous-commands" }]
  },
  {
    "matcher": "",
    "hooks": [{ "type": "command", "command": "/path/to/bin/block-env-read" }]
  },
  {
    "matcher": "",
    "hooks": [{ "type": "command", "command": "/path/to/bin/block-sensitive-dirs" }]
  },
  {
    "matcher": "",
    "hooks": [{ "type": "command", "command": "/path/to/bin/block-password-managers" }]
  }
]
```

### Step 3: Add CLAUDE.md rules

Copy rules from `example-claude-md-rules.md` into your `~/.claude/CLAUDE.md`.

### Step 4: (Optional) Alias claude to claude-safe

```bash
# Add to .zshrc / .bashrc
alias claude="~/bin/claude-safe"
```

### Step 5: Run the test suites

```bash
bash hooks/test-dangerous-commands-hook.sh
bash hooks/test-sensitive-dirs-hook.sh
bash hooks/test-password-managers-hook.sh
```

---

## Uninstall

1. Remove the hooks from your `~/.claude/settings.json` (delete the PreToolUse entries that reference the bouncer scripts)
2. Remove the scripts:
```bash
rm ~/bin/block-dangerous-commands ~/bin/block-env-read ~/bin/block-sensitive-dirs ~/bin/block-password-managers ~/bin/claude-safe
```
3. Remove any CLAUDE.md rules you added from `example-claude-md-rules.md`
4. (Optional) Remove the claude-safe alias from your `.zshrc` / `.bashrc`
5. (Optional) Clean up bouncer data:
```bash
rm -rf ~/.claude_bouncer
```

That's it. No config files are modified outside of `settings.json` and your shell profile.

---

## Roadmap

- [ ] Parser-based mode (AST analysis instead of regex for higher-confidence blocking)
- [ ] Allowlist mode (per-project policy files)
- [ ] Container recipe (Docker/Podman for real isolation)
- [ ] Linux support (macOS-specific blocks and dialogs need equivalents)
- [ ] CI pipeline for automated testing
- [ ] More bypass tests and patterns

---

## Contributing

This is v0.2-alpha. Help make it better.

- **Found a bypass?** That's valuable — [open an issue](../../issues) so we can decide whether to patch or document it
- **False positive?** Report the command that got blocked and we'll figure out how to allow it safely
- **New patterns?** PRs welcome — include a test case
- **Different OS?** Linux equivalents of the macOS blocks would be great
- **Better approach?** If you know how to do parser-based shell analysis in a lightweight hook, we want to hear from you

The goal isn't Fort Knox. It's making Claude Code meaningfully safer for power users without killing productivity.

---

## License

MIT — use it, fork it, make it better.
