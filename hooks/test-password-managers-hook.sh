#!/bin/bash
# Tests for block-password-managers hook
HOOK="${HOOK:-$(dirname "$0")/block-password-managers}"

pass=0
fail=0

run_test() {
  local desc="$1"
  local cmd="$2"
  local expect="$3"  # "block" or "pass"

  result=$(echo "$cmd" | "$HOOK" 2>&1)
  code=$?

  if [ "$expect" = "block" ] && [ $code -eq 2 ]; then
    echo "  BLOCKED: $desc"
    ((pass++))
  elif [ "$expect" = "pass" ] && [ $code -eq 0 ]; then
    echo "  PASSED: $desc"
    ((pass++))
  elif [ "$expect" = "block" ] && [ $code -eq 0 ]; then
    echo "  MISSED: $desc"
    ((fail++))
  elif [ "$expect" = "pass" ] && [ $code -eq 2 ]; then
    echo "  FALSE POS: $desc — $result"
    ((fail++))
  fi
}

echo "=== PASSWORD MANAGER CLIs ==="
run_test "op CLI signin" '{"tool_name":"Bash","tool_input":{"command":"op signin"}}' "block"
run_test "op CLI item get" '{"tool_name":"Bash","tool_input":{"command":"op item get \"Bank Login\""}}' "block"
run_test "op CLI list" '{"tool_name":"Bash","tool_input":{"command":"op item list"}}' "block"
run_test "bw CLI login" '{"tool_name":"Bash","tool_input":{"command":"bw login"}}' "block"
run_test "bw CLI unlock" '{"tool_name":"Bash","tool_input":{"command":"bw unlock --raw"}}' "block"
run_test "bw CLI list items" '{"tool_name":"Bash","tool_input":{"command":"bw list items"}}' "block"
run_test "op in pipeline" '{"tool_name":"Bash","tool_input":{"command":"echo test && op item get bank"}}' "block"

echo ""
echo "=== macOS KEYCHAIN ==="
run_test "security find-generic-password" '{"tool_name":"Bash","tool_input":{"command":"security find-generic-password -s \"1Password\""}}' "block"
run_test "security find-internet-password" '{"tool_name":"Bash","tool_input":{"command":"security find-internet-password -s \"github.com\""}}' "block"
run_test "security dump-keychain" '{"tool_name":"Bash","tool_input":{"command":"security dump-keychain login.keychain"}}' "block"
run_test "security export" '{"tool_name":"Bash","tool_input":{"command":"security export -k login.keychain -o /tmp/dump"}}' "block"
run_test "safe: security list-keychains" '{"tool_name":"Bash","tool_input":{"command":"security list-keychains"}}' "pass"

echo ""
echo "=== DATA DIRECTORY ACCESS (Bash) ==="
run_test "cat 1Password data" '{"tool_name":"Bash","tool_input":{"command":"cat ~/Library/Application Support/1Password/Preferences"}}' "block"
run_test "sqlite3 1Password" '{"tool_name":"Bash","tool_input":{"command":"sqlite3 ~/Library/Application\\ Support/1Password/data.sqlite"}}' "block"
run_test "strings bitwarden" '{"tool_name":"Bash","tool_input":{"command":"strings ~/Library/Containers/com.bitwarden.desktop/data"}}' "block"
run_test "cp 1Password data" '{"tool_name":"Bash","tool_input":{"command":"cp -r ~/Library/Application\\ Support/1Password /tmp/"}}' "block"
run_test "tar bitwarden" '{"tool_name":"Bash","tool_input":{"command":"tar czf /tmp/bw.tar.gz ~/Library/Containers/com.bitwarden.desktop"}}' "block"

echo ""
echo "=== PROCESS MANIPULATION ==="
run_test "kill 1Password" '{"tool_name":"Bash","tool_input":{"command":"killall 1Password"}}' "block"
run_test "pkill bitwarden" '{"tool_name":"Bash","tool_input":{"command":"pkill -f bitwarden"}}' "block"
run_test "kill by PID (safe — cant catch this)" '{"tool_name":"Bash","tool_input":{"command":"kill 48830"}}' "pass"

echo ""
echo "=== 1PASSWORD AGENT ==="
run_test "access agent socket" '{"tool_name":"Bash","tool_input":{"command":"cat ~/.1password/agent.sock"}}' "block"
run_test "access identity" '{"tool_name":"Bash","tool_input":{"command":"cat ~/.1password/identity/key"}}' "block"

echo ""
echo "=== KEYCHAIN FILES ==="
run_test "cat keychain-db" '{"tool_name":"Bash","tool_input":{"command":"cat ~/Library/Keychains/login.keychain-db"}}' "block"
run_test "strings keychain" '{"tool_name":"Bash","tool_input":{"command":"strings /Library/Keychains/System.keychain"}}' "block"
run_test "hexdump keychain" '{"tool_name":"Bash","tool_input":{"command":"hexdump ~/Library/Keychains/login.keychain-db"}}' "block"

echo ""
echo "=== BROWSER EXTENSION DATA ==="
run_test "read 1Password browser helper" '{"tool_name":"Bash","tool_input":{"command":"cat ~/Library/Group Containers/2BUA8C4S2C.com.1password.browser-helper/data"}}' "block"
run_test "sqlite3 bitwarden ext" '{"tool_name":"Bash","tool_input":{"command":"sqlite3 ~/Library/Containers/com.bitwarden.desktop.safari/Data/data.db"}}' "block"

echo ""
echo "=== READ TOOL BLOCKS ==="
run_test "Read 1Password prefs" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Application Support/1Password/Preferences"}}' "block"
run_test "Read bitwarden data" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Containers/com.bitwarden.desktop/Data/data.json"}}' "block"
run_test "Read keychain" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Keychains/login.keychain-db"}}' "block"
run_test "Read .1password dir" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/.1password/agent.sock"}}' "block"
run_test "Read 1Password helper" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Group Containers/2BUA8C4S2C.com.1password/data"}}' "block"

echo ""
echo "=== EDIT/WRITE TOOL BLOCKS ==="
run_test "Edit 1Password config" '{"tool_name":"Edit","tool_input":{"file_path":"/Users/test/Library/Application Support/1Password/config.json","old_string":"a","new_string":"b"}}' "block"
run_test "Write to bitwarden dir" '{"tool_name":"Write","tool_input":{"file_path":"/Users/test/Library/Containers/com.bitwarden.desktop/inject.js","content":"evil"}}' "block"

echo ""
echo "=== GLOB TOOL BLOCKS ==="
run_test "Glob 1Password dir" '{"tool_name":"Glob","tool_input":{"pattern":"**/*","path":"/Users/test/Library/Application Support/1Password"}}' "block"
run_test "Glob bitwarden dir" '{"tool_name":"Glob","tool_input":{"pattern":"*.json","path":"/Users/test/Library/Containers/com.bitwarden.desktop"}}' "block"
run_test "Glob keychain" '{"tool_name":"Glob","tool_input":{"pattern":"*.keychain*","path":"/Users/test/Library/Keychains"}}' "block"

echo ""
echo "=== SAFE COMMANDS (no false positives) ==="
run_test "safe: git status" '{"tool_name":"Bash","tool_input":{"command":"git status"}}' "pass"
run_test "safe: npm install" '{"tool_name":"Bash","tool_input":{"command":"npm install express"}}' "pass"
run_test "safe: ls home" '{"tool_name":"Bash","tool_input":{"command":"ls /tmp"}}' "pass"
run_test "safe: python script" '{"tool_name":"Bash","tool_input":{"command":"python3 analyze.py"}}' "pass"
run_test "safe: Read normal file" '{"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"}}' "pass"
run_test "safe: Glob normal dir" '{"tool_name":"Glob","tool_input":{"pattern":"*.js","path":"/tmp"}}' "pass"
run_test "safe: security list-keychains" '{"tool_name":"Bash","tool_input":{"command":"security list-keychains"}}' "pass"
run_test "safe: ps aux" '{"tool_name":"Bash","tool_input":{"command":"ps aux"}}' "pass"

echo ""
echo "================================"
echo "PASSED: $pass  |  FAILED: $fail"
echo "================================"
