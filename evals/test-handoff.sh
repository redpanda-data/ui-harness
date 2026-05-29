# Evals for /handoff skill.

run_file_eval "$REPO_ROOT/handoff/SKILL.md" "handoff skill exists"
run_content_eval "$REPO_ROOT/handoff/SKILL.md" "name: handoff" "handoff frontmatter name"
run_content_eval "$REPO_ROOT/handoff/SKILL.md" "mktemp -t handoff-XXXXXX.md" "handoff uses mktemp path"
run_content_eval "$REPO_ROOT/handoff/SKILL.md" 'cat .*handoff_file.*>/dev/null' "handoff reads temp file before writing"
run_content_eval "$REPO_ROOT/handoff/SKILL.md" "Do not duplicate artifacts" "handoff avoids artifact duplication"
run_content_eval "$REPO_ROOT/handoff/SKILL.md" "[Rr]edact.*sensitive|secrets.*personal data" "handoff redacts sensitive information"
run_content_eval "$REPO_ROOT/handoff/SKILL.md" "Suggested skills" "handoff suggests next skills"
run_content_eval "$REPO_ROOT/.claude-plugin/plugin.json" "\./handoff/" "handoff registered in Claude plugin skills"
run_content_eval "$REPO_ROOT/README.md" "/handoff" "README documents handoff"
