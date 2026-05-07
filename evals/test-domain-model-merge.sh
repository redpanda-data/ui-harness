# Validates the upstream-content merge from mattpocock/skills (2026-04-29):
#   - improve-codebase-architecture/LANGUAGE.md (canonical vocabulary)
#   - tdd/tests.md (good vs bad test philosophy)
#   - domain-model/ADR-FORMAT.md "What Qualifies" enriched list

ICA_DIR="$REPO_ROOT/improve-codebase-architecture"
TDD_DIR="$REPO_ROOT/tdd"
DM_DIR="$REPO_ROOT/domain-model"

# ── improve-codebase-architecture/LANGUAGE.md ────────────────────
run_file_eval "$ICA_DIR/LANGUAGE.md" "LANGUAGE.md exists in improve-codebase-architecture/"

for term in "Module" "Interface" "Implementation" "Depth" "Seam" "Adapter" "Leverage" "Locality"; do
  run_content_eval "$ICA_DIR/LANGUAGE.md" "^\\*\\*$term\\*\\*" "LANGUAGE.md defines $term"
done

run_content_eval "$ICA_DIR/LANGUAGE.md" "[Dd]eletion test" "LANGUAGE.md describes the deletion test"
run_content_eval "$ICA_DIR/LANGUAGE.md" "interface is the test surface" "LANGUAGE.md asserts interface=test surface"
run_content_eval "$ICA_DIR/LANGUAGE.md" "[Oo]ne adapter.*hypothetical.*[Tt]wo adapters.*real" "LANGUAGE.md has one-vs-two-adapters rule"
run_content_eval "$ICA_DIR/LANGUAGE.md" "Avoid.*[Bb]oundary|boundary.*overloaded" "LANGUAGE.md rejects boundary as overloaded with DDD"

# SKILL.md links to LANGUAGE.md
run_content_eval "$ICA_DIR/SKILL.md" "LANGUAGE\\.md" "ICA SKILL.md references LANGUAGE.md"
run_content_eval "$ICA_DIR/SKILL.md" "domain glossary|CONTEXT\\.md" "ICA SKILL.md references project domain glossary"
run_content_eval "$ICA_DIR/SKILL.md" "ADR" "ICA SKILL.md references ADRs"

# ── tdd/tests.md ─────────────────────────────────────────────────
run_file_eval "$TDD_DIR/tests.md" "tests.md exists in tdd/"
run_content_eval "$TDD_DIR/tests.md" "Good Tests" "tests.md has Good Tests section"
run_content_eval "$TDD_DIR/tests.md" "Bad Tests" "tests.md has Bad Tests section"
run_content_eval "$TDD_DIR/tests.md" "[Ii]ntegration-style" "tests.md prefers integration-style tests"
run_content_eval "$TDD_DIR/tests.md" "[Ii]mplementation-detail" "tests.md flags implementation-detail tests"
run_content_eval "$TDD_DIR/tests.md" "behaviour|behavior" "tests.md emphasises behaviour over implementation"

# SKILL.md links to tests.md
run_content_eval "$TDD_DIR/SKILL.md" "tests\\.md" "tdd SKILL.md references tests.md"

# ── domain-model/ADR-FORMAT.md enriched "What Qualifies" ─────────
run_file_eval "$DM_DIR/ADR-FORMAT.md" "ADR-FORMAT.md exists in domain-model/"

run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Aa]rchitectural shape" "ADR-FORMAT lists architectural shape"
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Ii]ntegration patterns" "ADR-FORMAT lists integration patterns"
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Tt]echnology.*lock-in|lock-in" "ADR-FORMAT lists technology with lock-in"
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Bb]oundary.*decisions|[Bb]oundary and scope" "ADR-FORMAT lists boundary decisions"
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Dd]eliberate deviations" "ADR-FORMAT lists deliberate deviations"
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Cc]onstraints not visible|[Ii]nvisible constraints" "ADR-FORMAT lists invisible constraints"
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Rr]ejected alternatives|[Nn]on-obvious rejections" "ADR-FORMAT lists non-obvious rejections"

# ── Three-prong "when to offer" rule ─────────────────────────────
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Hh]ard to reverse" "ADR-FORMAT requires hard-to-reverse"
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Ss]urprising without context" "ADR-FORMAT requires surprising-without-context"
run_content_eval "$DM_DIR/ADR-FORMAT.md" "[Rr]eal trade-off|real alternatives" "ADR-FORMAT requires real trade-off"

# ── zoom-out vague-prose ref ─────────────────────────────────────
run_content_eval "$REPO_ROOT/zoom-out/SKILL.md" "domain glossary" "zoom-out SKILL.md references project domain glossary"
