#!/usr/bin/env bash
# Post a PR review using JSON payload (avoids markdown escaping issues)
# Usage: ./post-review.sh <pr_number> <json_file> [dry_run]
#
# Examples:
#   ./post-review.sh 6 /tmp/review.json
#   ./post-review.sh 6 /tmp/review.json dry_run  # Test without posting
#
# JSON format:
# {
#   "commit_id": "abc123...",
#   "event": "COMMENT",           // Optional: APPROVE, REQUEST_CHANGES, COMMENT
#   "body": "Overall message",    // Required if event is provided
#   "comments": [
#     {
#       "path": "path/to/file.ts",
#       "position": 13,
#       "body": "Comment text\n\n```suggestion\nconst x = 1;\n```"
#     }
#   ]
# }

set -e

PR_NUMBER="${1:-}"
JSON_FILE="${2:-}"
DRY_RUN="${3:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$PR_NUMBER" ] || [ -z "$JSON_FILE" ]; then
  echo "Usage: $0 <pr_number> <json_file> [dry_run]"
  echo ""
  echo "Examples:"
  echo "  $0 6 /tmp/review.json"
  echo "  $0 6 /tmp/review.json dry_run  # Test without posting"
  exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
  echo -e "${RED}Error: File not found: $JSON_FILE${NC}"
  exit 1
fi

echo -e "${BLUE}=== GitHub PR Review Poster ===${NC}"
echo "PR Number: $PR_NUMBER"
echo "JSON File: $JSON_FILE"

if [ "$DRY_RUN" = "dry_run" ]; then
  echo -e "${YELLOW}Mode: DRY RUN (will not post)${NC}"
fi
echo ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${YELLOW}Warning: jq not found. Install for better output: brew install jq${NC}"
  echo ""
fi

# Validate JSON first
echo -e "${BLUE}1. Validating JSON...${NC}"
if command -v jq &> /dev/null; then
  if ! jq empty "$JSON_FILE" 2>/dev/null; then
    echo -e "${RED}✗ Invalid JSON${NC}"
    exit 1
  fi
  echo -e "${GREEN}   ✓ JSON is valid${NC}"
else
  # Basic validation without jq
  if ! grep -q '{' "$JSON_FILE" || ! grep -q '}' "$JSON_FILE"; then
    echo -e "${RED}✗ Invalid JSON${NC}"
    exit 1
  fi
  echo -e "${GREEN}   ✓ JSON appears valid${NC}"
fi
echo ""

# Show review summary
echo -e "${BLUE}2. Review Summary:${NC}"
if command -v jq &> /dev/null; then
  COMMIT_ID=$(jq -r '.commit_id // "not set"' "$JSON_FILE")
  EVENT=$(jq -r '.event // "pending (will create PENDING review)"' "$JSON_FILE")
  COMMENT_COUNT=$(jq '.comments | length' "$JSON_FILE")
  BODY_PREVIEW=$(jq -r '.body // "no body"' "$JSON_FILE" | head -c 60)

  echo "   Commit ID: $COMMIT_ID"
  echo "   Event: $EVENT"
  echo "   Comments: $COMMENT_COUNT"
  echo "   Body: $BODY_PREVIEW..."
else
  echo "   (Install jq for detailed summary)"
fi
echo ""

# Show each comment
echo -e "${BLUE}3. Comments to be posted:${NC}"
if command -v jq &> /dev/null; then
  jq -r '.comments[] | "   \(.path):\(.position) - \(.body | gsub("\n"; " ") | .[0:60])..."' "$JSON_FILE"
else
  echo "   (Install jq to see comment details)"
fi
echo ""

# Check if event is set
if command -v jq &> /dev/null; then
  HAS_EVENT=$(jq -e '.event' "$JSON_FILE" &> /dev/null && echo "yes" || echo "no")

  if [ "$HAS_EVENT" = "yes" ]; then
    EVENT=$(jq -r '.event' "$JSON_FILE")
    echo -e "${BLUE}4. Event Type: $EVENT${NC}"
    echo "   Review will be submitted immediately with event=$EVENT"
  else
    echo -e "${BLUE}4. Event Type: Not set${NC}"
    echo "   Review will be created as PENDING"
    echo "   Submit it later with: gh api .../reviews/<id>/events -f event=..."
  fi
else
  echo -e "${BLUE}4. Event Type: (Install jq to check)${NC}"
fi
echo ""

# Dry run mode
if [ "$DRY_RUN" = "dry_run" ]; then
  echo -e "${YELLOW}=== DRY RUN COMPLETE - Would post the review above ===${NC}"
  echo ""
  echo "To post for real, run:"
  echo "  $0 $PR_NUMBER $JSON_FILE"
  exit 0
fi

# Confirm before posting
echo -e "${YELLOW}Ready to post this review to PR #$PR_NUMBER?${NC}"
echo -n "Type 'yes' to confirm: "
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi
echo ""

# Post the review
echo -e "${BLUE}5. Posting review...${NC}"

# Build the gh api command
API_PATH="repos/:owner/:repo/pulls/$PR_NUMBER/reviews"

# Post with JSON input
RESULT=$(gh api "$API_PATH" \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  --input "$JSON_FILE" 2>&1)

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✓ Review posted successfully!${NC}"
  echo ""
  echo "Response:"
  echo "$RESULT"

  # Extract review ID if available
  if command -v jq &> /dev/null; then
    REVIEW_ID=$(echo "$RESULT" | jq -r '.id // empty')
    STATE=$(echo "$RESULT" | jq -r '.state // empty')

    if [ -n "$REVIEW_ID" ]; then
      echo ""
      echo "Review ID: $REVIEW_ID"
      echo "State: $STATE"

      if [ "$STATE" = "PENDING" ]; then
        echo ""
        echo "To submit this pending review:"
        echo "  gh api repos/:owner/:repo/pulls/$PR_NUMBER/reviews/$REVIEW_ID/events -X POST -f event=COMMENT -f body='Ready to merge'"
      fi
    fi
  fi
else
  echo -e "${RED}✗ Failed to post review${NC}"
  echo ""
  echo "Error:"
  echo "$RESULT"
  echo ""

  # Check for common errors
  if echo "$RESULT" | grep -q "could not be resolved"; then
    echo -e "${YELLOW}=== Position Error Detected ===${NC}"
    echo ""
    echo "One or more positions could not be resolved in the diff."
    echo ""
    echo "To fix:"
    echo "  1. Validate positions first:"
    echo "     ./commands/validate-review.sh $PR_NUMBER $JSON_FILE"
    echo ""
    echo "  2. Check specific positions:"
    echo "     ./commands/validate-position.sh $PR_NUMBER <file> <position>"
    echo ""
    echo "  3. Recalculate positions:"
    echo "     ./commands/calculate-position.sh $PR_NUMBER <file>"
    exit 1
  fi

  if echo "$RESULT" | grep -q "Expected value to not be null"; then
    echo -e "${YELLOW}=== Null Value Error Detected ===${NC}"
    echo ""
    echo "One or more required fields are null or empty."
    echo "Check that all comments have: path, position, body"
    exit 1
  fi

  exit 1
fi
