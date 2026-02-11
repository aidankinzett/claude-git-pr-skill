---
name: github-pr-review
description: Use when reviewing GitHub pull requests with gh CLI - creates pending reviews with code suggestions, batches comments, and chooses appropriate event types (COMMENT/APPROVE/REQUEST_CHANGES). v2.0+ supports parallel multi-agent review with 5 specialized reviewers for comprehensive analysis.
allowed-tools: AskUserQuestion
---

# GitHub PR Review

## Overview

Workflow for reviewing GitHub pull requests using `gh api` to create pending reviews with code suggestions. **Always use pending reviews to batch comments, even under time pressure.**

**v2.0.0+ Multi-Agent Review:** Launch 5 specialized agents (SOLID, Security, Performance, Error Handling, Boundaries) in parallel for comprehensive PR analysis with consistent P0-P3 severity labeling.

**CRITICAL: Always get explicit user approval before posting any review comments.** Show exactly what will be posted and ask for yes/no confirmation using AskUserQuestion.

## Multi-Agent Review (v2.0.0)

**NEW in v2.0.0:** This skill now supports **parallel multi-agent review** using 5 specialized reviewers.

### The 5 Specialized Agents

| Agent | Focus Area | Examples |
|-------|-----------|----------|
| **solid-reviewer** | SOLID Principles + Architecture | SRP violations, god classes, OCP violations |
| **security-reviewer** | Security Vulnerabilities | SQL injection, XSS, IDOR, hardcoded secrets |
| **performance-reviewer** | Performance Issues | N+1 queries, O(n²) algorithms, missing cache |
| **error-handling-reviewer** | Error Handling | Swallowed exceptions, missing error boundaries |
| **boundary-reviewer** | Boundary Conditions | Null dereference, empty arrays, off-by-one |

### Severity Levels

All agents use a consistent **P0-P3 severity system**:

| Level | Name | Action | Event Type |
|-------|------|--------|------------|
| **P0** | Critical | Must fix, blocks merge | `REQUEST_CHANGES` |
| **P1** | High | Should fix before merge | `REQUEST_CHANGES` |
| **P2** | Medium | Fix or create follow-up | `COMMENT` |
| **P3** | Low | Optional improvement | `APPROVE` with notes |

### Hybrid Event Type Mapping

The multi-agent system automatically determines the appropriate event type based on findings:

```
if (any P0 or P1 findings exist) {
    event = "REQUEST_CHANGES";
} else if (any P2 findings exist) {
    event = "COMMENT";
} else if (any P3 findings exist) {
    event = "APPROVE"; // with notes about P3 issues
} else {
    event = "APPROVE"; // clean PR
}
```

### Multi-Agent Workflow

1. **Check gh CLI is installed** - Run `gh --version`
2. **Get PR details** - Fetch PR number and commit SHA
3. **Launch 5 agents in parallel** - Each analyzes a specific aspect
4. **Consolidate findings** - Merge results by severity level
5. **Calculate positions** - Use helper commands for accuracy
6. **Show consolidated review** - Present all findings organized by severity
7. **Get explicit approval** - Use AskUserQuestion
8. **Post the review** - Single-call with appropriate event type

### Agent Output Format

Each agent produces structured findings:

```markdown
## [Agent Name] Review

### Critical (P0) - Must Fix
- **[File:Line]** Issue description
  - Confidence: 95
  - Fix: [Suggestion]

### High (P1) - Should Fix
...
```

### Consolidation Example

The orchestrator combines all agent outputs:

```markdown
# Consolidated PR Review

## Summary
- **P0 (Critical)**: 2 issues from security-reviewer
- **P1 (High)**: 5 issues from solid-reviewer, performance-reviewer
- **P2 (Medium)**: 8 issues across all agents
- **P3 (Low)**: 3 optional improvements

## 🔴 Critical (P0) - Must Fix

### From Security Review
- **app/auth.ts:45** - Hardcoded API key
  - Confidence: 100
  - Fix: Move to environment variable

### From Performance Review
- **app/api/users.ts:78** - N+1 query in user list
  - Confidence: 90
  - Fix: Use eager loading with JOIN

## 🟠 High (P1) - Should Fix
...
```

### Running Multi-Agent Review

Use the orchestrator script:

```bash
./commands/multi-agent-review.sh <pr_number> <commit_sha> [output_dir]
```

Example:
```bash
# Get commit SHA first
COMMIT_SHA=$(gh pr view 6 --json commits --jq '.commits[-1].oid')

# Run multi-agent review
./commands/multi-agent-review.sh 6 $COMMIT_SHA /tmp/pr-review-6

# Review the consolidated output
cat /tmp/pr-review-6/consolidated-review.md
```

### Confidence Scoring

All agents use **80+ confidence threshold**:

| Score | Meaning | Reported? |
|-------|---------|-----------|
| 0-49 | Not confident (false positive) | ❌ No |
| 50-79 | Somewhat confident (nitpick) | ❌ No |
| 80-89 | Confident (real issue) | ✅ Yes |
| 90-100 | Very confident (critical) | ✅ Yes |

### Agent Attributed Transparency

The consolidated review maintains **agent attribution** so reviewers understand:

- Which agent found each issue
- Why it was flagged (agent's expertise area)
- What severity level was assigned
- Confidence score for the finding

Example attribution:
```markdown
- **src/auth.ts:45** - Hardcoded API key (security-reviewer, P0, 100% confidence)
```

### When to Use Multi-Agent vs Manual

**Use Multi-Agent (v2.0.0) for:**
- Comprehensive PR reviews with multiple aspects to check
- Large PRs with many files changed
- Security-sensitive code requiring thorough analysis
- Performance-critical code paths
- Teams wanting consistent review coverage

**Use Manual (v1.x) for:**
- Small, straightforward PRs
- Quick sanity checks
- Focused review on specific aspects
- Learning the PR review workflow

---

## CRITICAL: JSON Payload vs Array Syntax

**⚠️ IMPORTANT: Always use JSON payload for reviews with code suggestions.**

### The Markdown Escaping Problem

When using the `-f` flag with array syntax, backslashes and special characters get escaped, breaking markdown code blocks:

```bash
# ❌ PROBLEMATIC: -f flag breaks markdown
gh api .../reviews \
  -f 'comments[][body]=Fix this:\n\n```suggestion\nconst x = 1;\n```'
# Result: Backslashes get escaped (\\n\\n instead of \n\n)
# Markdown breaks, suggestions appear as plain text
```

### Solution: JSON Payload Approach

**✅ RECOMMENDED: Always use JSON payload with `--input` flag**

```bash
# Create JSON file with proper newlines
cat > /tmp/review.json <<'EOF'
{
  "commit_id": "abc123",
  "event": "COMMENT",
  "body": "Found 2 issues",
  "comments": [
    {
      "path": "src/file.ts",
      "position": 13,
      "body": "Fix the import:\n\n```suggestion\nimport { foo } from './bar';\n```"
    }
  ]
}
EOF

# Post with --input (preserves formatting)
gh api .../reviews --input /tmp/review.json
```

### Comparison Table

| Aspect | Array Syntax (-f) | JSON Payload (--input) |
|--------|-------------------|----------------------|
| Markdown rendering | ❌ Breaks with special chars | ✅ Works correctly |
| Type handling | ❌ Numbers become strings | ✅ Types preserved |
| Multiple comments | ❌ Fragile, mixed flags | ✅ Reliable |
| Validation | ❌ Hard to validate | ✅ Can validate first |
| File reuse | ❌ Must recreate each time | ✅ Can save and reuse |

### Helper Commands (v2.1.0+)

The skill now includes helper commands for reliable review posting:

```bash
# Validate positions before posting
./commands/validate-review.sh <pr_number> <json_file>

# Validate a single position
./commands/validate-position.sh <pr_number> <file_path> <position>

# Post review with proper handling
./commands/post-review.sh <pr_number> <json_file>

# Dry run to test
./commands/post-review.sh <pr_number> <json_file> dry_run
```

### Recommended Workflow

1. **Create review JSON** using the template:
   ```bash
   cp templates/review-template.json /tmp/review.json
   # Edit with your comments
   ```

2. **Validate before posting**:
   ```bash
   ./commands/validate-review.sh <pr_number> /tmp/review.json
   ```

3. **Post the review**:
   ```bash
   ./commands/post-review.sh <pr_number> /tmp/review.json
   ```

### Red Flags - You're About to Break Markdown

Stop if you're thinking:
- "I'll use `-f 'body=```suggestion...'`" - **This will break**
- "The `-f` flag should work fine" - **It breaks with backticks**
- "I'll escape the backslashes" - **Don't, use JSON instead**
- "Array syntax is simpler" - **JSON is more reliable**

---

## When to Use

- Reviewing pull requests
- Adding code suggestions to PRs
- Posting review comments with the gh CLI

## Prerequisites

**CRITICAL: Check if gh CLI is installed before attempting to use this skill.**

### Check for gh CLI

Before starting any PR review workflow, verify the gh CLI is available:

```bash
gh --version
```

**If gh is not installed:**

1. **Stop immediately** - Do not attempt to run gh api commands
2. **Inform the user** with this message:

```
The GitHub CLI (gh) is required for this skill but is not installed.

Please install it from: https://cli.github.com/

Installation options:
- macOS: brew install gh
- Windows: winget install GitHub.cli
- Linux: See https://cli.github.com/ for your distro

After installing, authenticate with:
  gh auth login

Then try your PR review request again.
```

3. **Do not proceed** with the review workflow until gh is installed

### After Installation

Once gh is installed, users must authenticate:
```bash
gh auth login
```

## Core Workflow

**REQUIRED STEPS (do not skip):**

### Multi-Agent Workflow (v2.0.0+) - Recommended for Comprehensive Reviews

1. **Check gh CLI is installed** - Run `gh --version` to verify
2. **Get PR details** - Fetch PR number and commit SHA
3. **Launch 5 agents in parallel** - Run `multi-agent-review.sh` orchestrator
4. **Consolidate findings** - Script merges results by severity
5. **Calculate positions** - Use helper commands for accuracy
6. **Show user consolidated review** - Present findings by severity level
7. **Get explicit approval** - Use AskUserQuestion with yes/no
8. **Post the review** - Single-call with appropriate event type

### Manual Workflow (v1.x) - For Quick/Focused Reviews

1. **Check gh CLI is installed** - Run `gh --version` to verify
2. **Get PR diff** - Fetch diff to calculate correct positions
3. **Draft the review** - Analyze PR and prepare all comments with valid positions
4. **Validate all parameters** - Ensure no null/empty values
5. **Show user exactly what will be posted** - Use AskUserQuestion with yes/no
6. **Get explicit approval** - Wait for user confirmation
7. **Post the review** - Only after approval

### Approval Pattern

Before posting ANY review, use AskUserQuestion to show:
- File and position for each comment
- Exact comment text (including code suggestions)
- Event type (APPROVE/REQUEST_CHANGES/COMMENT)
- Overall review message

**Example:**
```
Question: "Ready to post this review?"
Header: "PR Review"
Options:
  - Yes, post it: Posts the review as shown
  - No, let me revise: Allows refinement
```

## Understanding Position vs Line Number

**CRITICAL:** GitHub's review API uses `position` NOT `line` number. Using incorrect positions causes HTTP 422 errors.

### What is Position?

- **Position** = The line number within the diff hunk, starting from the first `@@` line
- The line just below the `@@` hunk header is position 1
- Position continues through all hunks in the file until a new file begins
- **Position is NOT the same as line number in the file**

### Step-by-Step: How to Calculate Position

**CRITICAL:** Position must be counted from ALL lines in the diff hunk, including:
- Added lines (`+`)
- Removed lines (`-`)
- Context lines (unchanged, shown with space)
- Empty lines

**Option 1: Use the helper command (Recommended)**

```bash
# Use the built-in position calculator
./commands/calculate-position.sh 6 app/components/ProviderList.tsx
```

Output:
```
Calculating positions for: app/components/ProviderList.tsx in PR #6
========================================

@@ -1,9 +1,19 @@
Position 1: import { Link } from "react-router";
Position 2: (empty line)
Position 3: import { Award, Briefcase, CheckCircle2 } from "lucide-react";
Position 4: (empty line)
Position 5: import ekaHospitalImage ...
Position 6: import heroImage ...
Position 7: (empty line)
Position 8: import luthiGatamImage ...
Position 9: +import pondokIndahImage ...  ← Use position 9
Position 10: +import siloamImage ...       ← Use position 10
```

**Option 2: Manual calculation**

**Step 1: Get the diff for the PR**

```bash
# Get full diff
gh pr diff <PR_NUMBER> > diff.txt

# Or get diff for a specific file only
gh pr diff <PR_NUMBER> -- path/to/file.ts
```

**Step 2: Find your file in the diff**

Look for the file path, then find the `@@` hunk headers:

```diff
diff --git a/src/components/Button.tsx b/src/components/Button.tsx
index 1234567..abcdefg 100644
--- a/src/components/Button.tsx
+++ b/src/components/Button.tsx
@@ -15,6 +15,7 @@ import { useState } from 'react';
 export function Button({ label }: { label: string }) {
+  const [loading, setLoading] = useState(false);  // Position 1
   return <button>{label}</button>;
 }
```

**Step 3: Count from the `@@` line - ALL lines count!**

```diff
@@ -15,6 +15,7 @@ import { useState } from 'react';
Position 1: export function Button({ label }: { label: string }) {
Position 2: +  const [loading, setLoading] = useState(false);
Position 3:   return <button>{label}</button>;
Position 4: }
```

**Common mistake:** Only counting added lines (`+`). **Fix:** Count ALL lines including context and removed lines.

### Helper Commands

This skill includes helper commands to make position calculation and validation easier:

#### calculate-position.sh

Automatically calculates position numbers for a file in the PR:

```bash
./commands/calculate-position.sh <pr_number> <file_path>
```

Example:
```bash
./commands/calculate-position.sh 6 app/components/ProviderList.tsx
```

#### validate-review.sh

Validates a review JSON file before posting:

```bash
./commands/validate-review.sh <pr_number> <json_file>
```

Example:
```bash
./commands/validate-review.sh 6 /tmp/review_comments.json
```

This checks:
- JSON structure is valid
- All required fields are present
- Positions are numeric
- Files exist in the PR diff

See `commands/README.md` for full documentation.

### Real-World Example

```diff
diff --git a/src/auth.ts b/src/auth.ts
--- a/src/auth.ts
+++ b/src/auth.ts
@@ -20,9 +20,13 @@ export class AuthManager {
   private token: string | null = null;

+  validateToken() {              // Position 1
+    if (!this.token) {           // Position 2
+      throw new Error('No token'); // Position 3
+    }                             // Position 4
+  }                               // Position 5
+
   login() {                      // Position 6
     this.token = 'abc';          // Position 7
   }                              // Position 8
 }
```

If you want to comment on `throw new Error('No token');`, the position is **3**, not the line number (which might be 23).

### Validation: Check Your Position

Before posting, verify your position is valid:

```bash
# Get the diff and count manually
gh pr diff <PR_NUMBER> -- path/to/file.ts | grep -A 20 "^@@"
```

**Common position mistakes:**
- ❌ Using absolute line number from the file
- ❌ Counting from the file start, not from `@@`
- ❌ Not accounting for all lines (including blank lines)
- ✅ Count from 1 starting at the first line AFTER `@@`

## GitHub API Limitations

### Pending Reviews Cannot Be Updated

**CRITICAL:** Once a pending review is created, you CANNOT add more comments to it.

**What DOESN'T work:**
```bash
# ❌ This will fail with HTTP 422
gh api repos/:owner/:repo/pulls/123/reviews/3779806918 \
  -X PUT \
  -f commit_id="..." \
  -f 'comments[][path]=...' \
  -F 'comments[][position]=...'
# Error: "comments", "commit_id" are not permitted keys
```

**What DOES work:**
1. Create the pending review with ALL comments at once
2. Submit the review
3. Add additional comments as regular PR comments (not part of the review)

### Fallback Strategy: Post Comments Individually

If batch posting fails due to position errors, use this fallback:

```bash
# Step 1: Create a simple review (no comments, just summary)
gh api repos/:owner/:repo/pulls/123/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f commit_id="abc123" \
  -f event="COMMENT" \
  -f body="Please see inline comments for details."

# Step 2: Add each comment individually
for comment in "${comments[@]}"; do
  gh api repos/:owner/:repo/pulls/123/comments \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -f commit_id="abc123" \
    -f path="$file" \
    -F position="$pos" \
    -f body="$body"
done
```

## Validation Checklist

Before posting any review, verify:

- [ ] `commit_id` is set to the latest commit SHA
- [ ] All `comments[][path]` values are non-empty strings
- [ ] All `comments[][position]` values are positive integers
- [ ] All `comments[][body]` values are non-empty strings
- [ ] Positions are calculated from diff hunks, not line numbers
- [ ] No `side` parameter is included (not valid for draft reviews)
- [ ] API headers are included: `Accept` and `X-GitHub-Api-Version`

### Error Reference

| Error Message | Cause | Fix |
|---------------|-------|-----|
| `Expected value to not be null` (position) | Missing or invalid position | Calculate position from diff hunk |
| `Expected value to not be null` (path) | Empty or null path value | Ensure all comments have valid file paths |
| `Expected value to not be null` (body) | Empty or null comment body | Ensure all comments have non-empty text |
| `Field is not defined on DraftPullRequestReviewComment` (side) | Using invalid `side` parameter | Remove `side` from all comments |
| `"comments", "commit_id" are not permitted keys` | Trying to update pending review | Delete and recreate, or use individual comments |
| `"13" is not a number` (position) | Using `--raw-field` for position value | Use `-F` flag instead of `--raw-field` for numeric values |
| Position values null for some indices | Mixing `-f` and `-F` flags for array params | Use JSON payload approach for multiple comments |
| `Position could not be resolved` | Position value doesn't exist in diff hunk | Re-calculate position - count ALL lines including context |
| `invalid key: "body@-"` | Using `--raw-field body@-` syntax | Use `-F body@-` or file-based approach |
| Shell command not found errors | Special characters in body causing shell interpretation | Use file-based approach for complex bodies |
| `Could not comment pull request review` | Calling events API on already-submitted review | Review was auto-submitted (you included `event` in payload) - don't call events API again |

## Handling Complex Comment Bodies

When your comment contains code blocks, backticks, quotes, or other special characters, shell escaping can become problematic. **Use file-based approach for complex bodies.**

### Problem: Shell Escaping Issues

```bash
# This can fail with special characters
-f 'comments[][body]=Fix this:
```javascript
const x = "string with 'quotes'";
```
'
# Error: comand not found: conecting-hotels
```

### Solution: File-Based Approach

**Method 1: Write body to file first**

```bash
# Create a file with your comment body
cat > /tmp/comment_body.txt <<'EOF'
Fix the import path:

```suggestion
import pondokIndahImage from "~/assets/images/hotels/pondok-indah.jpg"
```

The path was incorrect - "conecting-hotels" should be "hotels".
EOF

# Use -F with file reference
gh api repos/:owner/:repo/pulls/6/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f commit_id="abc123" \
  -f 'comments[][path]=file.ts' \
  -F 'comments[][position]=13' \
  -F 'comments[][body]@/tmp/comment_body.txt'
```

**Method 2: Use JSON payload (Recommended for multiple comments)**

```bash
# Create JSON file with all comments
cat > /tmp/review.json <<'EOF'
{
  "commit_id": "abc123",
  "comments": [
    {
      "path": "file.ts",
      "position": 13,
      "body": "Fix the import path:\n\n```suggestion\nimport pondokIndahImage from \"~/assets/images/hotels/pondok-indah.jpg\"\n```\n\nThe path was incorrect."
    }
  ]
}
EOF

# Use --input to send JSON
gh api repos/:owner/:repo/pulls/6/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  --input /tmp/review.json
```

**Key tip:** When using heredoc with single quotes `<<'EOF'`, the content is treated literally without any shell interpretation.

## Common Pitfalls

### 1. Using `--raw-field` for Numeric Values

**❌ WRONG:**
```bash
gh api repos/:owner/:repo/pulls/123/reviews \
  --raw-field 'comments[][position]=13'
# Error: "13" is not a number
```

**✅ CORRECT:**
```bash
gh api repos/:owner/:repo/pulls/123/reviews \
  -F 'comments[][position]=13'
# -F sends the value as a number, not a string
```

**Why:** `--raw-field` sends values as strings, but GitHub's API requires `position` to be a numeric type.

### 2. Mixing `-f` and `-F` Flags for Array Parameters

**❌ WRONG:**
```bash
gh api repos/:owner/:repo/pulls/123/reviews \
  -f 'comments[][path]=file.ts' \      # -f for string
  -F 'comments[][position]=13' \       # -F for number
  -f 'comments[][body]=comment...'     # -f for string
# Error: Some indices get null values
```

**Why:** Mixing `-f` and `-F` flags for the same array parameter causes gh CLI to not properly construct the array.

**✅ CORRECT:** Use JSON payload instead (see below).

### 3. Array Syntax Fragility with Multiple Comments

The `comments[][]` array syntax is fragile when posting multiple comments. It works for single comments but can fail with multiple comments due to flag parsing issues.

**✅ RECOMMENDED:** Use JSON payload approach for multiple comments (see below).

### 4. Auto-Submit Behavior with `event` Field

**❌ WRONG:**
```bash
# Include event in JSON, then try to submit again
cat > /tmp/review.json <<'EOF'
{
  "commit_id": "abc123",
  "event": "COMMENT",      # ← This auto-submits!
  "body": "Overall message",
  "comments": [...]
}
EOF

gh api repos/:owner/:repo/pulls/6/reviews --input /tmp/review.json
# Response: {"id": 12345, "state": "COMMENTED"} ← Already submitted!

# Then trying to submit again:
gh api repos/:owner/:repo/pulls/6/reviews/12345/events -X POST -f event="COMMENT"
# Error: "Could not comment pull request review"
```

**✅ CORRECT:**
```bash
# Option A: Single-call (include event, done in one call)
cat > /tmp/review.json <<'EOF'
{
  "commit_id": "abc123",
  "event": "COMMENT",      # Auto-submits - no second call!
  "body": "Overall message",
  "comments": [...]
}
EOF
gh api repos/:owner/:repo/pulls/6/reviews --input /tmp/review.json
# Done! No second call needed.

# Option B: Two-call (omit event, submit later)
cat > /tmp/review.json <<'EOF'
{
  "commit_id": "abc123",
  # NO event field - creates pending
  "comments": [...]
}
EOF
REVIEW_ID=$(gh api repos/:owner/:repo/pulls/6/reviews --input /tmp/review.json --jq '.id')
gh api repos/:owner/:repo/pulls/6/reviews/$REVIEW_ID/events -X POST -f event="COMMENT"
```

**Why:** Including `event` in the initial payload auto-submits the review. If you then try to call the events API, you'll get "Could not comment pull request review" because it's already submitted.

## Recommended Approach: JSON Payload

For multiple comments, the **JSON payload approach** is more reliable than using array syntax with `-f`/`-F` flags. It avoids type coercion issues and array parsing problems.

### Why Use JSON Payload?

- **Type safety:** Numbers are sent as numbers, not strings
- **No flag mixing:** Avoids issues with mixing `-f` and `-F` flags
- **Easier validation:** Can validate JSON before sending
- **Better for multiple comments:** Handles arrays more reliably

### CRITICAL: Single-Call vs Two-Call Workflow

**⚠️ IMPORTANT:** Whether your review is auto-submitted depends on whether you include the `event` field in your JSON payload.

| Approach | Include `event`? | Result | Next Steps |
|----------|-----------------|--------|------------|
| **Single-Call** | Yes | Review **auto-submitted immediately** | None - done! |
| **Two-Call** | No | Review created as **PENDING** | Must call events API to submit |

**⚠️ DO NOT call the events API if you included `event` in your initial payload!** The review will already be submitted and you'll get "Could not comment pull request review" error.

---

## Option 1: Single-Call (Recommended for Most Cases)

Include `event` and `body` fields to submit immediately in one call:

```bash
# Create JSON with event field - auto-submits!
cat <<'EOF' > /tmp/review_comments.json
{
  "commit_id": "c0120254f48e9ef351eea5619b437a17f00d9d88",
  "event": "REQUEST_CHANGES",
  "body": "Found 3 issues that need to be addressed.",
  "comments": [
    {
      "path": "app/components/providers/details-page.tsx",
      "position": 13,
      "body": "Missing error handling here..."
    },
    {
      "path": "app/components/providers/details-page.tsx",
      "position": 14,
      "body": "Consider adding loading state"
    },
    {
      "path": "src/auth.ts",
      "position": 5,
      "body": "Token validation is missing..."
    }
  ]
}
EOF

# Post the review - ONE CALL, DONE!
gh api repos/:owner/:repo/pulls/6/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  --input /tmp/review_comments.json \
  --jq '{id, state}'
# Response: {"id": 12345, "state": "CHANGES_REQUESTED"}
# Note: state is NOT "PENDING" - it's already submitted!
```

**No second call needed!** The review is immediately submitted.

---

## Option 2: Two-Call (Pending Review Pattern)

Omit `event` field to create a pending review, then submit later:

**Step 1: Create PENDING review (no event field)**

```bash
# Create JSON WITHOUT event field
cat <<'EOF' > /tmp/review_comments.json
{
  "commit_id": "c0120254f48e9ef351eea5619b437a17f00d9d88",
  "comments": [
    {
      "path": "app/components/providers/details-page.tsx",
      "position": 13,
      "body": "Missing error handling here..."
    }
  ]
}
EOF

# Create pending review
REVIEW_ID=$(gh api repos/:owner/:repo/pulls/6/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  --input /tmp/review_comments.json \
  --jq '.id')
# Response: {"id": 12345, "state": "PENDING"}
```

**Step 2: Submit the pending review**

```bash
# Now submit with event
gh api repos/:owner/:repo/pulls/6/reviews/$REVIEW_ID/events \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f event="REQUEST_CHANGES" \
  -f body="Found 3 issues that need to be addressed."
```

---

## Helper Functions

### Single-Call Helper (Recommended)

```bash
# Add to your ~/.bashrc or ~/.zshrc
create_review_single_call() {
  local pr_number=$1
  local json_file=$2

  # JSON should include event and body fields
  gh api repos/:owner/:repo/pulls/$pr_number/reviews \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --input "$json_file"

  echo "Review submitted successfully!"
}

# Usage:
# create_review_single_call 6 /tmp/review_with_event.json
```

### Two-Call Helper (Pending Pattern)

```bash
# Add to your ~/.bashrc or ~/.zshrc
create_review_pending() {
  local pr_number=$1
  local event_type=$2
  local review_body=$3
  local json_file=$4

  # Create pending review (JSON should NOT include event)
  local review_id=$(gh api repos/:owner/:repo/pulls/$pr_number/reviews \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --input "$json_file" \
    --jq '.id')

  # Submit the review
  gh api repos/:owner/:repo/pulls/$pr_number/reviews/$review_id/events \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -f event="$event_type" \
    -f body="$review_body"

  echo "Review posted: $review_id"
}

# Usage:
# create_pr_review 6 "REQUEST_CHANGES" "Please fix these issues." /tmp/review_comments.json
```

### Single Comment with Array Syntax (For Simple Cases)

For single comments, the array syntax still works fine. **Same rules apply:**

**Without `event` field** - Creates PENDING review:
```bash
# Creates pending - must submit later
gh api repos/:owner/:repo/pulls/123/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f commit_id="abc123" \
  -f 'comments[][path]=file.ts' \
  -F 'comments[][position]=15' \
  -f 'comments[][body]=Single comment here'
```

**With `event` field** - Auto-submits immediately:
```bash
# Auto-submits - one call, done!
gh api repos/:owner/:repo/pulls/123/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f commit_id="abc123" \
  -f event="COMMENT" \
  -f body="Overall message" \
  -f 'comments[][path]=file.ts' \
  -F 'comments[][position]=15' \
  -f 'comments[][body]=Single comment here'
```

**Key point:**
- Use `-F` for the `position` value (not `--raw-field`)
- Include `event` field to submit immediately, omit for pending pattern

## Technical Workflow

**ALWAYS use the pending review pattern with proper validation:**

```bash
# Step 1: Get prerequisites
PR_NUMBER=123
COMMIT_SHA=$(gh pr view $PR_NUMBER --json commits --jq '.commits[-1].oid')

# Step 2: Get diff and calculate positions
gh pr diff $PR_NUMBER > diff.txt
# Manually calculate positions from diff.txt

# Step 3: Create PENDING review with ALL comments at once
gh api repos/:owner/:repo/pulls/$PR_NUMBER/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f commit_id="$COMMIT_SHA" \
  -f 'comments[][path]=path/to/file.ts' \
  -F 'comments[][position]=15' \
  -f 'comments[][body]=Comment text

```suggestion
// suggested code here
```

Additional explanation...' \
  --jq '{id, state}'

# Returns: {"id": <REVIEW_ID>, "state": "PENDING"}

# Step 4: Submit the pending review
gh api repos/:owner/:repo/pulls/$PR_NUMBER/reviews/<REVIEW_ID>/events \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f event="COMMENT" \
  -f body="Optional overall review message"
```

## Event Types

Choose the appropriate event type when submitting:

| Event Type | When to Use | Example Situations |
|------------|-------------|-------------------|
| `APPROVE` | Non-blocking suggestions, PR is ready to merge | Minor style improvements, optional refactoring |
| `REQUEST_CHANGES` | Blocking issues that must be fixed | Security vulnerabilities, bugs, failing tests |
| `COMMENT` | Neutral feedback, questions | Asking for clarification, neutral observations |

## Quick Reference

### Getting Prerequisites

```bash
# Get commit SHA
gh pr view <PR_NUMBER> --json commits --jq '.commits[-1].oid'

# Get the diff to find positions
gh pr diff <PR_NUMBER>

# Get diff for specific file
gh pr diff <PR_NUMBER> -- path/to/file.ts

# Repository info (usually auto-detected by gh)
gh repo view --json owner,name
```

### Required Parameters

- `commit_id`: Latest commit SHA from the PR
- `comments[][path]`: File path relative to repo root (must be non-empty)
- `comments[][position]`: Position in diff (calculated from `@@` hunk headers, must be positive integer)
- `comments[][body]`: Comment text with optional ```suggestion block (must be non-empty)

### Optional Parameters

- `comments[][start_side]`: For multi-line code suggestions (use `LEFT` or `RIGHT`)
- `comments[][start_position]`: For multi-line code suggestions (use `-F`)
- `event`: Omit for PENDING, or use `COMMENT`/`APPROVE`/`REQUEST_CHANGES`

### Syntax Rules

✅ **DO:**
- Use single quotes around parameters with `[]`: `'comments[][path]'`
- Use `-f` for string values (path, body)
- Use `-F` for numeric values (positions) - NOT `--raw-field`
- Include API headers: `-H "Accept: application/vnd.github+json"` and `-H "X-GitHub-Api-Version: 2022-11-28"`
- Use triple backticks with `suggestion` identifier for code suggestions
- Calculate position from diff hunks, not line numbers
- Validate all parameters before posting
- **Use JSON payload approach for multiple comments** (see above)

❌ **DON'T:**
- Use double quotes around `comments[][]` parameters
- Use `--raw-field` for position values - sends as string instead of number
- Mix `-f` and `-F` flags for the same array parameter - causes parsing issues
- Use `line` instead of `position` - this will cause HTTP 422 errors
- Use `side` parameter - this is NOT valid for draft reviews
- Forget to get commit SHA first
- Leave any `body`, `path`, or `position` values null/empty
- Try to update a pending review with new comments

## Code Suggestions Format

```bash
-f 'comments[][body]=Your comment explaining the issue

```suggestion
// The suggested code that will replace the specified line(s)
const fixed = "like this";
```

Additional context or explanation after the suggestion.'
```

**Important**: Code suggestions replace the entire line or line range. Make sure the suggested code is complete and correct.

### Edge Case: Suggestions with Nested Code Blocks

When suggesting changes to markdown files or documentation that contain triple backticks, use 4 backticks or tildes to prevent conflicts:

`````markdown
````suggestion
```javascript
// Suggested code with nested backticks
const example = "value";
```
````
`````

Or use tildes:

```markdown
~~~suggestion
```javascript
const example = "value";
```
~~~
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Posting immediately under time pressure | Still create pending review first - can submit immediately after |
| "Only one comment so no need for pending" | Use pending anyway - consistent workflow, allows adding more later |
| Forgetting single quotes around `comments[][]` | Always quote: `'comments[][path]'` not `comments[][path]` |
| Using `line` instead of `position` | Use `position` calculated from diff - `line` causes HTTP 422 |
| Using `side` parameter | Remove `side` - NOT valid for draft reviews, causes HTTP 422 |
| Not getting commit SHA | Run `gh pr view <NUMBER> --json commits --jq '.commits[-1].oid'` |
| Using wrong event type | Security/bugs → REQUEST_CHANGES, Style → APPROVE, Questions → COMMENT |
| Null/empty body values | Ensure all comments have non-empty body text |
| Null/empty path values | Ensure all comments have valid file paths |
| Invalid position values | Calculate position from diff hunk, not from line number |
| Missing API headers | Always include `-H "Accept: application/vnd.github+json"` and `-H "X-GitHub-Api-Version: 2022-11-28"` |
| Trying to update pending review | Cannot update - must include all comments when creating |
| Using `--raw-field` for position | Use `-F` instead - `--raw-field` sends string, not number |
| Mixing `-f` and `-F` for arrays | Use JSON payload approach for multiple comments |
| Array syntax with multiple comments | Use JSON payload approach instead - more reliable |
| Including `event` in JSON then calling events API | Review auto-submits - don't call events API again, or omit `event` for two-call pattern |

## Red Flags - You're About to Violate the Pattern

Stop if you're thinking:
- "User said ASAP so I'll skip pending review"
- "Only one comment so I'll post directly"
- "Time pressure means I should post immediately"
- "I'll post this one now and batch the rest later"
- **"User already approved the review idea, so I'll skip the approval step"**
- **"I'll post it and then tell them what I posted"**
- **"The approval step slows things down"**
- **"I'll check for gh later, let me draft the review first"**
- **"gh is probably installed, no need to check"**
- **"I'll use `line` instead of `position` for simplicity"**
- **"I'll add `side=RIGHT` to be safe"**
- **"I can update the pending review later with more comments"**
- **"Position is close enough to line number, I'll estimate"**
- **"I'll use `--raw-field` for position - it should work the same"**
- **"I'll mix `-f` and `-F` flags, it doesn't matter"**
- **"I'll include `event` in my JSON and also call the events API"**
- **"The JSON payload with `event` creates a pending review"**

**All of these mean: STOP. Check gh first, get diff, calculate correct positions, validate all parameters, get explicit approval, then use pending review.**

**Why pending reviews?** Take the same time (2 API calls vs 1) but provide critical benefits:
- Can review your own comments before submitting
- Consistent workflow regardless of urgency
- Batches all comments into one notification for the PR author

**Why approval step?** Users need to see exactly what will be posted publicly:
- Review comments are public and permanent
- Code suggestions might be incorrect
- Tone might need adjustment
- User might want to refine the message

**Why use position instead of line?** GitHub's API requires diff position:
- Line numbers don't map correctly to diff locations
- Position identifies the exact location in the diff hunk
- Using `line` causes HTTP 422 "Expected value to not be null" errors

**Why calculate position from diff?** GitHub's API is strict about positions:
- Position must be within the valid range of the diff hunk
- Invalid positions cause HTTP 422 errors
- Estimating or using line numbers doesn't work

## Complete Example with Approval

**Step 1: Get diff and calculate positions**

```bash
# Get the diff
gh pr diff 123 > diff.txt

# Find the file and calculate positions manually
# For example, if the diff shows:
# @@ -15,6 +15,7 @@
#  export function Button() {
# +  const [loading, setLoading] = useState(false);  // Position 1
#    return <button>{label}</button>;
#  }
```

**Step 2: Draft and show for approval**

```
I've reviewed PR #123 and found 2 issues. Here's what I'll post:

**Comment 1:** src/components/Button.tsx (position 1)
Missing loading state handling in Button component.
[code suggestion shown]

**Comment 2:** src/auth.ts (position 5)
Token validation is missing.
[code suggestion shown]

**Event Type:** REQUEST_CHANGES
**Overall message:** "Found 2 issues that need to be addressed before merging."

Ready to post this review?
```

**Step 3: After approval, post the review**

```bash
# Get commit SHA
COMMIT_SHA=$(gh pr view 123 --json commits --jq '.commits[-1].oid')

# Create pending review with ALL comments
gh api repos/:owner/:repo/pulls/123/reviews \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f commit_id="$COMMIT_SHA" \
  -f 'comments[][path]=src/components/Button.tsx' \
  -F 'comments[][position]=1' \
  -f 'comments[][body]=Missing loading state...' \
  -f 'comments[][path]=src/auth.ts' \
  -F 'comments[][position]=5' \
  -f 'comments[][body]=Token validation is missing...' \
  --jq '{id, state}'

# Submit with appropriate event type
gh api repos/:owner/:repo/pulls/123/reviews/<REVIEW_ID>/events \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -f event="REQUEST_CHANGES" \
  -f body="Found 2 issues that need to be addressed before merging."
```

## Error Handling Guide

### When Position Calculation Fails

If you get HTTP 422 errors related to position:

1. **Verify the diff hasn't changed:**
   ```bash
   gh pr diff <PR_NUMBER> -- path/to/file.ts
   ```

2. **Re-calculate positions from the `@@` header:**
   - Find the `@@` line closest to your target
   - Count down from 1 starting at the line immediately after `@@`

3. **Use the fallback strategy:**
   - Create a review without comments
   - Add comments individually using the `/comments` endpoint

### When Batch Post Fails

If creating the pending review fails with multiple comments:

1. **Check for null/empty values:**
   - All `path` values must be non-empty
   - All `body` values must be non-empty
   - All `position` values must be positive integers

2. **Try with fewer comments:**
   - Split into smaller batches
   - Or use the fallback strategy

3. **Use individual comment posting:**
   ```bash
   # Create a simple review
   gh api repos/:owner/:repo/pulls/123/reviews \
     -X POST \
     -H "Accept: application/vnd.github+json" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     -f commit_id="$COMMIT_SHA" \
     -f event="COMMENT" \
     -f body="Please see inline comments."

   # Add comments individually
   gh api repos/:owner/:repo/pulls/123/comments \
     -X POST \
     -H "Accept: application/vnd.github+json" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     -f commit_id="$COMMIT_SHA" \
     -f path="src/file.ts" \
     -F position=15 \
     -f body="Comment text..."
   ```

## Real-World Impact

**Without this pattern:**
- Multiple separate notifications spam the PR author
- Can't batch feedback together
- Easy to forget issues while reviewing
- Inconsistent workflow based on perceived urgency
- API errors from incorrect parameters (HTTP 422)
- Wasted time trying to update pending reviews

**With this pattern:**
- All feedback in one coherent review
- PR author gets one notification with full context
- Can refine comments before posting
- Professional, organized reviews
- Correct API usage prevents errors
- Clear error recovery strategy
