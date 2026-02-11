#!/usr/bin/env bash
# Multi-Agent PR Review Orchestrator
# Launches 5 specialized review agents in parallel and consolidates findings
#
# Usage: ./multi-agent-review.sh <pr_number> <commit_sha>
# Example: ./multi-agent-review.sh 6 c0120254f48e9ef351eea5619b437a17f00d9d88

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

PR_NUMBER=$1
COMMIT_SHA=$2
OUTPUT_DIR=${3:-"/tmp/pr-review-${PR_NUMBER}"}

if [ -z "$PR_NUMBER" ] || [ -z "$COMMIT_SHA" ]; then
  echo "Usage: $0 <pr_number> <commit_sha> [output_dir]"
  exit 1
fi

echo -e "${BLUE}=== Multi-Agent PR Review Orchestrator ===${NC}"
echo "PR Number: $PR_NUMBER"
echo "Commit SHA: $COMMIT_SHA"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get git diff for analysis
echo -e "${BLUE}Fetching PR diff...${NC}"
DIFF_FILE="$OUTPUT_DIR/diff.patch"
gh pr diff $PR_NUMBER > "$DIFF_FILE"

# Count lines changed
ADDED_LINES=$(grep -c "^+" "$DIFF_FILE" || true)
REMOVED_LINES=$(grep -c "^-" "$DIFF_FILE" || true)
echo "Lines added: $ADDED_LINES, Lines removed: $REMOVED_LINES"
echo ""

# Agent definitions
AGENTS=(
  "solid-reviewer:SOLID+Architecture:blue"
  "security-reviewer:Security:red"
  "performance-reviewer:Performance:yellow"
  "error-handling-reviewer:Error-Handling:orange"
  "boundary-reviewer:Boundary-Conditions:purple"
)

# Create results directory
RESULTS_DIR="$OUTPUT_DIR/agent-results"
mkdir -p "$RESULTS_DIR"

# Function to run a single agent
run_agent() {
  local agent_name=$1
  local agent_title=$2
  local agent_color=$3

  local agent_output="$RESULTS_DIR/${agent_name}.md"
  local agent_log="$RESULTS_DIR/${agent_name}.log"

  echo -e "${!agent_color}[$(date +%H:%M:%S)] Launching $agent_title...${NC}" | tee -a "$agent_log"

  # This would be called via Claude Code's Task tool in actual usage
  # For now, create placeholder
  cat > "$agent_output" << EOF
# $agent_title Review

**Agent**: $agent_name
**Timestamp**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**PR**: #$PR_NUMBER
**Commit**: $COMMIT_SHA

<!-- Agent output will be populated by Claude Code -->
EOF

  echo -e "${GREEN}[$(date +%H:%M:%S)] $agent_title complete${NC}" | tee -a "$agent_log"
}

# Export functions for parallel execution
export -f run_agent
export PR_NUMBER COMMIT_SHA RESULTS_DIR BLUE GREEN RED YELLOW PURPLE NC

# Launch all agents in parallel
echo -e "${BLUE}Launching 5 review agents in parallel...${NC}"
echo ""

for agent_def in "${AGENTS[@]}"; do
  IFS=':' read -r agent_name agent_title agent_color <<< "$agent_def"
  run_agent "$agent_name" "$agent_title" "$agent_color" &
  PIDS+=($!)
done

# Wait for all agents to complete
echo -e "${BLUE}Waiting for all agents to complete...${NC}"
for pid in "${PIDS[@]}"; do
  wait $pid
done

echo ""
echo -e "${GREEN}=== All agents complete ===${NC}"
echo ""

# Consolidation script
echo -e "${BLUE}Consolidating findings...${NC}"

CONSOLIDATED_FILE="$OUTPUT_DIR/consolidated-review.md"

cat > "$CONSOLIDATED_FILE" << EOF
# Consolidated PR Review

**PR Number**: #$PR_NUMBER
**Commit**: $COMMIT_SHA
**Review Date**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Agents**: 5 specialized reviewers run in parallel

## Severity Legend

| Level | Name | Action |
|-------|------|--------|
| P0 | Critical | Must block merge |
| P1 | High | Should fix before merge |
| P2 | Medium | Fix or create follow-up |
| P3 | Low | Optional improvement |

## Event Type Mapping

- **P0/P1 findings** → \`REQUEST_CHANGES\` event
- **P2 findings** → \`COMMENT\` event
- **P3 findings** → \`APPROVE\` with notes

---

## Summary

EOF

# Parse all agent results and consolidate by severity
echo "Parsing agent results..."

for severity in P0 P1 P2 P3; do
  case $severity in
    P0)
      echo "## 🔴 Critical (P0) - Must Fix" >> "$CONSOLIDATED_FILE"
      echo "" >> "$CONSOLIDATED_FILE"
      echo "*These issues must be resolved before merging.*" >> "$CONSOLIDATED_FILE"
      ;;
    P1)
      echo "" >> "$CONSOLIDATED_FILE"
      echo "## 🟠 High (P1) - Should Fix" >> "$CONSOLIDATED_FILE"
      echo "" >> "$CONSOLIDATED_FILE"
      echo "*These issues should be fixed before merging.*" >> "$CONSOLIDATED_FILE"
      ;;
    P2)
      echo "" >> "$CONSOLIDATED_FILE"
      echo "## 🟡 Medium (P2) - Fix or Follow-up" >> "$CONSOLIDATED_FILE"
      echo "" >> "$CONSOLIDATED_FILE"
      echo "*Fix these or create follow-up issues.*" >> "$CONSOLIDATED_FILE"
      ;;
    P3)
      echo "" >> "$CONSOLIDATED_FILE"
      echo "## 🟢 Low (P3) - Optional" >> "$CONSOLIDATED_FILE"
      echo "" >> "$CONSOLIDATED_FILE"
      echo "*Optional improvements for code quality.*" >> "$CONSOLIDATED_FILE"
      ;;
  esac

  echo "" >> "$CONSOLIDATED_FILE"

  # Extract findings for this severity from all agents
  for agent_def in "${AGENTS[@]}"; do
    IFS=':' read -r agent_name agent_title agent_color <<< "$agent_def"
    agent_file="$RESULTS_DIR/${agent_name}.md"

    # Extract severity section from agent output
    if [ -f "$agent_file" ]; then
      # Look for findings at this severity level
      # In real usage, this would parse structured output
      echo "### From $agent_title" >> "$CONSOLIDATED_FILE"
      echo "" >> "$CONSOLIDATED_FILE"
      echo "<!-- Findings from $agent_name at $severity level -->" >> "$CONSOLIDATED_FILE"
      echo "" >> "$CONSOLIDATED_FILE"
    fi
  done
done

# Add event type recommendation
cat >> "$CONSOLIDATED_FILE" << EOF

---

## Recommended Event Type

Based on the findings above, the recommended event type is:

\`\`\`
EVENT_TO_USE: "COMMENT"  # Placeholder - calculate from actual findings
\`\`\`

**Decision Logic**:
- If any P0 findings exist → \`REQUEST_CHANGES\`
- If any P1 findings exist → \`REQUEST_CHANGES\`
- If only P2 findings exist → \`COMMENT\`
- If only P3 findings exist → \`APPROVE\` with notes
- If no findings → \`APPROVE\`

---

## Agent Attribution

This review was generated by 5 specialized agents running in parallel:

EOF

for agent_def in "${AGENTS[@]}"; do
  IFS=':' read -r agent_name agent_title agent_color <<< "$agent_def"
  echo "- **$agent_title**: \`$agent_name\`" >> "$CONSOLIDATED_FILE"
done

echo ""
echo -e "${GREEN}=== Consolidation Complete ===${NC}"
echo ""
echo "Consolidated review: $CONSOLIDATED_FILE"
echo "Agent results: $RESULTS_DIR/"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Review the consolidated findings"
echo "2. Validate positions using: ./commands/validate-review.sh $PR_NUMBER $CONSOLIDATED_FILE"
echo "3. Get user approval"
echo "4. Post review using gh api"
