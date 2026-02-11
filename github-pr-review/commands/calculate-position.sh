#!/usr/bin/env bash
# Calculate position numbers in diff for a given file
# Usage: ./calculate-position.sh <pr_number> <file_path>
#
# Example:
#   ./calculate-position.sh 6 app/components/registration/sections/form.tsx
#
# This will show the diff with position numbers for easy reference
# Position 1 = first line after the @@ hunk header
# ALL lines count (added +, removed -, context , blank)

set -e

PR_NUMBER="${1:-}"
FILE_PATH="${2:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

if [ -z "$PR_NUMBER" ] || [ -z "$FILE_PATH" ]; then
  echo -e "${RED}Error: Missing arguments${NC}"
  echo "Usage: $0 <pr_number> <file_path>"
  echo ""
  echo "Example:"
  echo "  $0 6 app/components/registration/sections/form.tsx"
  exit 1
fi

echo -e "${BLUE}Calculating positions for: $FILE_PATH in PR #$PR_NUMBER${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

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

# Show diff with position numbers
echo "$DIFF_OUTPUT" | awk -v red="$RED" -v green="$GREEN" -v blue="$BLUE" -v cyan="$CYAN" -v nc="$NC" '
BEGIN {
  position = 0
  in_hunk = 0
}

/^@@/ {
  # New hunk starts - position will start at 1 after this line
  in_hunk = 1
  position = 1

  # Print the hunk header
  print blue $0 nc
  next
}

in_hunk && /^[-+ ]/ {
  # All diff lines (added, removed, context)
  prefix = substr($0, 1, 1)
  rest = substr($0, 2)

  if (prefix == "+") {
    printf cyan "Position %d: " nc green "%s%s" nc "\n", position, prefix, rest
  } else if (prefix == "-") {
    printf cyan "Position %d: " nc red "%s%s" nc "\n", position, prefix, rest
  } else {
    printf cyan "Position %d: " nc " %s\n", position, rest
  }

  position++
  next
}

in_hunk && /^$/ {
  # Empty line still counts for position
  printf cyan "Position %d:" nc " (empty line)\n", position
  position++
  next
}

!in_hunk {
  # Print non-hunk lines as-is
  print $0
}
'

echo ""
echo -e "${YELLOW}Key:${NC}"
echo -e "  ${GREEN}+ Added line${NC}    ${cyan}→ Use this position in your review${NC}"
echo -e "  ${RED}- Removed line${NC}  ${cyan}→ Shows what was removed${NC}"
echo -e "  ${BLUE}  Context line${NC}  ${cyan}→ Shows surrounding context${NC}"
echo ""
echo -e "${BLUE}To validate a specific position:${NC}"
echo -e "  ${GREEN}./commands/validate-position.sh $PR_NUMBER $FILE_PATH <position>${NC}"
echo ""
echo -e "${BLUE}To see position range summary:${NC}"
echo -e "  ${GREEN}./commands/list-positions.sh $PR_NUMBER $FILE_PATH${NC}"
