# Contributing to claude-bouncer

Thanks for wanting to help make Claude Code safer. This project is early (v0.1-alpha) and contributions are welcome.

## Adding a New Blocking Rule

1. Open `hooks/block-dangerous-commands` and add your regex pattern to the appropriate section.
2. Add test cases to `hooks/test-dangerous-commands-hook.sh` — at minimum one case that should be blocked and one that should be allowed.
3. Every new pattern needs a test case. No exceptions.

The hook logic is simple: `exit 0` means allow, `exit 2` means block. If you're not sure where your pattern fits, look at the existing groups in the hook and follow the same structure.

## Running the Test Suite

```bash
bash hooks/test-dangerous-commands-hook.sh
```

All 55+ test cases should pass. If you added new patterns, run this before opening a PR.

## Reporting False Positives

If a legitimate command got blocked, open an issue with:

- The exact command that was blocked (copy-paste, don't paraphrase)
- What you were trying to do
- Why you think it should be allowed

False positive fixes are high-priority — overly aggressive blocking erodes trust in the tool.

## Reporting Bypasses

If a dangerous command got through when it shouldn't have, open an issue with:

- The exact command that should have been blocked
- What makes it dangerous
- Suggested regex pattern if you have one

Please use the "bypass" label if available. These are treated as security issues.

## Code Style

- Bash. Keep it simple.
- No external dependencies beyond standard Unix tools (grep, sed, awk, etc.).
- Regex patterns should be readable — add a comment if the pattern isn't obvious.
- Match the style of what's already there.

## PRs Welcome For

- New dangerous command patterns
- False positive fixes
- Linux equivalents of macOS-specific blocks (launchctl, defaults, etc.)
- Better regex (fewer false positives, same coverage)
- Documentation improvements
- New test cases (even without code changes)

## What to Avoid

- Don't add blocking rules without test cases.
- Don't make the hook slow — it runs on every tool use.
- Don't add rules that block common development workflows without good reason.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Maintained by JustHereToHelp.
