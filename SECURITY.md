# Security Policy

## Important Context

claude-bouncer is **not a security boundary**. It is a set of guardrails designed to catch accidental dangerous commands issued by LLMs — think of it as a seatbelt, not an armored car.

Regex-based command blocking is inherently bypassable. We know this, we document known bypasses openly, and we do not treat them as vulnerabilities. If you find a clever new way to sneak a command past the regex filters, that is expected behavior, not a security flaw.

## What to Report

**Please do report (via GitHub Issues):**

- Hook execution failures — cases where the PreToolUse hook silently fails to run, crashes, or exits in a way that allows all commands through unchecked
- Logic errors — a rule that is supposed to block `rm -rf /` but does not due to a bug in the matching logic (distinct from a novel encoding bypass)
- Default configurations that are actively harmful or misleading about what they protect
- Bugs that cause claude-bouncer to interfere with safe commands it should allow

**No need to report:**

- Regex bypasses using encoding tricks, shell expansion, indirect execution, or command chaining — these are expected and documented in the project
- Anything that requires the user to deliberately disable or reconfigure the hooks
- General limitations of regex-based command filtering

## How to Report

Open a GitHub Issue. That's it.

This is a v0.1-alpha FOSS project under the MIT license. We do not operate a bug bounty program or private disclosure process. Bypasses are part of the documented threat model, so there is no need for coordinated disclosure — just file an issue and describe what you found.

If you believe you have found something that genuinely falls outside the "expected bypass" category (for example, a way to make the hook framework itself fail silently), please include:

- Steps to reproduce
- Expected vs actual behavior
- Your OS and shell environment

## Scope

claude-bouncer hooks into Claude Code's PreToolUse system to intercept bash commands before execution. It is scoped exclusively to that integration point. It does not sandbox processes, restrict file system access, manage permissions, or provide any form of isolation.

Users should not rely on claude-bouncer as their sole protection against destructive commands. It is one layer of defense — and a thin one by design.

## Contact

Maintained by JustHereToHelp. Reach out via GitHub Issues on this repository.
