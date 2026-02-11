#!/usr/bin/env bash
# List all valid positions for a file in the PR diff
# Usage: ./list-positions.sh <pr_number> <file_path>
#
# Example:
#   ./list-positions.sh 6 app/components/registration/sections/form.tsx
#
# Output:
#   Valid positions: 1-249
#   Sample positions:
#     Position 1: +import React from "react";
#     Position 2: +import { useState } from "react";
#     Position 3: +import { useNavigate } from "react-router";
#     ...

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

echo -e "${BLUE}=== Valid Positions for: $FILE_PATH in PR #$PR_NUMBER ===${NC}"
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

# Calculate total positions and show sample lines
echo "$DIFF_OUTPUT" | awk -v cyan="$CYAN" -v green="$GREEN" -v blue="$BLUE" -v nc="$NC" '
BEGIN {
  position = 0
  in_hunk = 0
  total_lines = 0
  sample_count = 0
  max_samples = 20
}

/^@@/ {
  # Parse hunk header: @@ -old_start,old_count +new_start,new_count @@
  match($0, /@@[[:space:]]+([^@]+)@@/, hunk_parts)
  if (hunk_parts[1] != "") {
    split(hunk_parts[1], parts, /[[:space:]]+/)
    for (i in parts) {
      if (parts[i] ~ /^\+/) {
        gsub(/\+/, "", parts[i])
        split(parts[i], new_parts, ",")
        new_count = (new_parts[2] != "") ? new_parts[2] + 0 : 1
        total_lines += new_count

        # Print hunk info
        printf blue "\n  Hunk: " hunk_parts[1] " → " nc
        printf green "Positions: " position + 1 "-" position + new_count nc "\n"
        position += new_count
      }
    }
  }
  next
}

in_hunk && (/^[-+ ]/ || /^$/) {
  # Count all lines in hunk
  if (sample_count < max_samples) {
    prefix = substr($0, 1, 1)
    rest = substr($0, 2)
    line_num = position - total_lines + sample_count + 1

    if (prefix == "+") {
      printf cyan "    Position " line_num ":" nc " " green "+" rest nc "\n"
    } else if (prefix == "-") {
      printf "    Position " line_num ":" red "-" rest nc "\n"
    } else {
      printf "    Position " line_num ":" " " rest "\n"
    }
    sample_count++
  }
  next
}

END {
  printf "\n"
  printf green "  Total valid positions: 1-" total_lines nc "\n"
  printf "\n"
  printf blue "  Usage examples:" nc "\n"
  printf "    Validate: ./commands/validate-position.sh '"'"'" pr_num "'"'"' '"'"'" file_path "'"'"' <position>\n"
  printf "    For position 3: ./commands/validate-position.sh '"'"'" pr_num "'"'"' '"'"'" file_path "'"'"' 3\n"
}
' pr_num="$PR_NUMBER" file_path="$FILE_PATH"

echo ""
echo -e "${YELLOW}Tip: Use the position number when creating review comments${NC}"
echo -e "${YELLOW}      NOT the line number in the file${NC}"
