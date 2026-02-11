#!/usr/bin/env bash
# Helper command: Validate review JSON before posting
# Usage: ./validate-review.sh <pr_number> <json_file>
#
# Example:
#   ./validate-review.sh 6 /tmp/review_comments.json

set -e

PR_NUMBER="${1:-}"
JSON_FILE="${2:-}"

if [ -z "$PR_NUMBER" ] || [ -z "$JSON_FILE" ]; then
  echo "Usage: $0 <pr_number> <json_file>"
  echo ""
  echo "Example:"
  echo "  $0 6 /tmp/review_comments.json"
  exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
  echo "Error: File not found: $JSON_FILE"
  exit 1
fi

echo "Validating review for PR #$PR_NUMBER"
echo "===================================="
echo ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Warning: jq not found. Skipping JSON validation."
  echo "Install jq for full validation: brew install jq"
  echo ""
else
  echo "1. Validating JSON structure..."
  if jq empty "$JSON_FILE" 2>/dev/null; then
    echo "   ✓ JSON is valid"
  else
    echo "   ✗ Invalid JSON"
    exit 1
  fi

  echo ""
  echo "2. Checking required fields..."

  # Check commit_id
  if jq -e '.commit_id' "$JSON_FILE" &> /dev/null; then
    echo "   ✓ commit_id present: $(jq -r '.commit_id' "$JSON_FILE")"
  else
    echo "   ✗ Missing commit_id"
    exit 1
  fi

  # Check comments array
  if jq -e '.comments | type == "array"' "$JSON_FILE" &> /dev/null; then
    COMMENT_COUNT=$(jq '.comments | length' "$JSON_FILE")
    echo "   ✓ comments array present: $COMMENT_COUNT comment(s)"
  else
    echo "   ✗ Missing or invalid comments array"
    exit 1
  fi

  echo ""
  echo "3. Validating each comment..."

  jq -c '.comments[]' "$JSON_FILE" | while read -r comment; do
    PATH=$(echo "$comment" | jq -r '.path // empty')
    POSITION=$(echo "$comment" | jq -r '.position // empty')
    BODY=$(echo "$comment" | jq -r '.body // empty')

    if [ -z "$PATH" ]; then
      echo "   ✗ Comment missing 'path' field"
      exit 1
    fi

    if [ -z "$POSITION" ] || [ "$POSITION" = "null" ]; then
      echo "   ✗ Comment on '$PATH' missing 'position' field"
      exit 1
    fi

    if ! echo "$POSITION" | grep -qE '^[0-9]+$'; then
      echo "   ✗ Comment on '$PATH' has invalid position: '$POSITION' (must be a number)"
      exit 1
    fi

    if [ -z "$BODY" ] || [ "$BODY" = "null" ]; then
      echo "   ✗ Comment on '$PATH' at position $POSITION missing 'body' field"
      exit 1
    fi

    echo "   ✓ $PATH:$POSITION - $(echo "$BODY" | head -c 40)..."
  done

  echo ""
  echo "4. Checking if files exist in PR diff..."

  # Get list of files in the PR diff
  PR_FILES=$(gh pr diff "$PR_NUMBER" --name-only 2>/dev/null | sort -u)

  jq -r '.comments[].path' "$JSON_FILE" | sort -u | while read -r path; do
    if echo "$PR_FILES" | grep -qxF "$path"; then
      echo "   ✓ $path found in PR diff"
    else
      echo "   ⚠ $path not found in PR diff (may have wrong path)"
    fi
  done

  echo ""
  echo "5. Validating position ranges..."

  # Function to get valid position range for a file
  get_position_range() {
    local file="$1"
    local pr="$2"

    gh pr diff "$pr" -- "$file" 2>/dev/null | awk '
    BEGIN {
      min_pos = ""
      max_pos = ""
      position = 0
      in_hunk = 0
      total_lines = 0
    }

    /^@@/ {
      in_hunk = 1
      position = total_lines + 1

      # Format: @@ -old_start,old_count +new_start,new_count @@
      match($0, /\+([0-9]+),([0-9]+)/, arr)
      new_count = arr[2]

      hunk_max = position + new_count - 1

      if (min_pos == "" || position < min_pos) {
        min_pos = position
      }
      if (max_pos == "" || hunk_max > max_pos) {
        max_pos = hunk_max
      }

      total_lines = hunk_max
      next
    }

    END {
      if (min_pos != "" && max_pos != "") {
        print min_pos ":" max_pos
      } else {
        print "0:0"
      }
    }
    '
  }

  # Check each comment's position is valid
  VALIDATION_FAILED=0
  jq -c '.comments[]' "$JSON_FILE" | while read -r comment; do
    PATH=$(echo "$comment" | jq -r '.path')
    POSITION=$(echo "$comment" | jq -r '.position')

    RANGE=$(get_position_range "$PATH" "$PR_NUMBER")
    MIN_POS=$(echo "$RANGE" | cut -d: -f1)
    MAX_POS=$(echo "$RANGE" | cut -d: -f2)

    if [ "$MIN_POS" = "0" ] && [ "$MAX_POS" = "0" ]; then
      echo "   ⚠ $PATH:$POSITION - Could not determine position range"
    elif [ "$POSITION" -ge "$MIN_POS" ] && [ "$POSITION" -le "$MAX_POS" ]; then
      echo "   ✓ $PATH:$POSITION - Valid (range: $MIN_POS-$MAX_POS)"
    else
      echo "   ✗ $PATH:$POSITION - INVALID! Position $POSITION out of range [$MIN_POS-$MAX_POS]"
      echo "     → Run: ./commands/validate-position.sh $PR_NUMBER $PATH $POSITION"
      VALIDATION_FAILED=1
    fi
  done

  if [ "$VALIDATION_FAILED" -eq 1 ]; then
    echo ""
    echo "❌ Position validation failed!"
    echo ""
    echo "To fix invalid positions:"
    echo "  1. Run calculate-position.sh to see valid positions:"
    echo "     ./commands/calculate-position.sh $PR_NUMBER <file_path>"
    echo ""
    echo "  2. Or validate a specific position:"
    echo "     ./commands/validate-position.sh $PR_NUMBER <file_path> <position>"
    exit 1
  fi
fi

echo ""
echo "===================================="
echo "Validation complete!"
echo ""
echo "Next step: Post the review"
echo "  gh api repos/:owner/:repo/pulls/$PR_NUMBER/reviews --input \"$JSON_FILE\""
