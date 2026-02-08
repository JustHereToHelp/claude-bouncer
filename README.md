# Claude Code Security Hardening Kit

A collection of PreToolUse hooks, permission configs, and wrapper scripts that add practical security guardrails to Claude Code -- without killing your productivity.

This started as a full security audit of a power user's setup. I run Claude Code all day with `acceptEdits` mode, MCP servers, background tasks, the works. I wanted guardrails that catch the real mistakes without making me click "approve" fifty times a session.

**This is a seatbelt, not an armored car.** It catches the 95% case. If you need a full sandbox, this isn't it -- but if you want to stop Claude from accidentally `rm -rf`-ing your home directory or posting your `.env` to the internet, keep reading.

---

## The Problem

Claude Code is incredibly powerful. It's also incredibly trusted.

If you've set up `Bash(*)` in your allow list, or you're running with `bypassPermissions`, Claude has essentially unrestricted access to your system. Every file, every command, every credential sitting in your environment variables -- it's all fair game.

But even if you're more careful -- say you've scoped your Bash allowlist to specific commands like `git`, `npm`, `python3` -- **you're probably not as safe as you think.**

[Formal's research](https://www.joinformal.com/blog/allowlisting-some-bash-commands-is-often-the-same-as-allowlisting-all-with-claude-code/) showed that when Write/Edit tools are also allowed (which they are in `acceptEdits` mode), Claude can edit Makefiles, `package.json` scripts, or shell configs to inject arbitrary commands *through* your "safe" allowed commands. You allow `npm run build` and Claude edits `package.json` to make `build` do whatever it wants.

The community consensus has settled on: **`acceptEdits` mode + PreToolUse hooks is the sweet spot.** You get fast iteration on file edits while hooks enforce the actual security boundary on Bash commands.

One more thing: the `deny` rules in `settings.json` have been historically buggy. GitHub issues [#6631](https://github.com/anthropics/claude-code/issues/6631) and [#6699](https://github.com/anthropics/claude-code/issues/6699) document cases where deny rules silently fail. **PreToolUse hooks are the only reliable enforcement mechanism right now.** They run your own code, so you can test them, debug them, and trust them.

---

## What's Included

### 1. `hooks/block-dangerous-commands` -- The Bouncer

A PreToolUse hook that inspects every Bash command before it runs. Think of it as a bouncer at the door -- it checks the guest list and turns away the troublemakers while letting your normal dev commands through untouched.

**What it blocks:**

- **Destructive operations** -- `rm -rf`, `xargs rm`, disk-level writes (`dd`, `mkfs`)
- **Privilege escalation** -- `sudo` anything
- **Exotic bypass patterns** -- The creative stuff:
  - `base64 | bash` (encoded command injection)
  - `bash -c` / `sh -c` (subshell execution)
  - `python -c` with `os.system`, `subprocess`, `shutil.rmtree`, `exec`, or `eval`
  - `find -exec` (arbitrary command execution through find)
- **Write + execute combos** -- Patterns that download then run:
  - `curl | bash`, `wget | sh`
  - `curl -o ... && chmod +x && ./`
- **Data exfiltration** -- Sending your stuff somewhere it shouldn't go:
  - `curl` with POST data (`-d`, `--data`, `-F`, `--form`)
  - `curl` targeting `.env`, `.pem`, `.key` files
  - `netcat` / `nc` / `ncat`
- **Credential access** -- Direct reads of sensitive files:
  - `.env` files (reading, sourcing, exporting)
  - SSH keys (`~/.ssh/id_rsa`, `id_ed25519`, `authorized_keys`)
  - Cloud creds (`~/.aws/credentials`, `~/.netrc`)
- **macOS-specific** -- System-level stuff that has no business in a dev session:
  - `osascript` (AppleScript can do anything)
  - `defaults write` (system preference modification)
  - `launchctl load` (installing persistent daemons)
  - `crontab -e` (scheduled task modification)
- **Git destructive** -- The commands you always regret:
  - `git push --force` / `git push -f`
  - `git reset --hard`
  - `git clean -f`
- **Git remote tampering** -- Prevents data exfil via git:
  - `git remote add`, `set-url`, `rename`, `remove`

**What passes through untouched:** `git status`, `npm install`, `python3 script.py`, `ls -la`, `grep`, `docker ps`, `brew install` -- all the stuff you actually use every day.

---

### 2. `hooks/block-env-read` -- The .env Guardian

The `block-dangerous-commands` hook catches Bash-based reads of `.env` files (`cat .env`, `source .env`, etc.), but Claude also has a native `Read` tool that bypasses Bash entirely. This hook covers that gap.

It intercepts both:
- Claude's **Read tool** when the target filename starts with `.env`
- **Bash commands** that use `cat`, `head`, `tail`, `less`, `more`, `bat`, `sed`, or `awk` on `.env` files

Two hooks, one goal: your secrets stay secret.

---

### 3. `claude-safe` -- The Clean Room Launcher

A wrapper script that strips sensitive environment variables before launching Claude Code. Instead of typing `claude`, you type `claude-safe`.

**What gets scrubbed:**

- **Cloud providers** -- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `GOOGLE_APPLICATION_CREDENTIALS`, `GOOGLE_API_KEY`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`
- **Dev tool tokens** -- `GITHUB_TOKEN`, `GH_TOKEN`, `GITLAB_TOKEN`, `NPM_TOKEN`, `PYPI_TOKEN`, `DOCKER_PASSWORD`, `HOMEBREW_GITHUB_API_TOKEN`
- **API keys** -- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_API_KEY`, `SENDGRID_API_KEY`, `TWILIO_AUTH_TOKEN`, `SLACK_TOKEN`, `TELEGRAM_BOT_TOKEN`
- **Databases** -- `DATABASE_URL`, `REDIS_URL`, `MONGODB_URI`
- **SSH agent** -- `SSH_AUTH_SOCK`, `SSH_AGENT_PID` (prevents remote key use)

It also sets `GIT_TERMINAL_PROMPT=1` so git asks for credentials interactively instead of silently using stored ones.

Your tools still work -- git, npm, aws CLI all fall back to their configured credential helpers. You just prevent Claude from *reading* those values from the environment.

---

### 4. `hooks/test-dangerous-commands-hook.sh` -- The Test Suite

55 test cases across 10 categories. Run this after making any changes to the hook scripts to verify nothing broke.

**Categories tested:**
- Compound commands (`&&`, `;`, pipes)
- Quoting and escaping edge cases
- Subshell and indirect execution
- Credential file access
- macOS-specific commands
- Git destructive operations
- Network exfiltration patterns
- Open command behavior (should pass to prompt, not hard-block)
- Exotic bypass patterns
- Safe commands (false positive checks)

```bash
# Run it
./hooks/test-dangerous-commands-hook.sh

# Expected output
# ================================
# PASSED: 55  |  FAILED: 0
# ================================
```

---

### 5. `example-settings.json` -- Recommended Permissions

The exact `settings.json` permissions block and PreToolUse hook entries you need. Copy this into your `~/.claude/settings.json`.

Key points:
- `acceptEdits: true` auto-approves file Read/Write/Edit operations
- The `allow` list covers common dev commands so you're not clicking "approve" constantly
- Every Bash command not in the allow list triggers a manual prompt
- The PreToolUse hooks run *before* even allowed commands, so dangerous patterns get caught regardless

---

### 6. `example-claude-md-rules.md` -- Behavioral Guardrails

CLAUDE.md rules that reinforce the technical controls with behavioral ones:
- **File delivery rule** -- Claude must ask before opening any file (prevents `open malware.app` surprises)
- **Git safety** -- No force push, no hard reset, no skipping hooks unless explicitly asked
- **Sensitive file handling** -- Never read or display `.env` contents
- **External command limits** -- No `sudo`, no `curl | bash`, no system config changes

---

## What's NOT Included (and Why)

- **Path-based file access blocking** -- Too much maintenance. Every new project means updating path rules. The hooks cover the dangerous patterns without needing to know your directory structure.
- **Full sandbox / VM isolation** -- That's a different threat model. This is for devs who want guardrails on their daily driver, not a secure enclave.
- **PII scanner** -- Too many false positives, especially if you work with financial data, user records, or anything with numbers in it.
- **AST-level shell parser** -- You could parse every command into an AST and analyze it properly. You could also spend three weeks building that instead of shipping your actual project. Regex catches the 95% case.

---

## Known Limitations (Honest)

Let's be real about what this doesn't cover:

- **Regex-based blocking can be bypassed with creative encoding.** If someone really wants to craft a command that evades the patterns, they probably can. This catches accidental danger and obvious attack patterns, not a determined adversary.
- **Makefile injection still works.** If Write/Edit is allowed (and it is in `acceptEdits` mode), Claude can edit a `Makefile` or `package.json` to inject commands that run through otherwise-safe allowed commands. This is a fundamental limitation documented in [Formal's research](https://www.joinformal.com/blog/allowlisting-some-bash-commands-is-often-the-same-as-allowlisting-all-with-claude-code/). The hooks reduce the attack surface but don't eliminate it.
- **Remote sessions (CCC/Telegram) are unprotected.** If you're running Claude Code via remote control with `--dangerously-skip-permissions`, these hooks don't run. That flag means what it says.
- **`claude-safe` is opt-in.** You have to remember to use it (or alias it). If you just type `claude`, your env vars are still exposed.
- **Env var scrubbing doesn't affect credential helpers.** Git credential helpers, macOS Keychain, and other system-level credential stores are not touched. The scrubbing only removes what's in the shell environment.

---

## Installation

### Step 1: Copy the hook scripts

```bash
# Copy hooks to your bin directory (or wherever you keep scripts)
cp hooks/block-dangerous-commands ~/bin/
cp hooks/block-env-read ~/bin/
cp hooks/test-dangerous-commands-hook.sh ~/bin/
cp claude-safe ~/bin/

# Make them executable
chmod +x ~/bin/block-dangerous-commands
chmod +x ~/bin/block-env-read
chmod +x ~/bin/test-dangerous-commands-hook.sh
chmod +x ~/bin/claude-safe
```

### Step 2: Configure settings.json

Add the hook entries and permissions to your `~/.claude/settings.json`. See `example-settings.json` for the full config -- the key parts are:

```json
{
  "permissions": {
    "acceptEdits": true,
    "allow": [
      "Bash(git status)",
      "Bash(git diff*)",
      "Bash(npm install*)",
      "Bash(npm run*)",
      "..."
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/bin/block-dangerous-commands"
          }
        ]
      },
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "~/bin/block-env-read"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/bin/block-env-read"
          }
        ]
      }
    ]
  }
}
```

**Important:** Update the command paths to match where you actually put the scripts.

### Step 3: Add CLAUDE.md rules

Copy the rules from `example-claude-md-rules.md` into your project or global `~/.claude/CLAUDE.md` file.

### Step 4: Optionally alias claude to claude-safe

```bash
# Add to your .bashrc / .zshrc
alias claude="~/bin/claude-safe"
```

### Step 5: Run the test suite

```bash
~/bin/test-dangerous-commands-hook.sh
```

You should see 55 passed, 0 failed. If anything fails, check that the hook script path in the test file matches where you installed it.

---

## Contributing

This started as one person's security audit. It's not perfect. Help make it better.

- **Found a bypass?** That's actually valuable. Please report it as an issue so we can add a pattern for it.
- **False positive?** If the hooks are blocking a legitimate command you use regularly, open an issue with the command and we'll figure out how to allow it safely.
- **New blocked patterns?** Submit a PR. Include a test case.
- **Your own hooks?** Share them. The more eyes on this, the better.
- **Different OS?** The macOS-specific blocks might need Linux equivalents. PRs welcome.

The goal isn't to build Fort Knox. It's to make the default Claude Code experience meaningfully safer for power users who don't want to give up productivity.

---

## Credits

- Security audit and implementation by Claude (Opus 4.6) + human direction
- Bash allowlist bypass research: [Formal](https://www.joinformal.com/blog/allowlisting-some-bash-commands-is-often-the-same-as-allowlisting-all-with-claude-code/)
- Community discussion and best practices from [Claude Code GitHub issues](https://github.com/anthropics/claude-code/issues)
- Cross-verification by GPT-5.2 and Grok-4 via HydraMCP

---

## License

MIT. Use it, fork it, make it better.
