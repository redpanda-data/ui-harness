#!/bin/bash
# Run all hook unit test suites.
# Usage: bash agent-evals/hook-unit-tests-all.sh

set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
SUITES_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

run_suite() {
  local name="$1"
  local script="$2"
  echo ""
  echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Suite: $name${NC}"
  echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
  echo ""

  local output=""
  local exit_code=0
  output=$(bash "$DIR/$script" 2>&1) || exit_code=$?
  echo "$output"

  # Extract counts from last results line
  local pass fail skip
  pass=$(echo "$output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1 || echo 0)
  fail=$(echo "$output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | tail -1 || echo 0)
  skip=$(echo "$output" | grep -oE '[0-9]+ skipped' | grep -oE '[0-9]+' | tail -1 || echo 0)

  TOTAL_PASS=$((TOTAL_PASS + ${pass:-0}))
  TOTAL_FAIL=$((TOTAL_FAIL + ${fail:-0}))
  TOTAL_SKIP=$((TOTAL_SKIP + ${skip:-0}))

  if [ "$exit_code" -ne 0 ]; then
    SUITES_FAILED=$((SUITES_FAILED + 1))
  fi
}

echo -e "${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Hook Unit Test Runner                       ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

run_suite "Original (baseline)" "hook-unit-tests.sh"
run_suite "_hook-lib.sh" "hook-unit-tests-lib.sh"
run_suite "Pattern-Check Hooks" "hook-unit-tests-patterns.sh"
run_suite "Integration" "hook-unit-tests-integration.sh"
run_suite "Resilience" "hook-unit-tests-resilience.sh"

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  GRAND TOTAL${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
TOTAL=$((TOTAL_PASS + TOTAL_FAIL + TOTAL_SKIP))
echo -e "  Tests:  ${GREEN}${TOTAL_PASS} passed${NC}, ${RED}${TOTAL_FAIL} failed${NC}, ${YELLOW}${TOTAL_SKIP} skipped${NC} (${TOTAL} total)"
echo -e "  Suites: $((5 - SUITES_FAILED))/5 passed"
echo ""

if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo -e "${RED}FAILED${NC} — $TOTAL_FAIL test(s) failed"
  exit 1
fi
echo -e "${GREEN}ALL PASSED${NC}"
exit 0
