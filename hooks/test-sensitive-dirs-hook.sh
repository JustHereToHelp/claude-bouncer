#!/bin/bash
# Tests for block-sensitive-dirs hook
HOOK="${HOOK:-$(dirname "$0")/block-sensitive-dirs}"

pass=0
fail=0

run_test() {
  local desc="$1"
  local cmd="$2"
  local expect="$3"

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

echo "=== BROWSER CREDENTIALS (Bash) ==="
run_test "sqlite3 Chrome Login Data" '{"tool_name":"Bash","tool_input":{"command":"sqlite3 ~/Library/Application\\ Support/Google/Chrome/Default/Login\\ Data"}}' "block"
run_test "cat Chrome Cookies" '{"tool_name":"Bash","tool_input":{"command":"cat ~/Library/Application\\ Support/Google/Chrome/Default/Cookies"}}' "block"
run_test "cp Brave Login Data" '{"tool_name":"Bash","tool_input":{"command":"cp ~/Library/Application\\ Support/BraveSoftware/Brave-Browser/Default/Login\\ Data /tmp/"}}' "block"
run_test "strings Edge Cookies" '{"tool_name":"Bash","tool_input":{"command":"strings \"~/Library/Application Support/Microsoft Edge/Default/Cookies\""}}' "block"
run_test "sqlite3 Firefox profile" '{"tool_name":"Bash","tool_input":{"command":"sqlite3 ~/Library/Application\\ Support/Firefox/Profiles/abc123.default/cookies.sqlite"}}' "block"
run_test "cat Safari data" '{"tool_name":"Bash","tool_input":{"command":"cat ~/Library/Safari/History.db"}}' "block"
run_test "strings system cookies" '{"tool_name":"Bash","tool_input":{"command":"strings ~/Library/Cookies/Cookies.binarycookies"}}' "block"

echo ""
echo "=== GPG KEYS (Bash) ==="
run_test "cat gpg private key" '{"tool_name":"Bash","tool_input":{"command":"cat ~/.gnupg/private-keys-v1.d/key.key"}}' "block"
run_test "tar gpg dir" '{"tool_name":"Bash","tool_input":{"command":"tar czf /tmp/gpg.tar.gz ~/.gnupg"}}' "block"

echo ""
echo "=== PERSONAL COMMS (Bash) ==="
run_test "sqlite3 iMessage" '{"tool_name":"Bash","tool_input":{"command":"sqlite3 ~/Library/Messages/chat.db"}}' "block"
run_test "cat Mail data" '{"tool_name":"Bash","tool_input":{"command":"cat ~/Library/Mail/V10/MailData/Envelope\\ Index"}}' "block"
run_test "tar Messages" '{"tool_name":"Bash","tool_input":{"command":"tar czf /tmp/msgs.tar.gz ~/Library/Messages"}}' "block"

echo ""
echo "=== DEV AUTH TOKENS (Bash) ==="
run_test "cat gh hosts.yml" '{"tool_name":"Bash","tool_input":{"command":"cat ~/.config/gh/hosts.yml"}}' "block"
run_test "cat docker config" '{"tool_name":"Bash","tool_input":{"command":"cat ~/.docker/config.json"}}' "block"
run_test "cat kube config" '{"tool_name":"Bash","tool_input":{"command":"cat ~/.kube/config"}}' "block"
run_test "cat npmrc" '{"tool_name":"Bash","tool_input":{"command":"cat ~/.npmrc"}}' "block"

echo ""
echo "=== SYSTEM AUTH (Bash) ==="
run_test "cat sudoers" '{"tool_name":"Bash","tool_input":{"command":"cat /etc/sudoers"}}' "block"
run_test "cat pam.d" '{"tool_name":"Bash","tool_input":{"command":"cat /etc/pam.d/sudo"}}' "block"

echo ""
echo "=== READ TOOL BLOCKS ==="
run_test "Read SSH private key" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/.ssh/id_ed25519"}}' "block"
run_test "Read SSH config" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/.ssh/config"}}' "block"
run_test "Read GPG key" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/.gnupg/private-keys-v1.d/key.key"}}' "block"
run_test "Read Chrome Login Data" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Application Support/Google/Chrome/Default/Login Data"}}' "block"
run_test "Read Firefox logins" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Application Support/Firefox/Profiles/abc.default/logins.json"}}' "block"
run_test "Read Safari" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Safari/History.db"}}' "block"
run_test "Read Cookies" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Cookies/Cookies.binarycookies"}}' "block"
run_test "Read iMessage" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Messages/chat.db"}}' "block"
run_test "Read Mail" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/Library/Mail/V10/data.emlx"}}' "block"
run_test "Read gh token" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/.config/gh/hosts.yml"}}' "block"
run_test "Read docker creds" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/.docker/config.json"}}' "block"
run_test "Read kube config" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/.kube/config"}}' "block"
run_test "Read npmrc" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/.npmrc"}}' "block"
run_test "Read sudoers" '{"tool_name":"Read","tool_input":{"file_path":"/etc/sudoers"}}' "block"

echo ""
echo "=== EDIT/WRITE TOOL BLOCKS ==="
run_test "Edit SSH config" '{"tool_name":"Edit","tool_input":{"file_path":"/Users/test/.ssh/config","old_string":"a","new_string":"b"}}' "block"
run_test "Write to gnupg" '{"tool_name":"Write","tool_input":{"file_path":"/Users/test/.gnupg/inject.key","content":"evil"}}' "block"
run_test "Edit gh hosts" '{"tool_name":"Edit","tool_input":{"file_path":"/Users/test/.config/gh/hosts.yml","old_string":"a","new_string":"b"}}' "block"

echo ""
echo "=== GLOB TOOL BLOCKS ==="
run_test "Glob SSH dir" '{"tool_name":"Glob","tool_input":{"pattern":"*","path":"/Users/test/.ssh"}}' "block"
run_test "Glob GPG dir" '{"tool_name":"Glob","tool_input":{"pattern":"*","path":"/Users/test/.gnupg"}}' "block"
run_test "Glob Chrome dir" '{"tool_name":"Glob","tool_input":{"pattern":"*","path":"/Users/test/Library/Application Support/Google/Chrome"}}' "block"
run_test "Glob Messages" '{"tool_name":"Glob","tool_input":{"pattern":"*","path":"/Users/test/Library/Messages"}}' "block"
run_test "Glob gh config" '{"tool_name":"Glob","tool_input":{"pattern":"*","path":"/Users/test/.config/gh"}}' "block"
run_test "Glob docker" '{"tool_name":"Glob","tool_input":{"pattern":"*","path":"/Users/test/.docker"}}' "block"

echo ""
echo "=== SAFE COMMANDS (no false positives) ==="
run_test "safe: git status" '{"tool_name":"Bash","tool_input":{"command":"git status"}}' "pass"
run_test "safe: npm install" '{"tool_name":"Bash","tool_input":{"command":"npm install express"}}' "pass"
run_test "safe: Read normal file" '{"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"}}' "pass"
run_test "safe: Read project file" '{"tool_name":"Read","tool_input":{"file_path":"/Users/test/project/src/index.js"}}' "pass"
run_test "safe: Glob project" '{"tool_name":"Glob","tool_input":{"pattern":"*.js","path":"/Users/test/project"}}' "pass"
run_test "safe: gh CLI config read" '{"tool_name":"Bash","tool_input":{"command":"cat ~/.config/gh/config.yml"}}' "pass"
run_test "safe: gh command" '{"tool_name":"Bash","tool_input":{"command":"gh pr list"}}' "pass"
run_test "safe: npm run" '{"tool_name":"Bash","tool_input":{"command":"npm run build"}}' "pass"
run_test "safe: docker ps" '{"tool_name":"Bash","tool_input":{"command":"docker ps"}}' "pass"
run_test "safe: security list" '{"tool_name":"Bash","tool_input":{"command":"security list-keychains"}}' "pass"

echo ""
echo "================================"
echo "PASSED: $pass  |  FAILED: $fail"
echo "================================"
