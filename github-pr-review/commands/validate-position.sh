#!/usr/bin/env bash
# Validate a single position in a file's diff
# Usage: ./validate-position.sh <pr_number> <file_path> <position>
#
# Example:
#   ./validate-position.sh 6 app/root.tsx 5
#
# Output:
#   ✅ Valid: Position 5 is in range [1-7]
#   OR
#   ❌ Invalid: Position 25 is out of range. Valid positions: [1-7]

set -e

PR_NUMBER="${1:-}"
FILE_PATH="${2:-}"
POSITION="${3:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$PR_NUMBER" ] || [ -z "$FILE_PATH" ] || [ -z "$POSITION" ]; then
  echo -e "${RED}Error: Missing arguments${NC}"
  echo "Usage: $0 <pr_number> <file_path> <position>"
  echo ""
  echo "Example:"
  echo "  $0 6 app/root.tsx 5"
  exit 1
fi

# Check if position is a valid number
if ! echo "$POSITION" | grep -qE '^[0-9]+$'; then
  echo -e "${RED}❌ Error: Position must be a positive integer, got '$POSITION'${NC}"
  exit 1
fi

# Get the diff for the specific file
DIFF_OUTPUT=$(gh pr diff "$PR_NUMBER" -- "$FILE_PATH" 2>/dev/null)

if [ -z "$DIFF_OUTPUT" ]; then
  echo -e "${RED}❌ Error: File '$FILE_PATH' not found in PR #$PR_NUMBER diff${NC}"
  echo ""
  echo -e "${BLUE}Available files in PR:${NC}"
  gh pr diff "$PR_NUMBER" --name-only 2>/dev/null | head -20 | while read -r f; do
    echo "  - $f"
  done
  exit 1
fi

# Calculate valid position ranges from diff hunks
# Format: @@ -old_start,old_count +new_start,new_count @@
calculate_position_ranges() {
  echo "$DIFF_OUTPUT" | awk '
  BEGIN {
    in_hunk = 0
    position = 0
    min_pos = ""
    max_pos = ""
  }

  /^@@/ {
    # Parse hunk header: @@ -old_start,old_count +new_start,new_count @@
    # The position starts at 1 after this line

    # Extract the part after @@ that contains the ranges
    match($0, /@@[[:space:]]+([^@]+)@@/, hunk_parts)
    if (hunk_parts[1] != "") {
      # Parse: -old_start,old_count +new_start,new_count
      split(hunk_parts[1], parts, /[[:space:]]+/)

      # Find the part starting with + (new file range)
      for (i in parts) {
        if (parts[i] ~ /^\+/) {
          # Parse +new_start,new_count or +new_start
          gsub(/\+/, "", parts[i])
          split(parts[i], new_parts, ",")
          new_start = new_parts[1] + 0  # Convert to number
          new_count = (new_parts[2] != "") ? new_parts[2] + 0 : 1

          # Position starts at 1 for each hunk
          hunk_min = 1
          hunk_max = new_count

          if (min_pos == "" || hunk_min < min_pos) {
            min_pos = hunk_min
          }
          if (max_pos == "" || hunk_max > max_pos) {
            max_pos = hunk_max
          }

          print "HUNK:" hunk_parts[1] " RANGE:" hunk_min "-" hunk_max
        }
      }
    }

    next
  }

  END {
    if (min_pos != "" && max_pos != "") {
      print "MIN:" min_pos
      print "MAX:" max_pos
    } else {
      print "MIN:0"
      print "MAX:0"
    }
  }
  '
}

# Run the calculation
RESULT=$(calculate_position_ranges)

# Parse results
MIN_POSITION=$(echo "$RESULT" | grep "^MIN:" | cut -d: -f2)
MAX_POSITION=$(echo "$RESULT" | grep "^MAX:" | cut -d: -f2)
HUNK_INFO=$(echo "$RESULT" | grep "^HUNK:" | sed 's/HUNK:/  /' | sed 's/ RANGE:/ → positions /')

if [ -z "$MIN_POSITION" ] || [ "$MIN_POSITION" = "0" ] || [ -z "$MAX_POSITION" ] || [ "$MAX_POSITION" = "0" ]; then
  echo -e "${YELLOW}⚠ Warning: Could not determine position range for '$FILE_PATH'${NC}"
  echo ""
  echo -e "${BLUE}Diff output (first 30 lines):${NC}"
  echo "$DIFF_OUTPUT" | head -30
  exit 1
fi

# Check if position is in range
if [ "$POSITION" -ge "$MIN_POSITION" ] && [ "$POSITION" -le "$MAX_POSITION" ]; then
  echo -e "${GREEN}✅ Valid: Position $POSITION is in range [$MIN_POSITION-$MAX_POSITION]${NC}"
  echo ""
  echo -e "${BLUE}File:${NC} $FILE_PATH"
  echo -e "${BLUE}PR:${NC} #$PR_NUMBER"
  echo ""
  echo -e "${BLUE}Diff hunks:${NC}"
  echo "$HUNK_INFO"
  exit 0
else
  echo -e "${RED}❌ Invalid: Position $POSITION is out of range.${NC}"
  echo ""
  echo -e "${BLUE}File:${NC} $FILE_PATH"
  echo -e "${BLUE}PR:${NC} #$PR_NUMBER"
  echo ""
  echo -e "${BLUE}Valid positions:${NC} [$MIN_POSITION-$MAX_POSITION]"
  echo ""
  echo -e "${BLUE}Diff hunks:${NC}"
  echo "$HUNK_INFO"
  echo ""
  echo -e "${YELLOW}Suggested fixes:${NC}"
  echo "  1. See all valid positions:"
  echo -e "     ${GREEN}./commands/list-positions.sh $PR_NUMBER $FILE_PATH${NC}"
  echo ""
  echo "  2. Calculate position from line number:"
  echo -e "     ${GREEN}./commands/calculate-position.sh $PR_NUMBER $FILE_PATH${NC}"
  echo ""
  echo "  3. Check the diff directly:"
  echo -e "     ${GREEN}gh pr diff $PR_NUMBER -- $FILE_PATH${NC}"
  exit 1
fi
