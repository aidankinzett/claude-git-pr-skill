# Helper Commands

This directory contains helper commands to make PR reviews easier and more reliable.

## Available Commands

### Hooks

#### pre-commit (NEW in v2.1.0)

Validate review JSON files before committing to ensure positions are valid.

**Installation:**
```bash
# Copy the hook to your .git/hooks directory
cp github-pr-review/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**What it does:**
- Checks for review JSON files being committed
- Validates JSON structure using jq (if available)
- Shows positions found in the JSON
- Reminds you to run validate-review.sh before committing

**To disable:**
```bash
rm .git/hooks/pre-commit
```

### Helper Commands

### calculate-position.sh

Calculate position numbers in the diff for a given file. This helps you find the correct position values to use in your review comments.

**Usage:**
```bash
./commands/calculate-position.sh <pr_number> <file_path>
```

**Example:**
```bash
./commands/calculate-position.sh 6 app/components/ProviderList.tsx
```

**Output:**
```
Calculating positions for: app/components/ProviderList.tsx in PR #6
========================================

@@ -1,9 +1,19 @@
Position 1: import { Link } from "react-router";
Position 2: (empty line)
Position 3: import ekaHospitalImage ...
Position 4: import heroImage ...
...
Position 9: import pondokIndahImage ...  ← Use position 9 in your review
Position 10: import siloamImage ...      ← Use position 10 in your review
```

### multi-agent-review.sh (NEW in v2.0.0)

Launches 5 specialized review agents in parallel and consolidates findings. This is the primary entry point for the multi-agent review system.

**Usage:**
```bash
./commands/multi-agent-review.sh <pr_number> <commit_sha> [output_dir]
```

**Example:**
```bash
./commands/multi-agent-review.sh 6 c0120254f48e9ef351eea5619b437a17f00d9d88
```

**Agents Launched (in parallel):**
1. **solid-reviewer** - SOLID principles + Architecture issues
2. **security-reviewer** - Security vulnerabilities
3. **performance-reviewer** - Performance bottlenecks
4. **error-handling-reviewer** - Error handling problems
5. **boundary-reviewer** - Boundary condition errors

**Output:**
```
=== Multi-Agent PR Review Orchestrator ===
PR Number: 6
Commit SHA: c0120254f48e9ef351eea5619b437a17f00d9d88

Launching 5 review agents in parallel...

[10:30:15] Launching SOLID+Architecture...
[10:30:15] Launching Security...
[10:30:15] Launching Performance...
[10:30:15] Launching Error-Handling...
[10:30:15] Launching Boundary-Conditions...

[10:30:42] SOLID+Architecture complete
[10:30:45] Security complete
[10:30:38] Performance complete
[10:30:41] Error-Handling complete
[10:30:44] Boundary-Conditions complete

=== All agents complete ===

Consolidating findings...
Consolidated review: /tmp/pr-review-6/consolidated-review.md
Agent results: /tmp/pr-review-6/agent-results/
```

**Severity Mapping:**
- **P0 (Critical)** - Must fix, blocks merge
- **P1 (High)** - Should fix before merge
- **P2 (Medium)** - Fix or create follow-up
- **P3 (Low)** - Optional improvement

**Event Type Recommendation:**
- P0/P1 findings → `REQUEST_CHANGES`
- P2 findings → `COMMENT`
- P3 findings → `APPROVE` with notes

### validate-position.sh (NEW in v2.1.0)

Validate a single position in a file's diff. This is useful when you want to check if a specific position is valid before posting.

**Usage:**
```bash
./commands/validate-position.sh <pr_number> <file_path> <position>
```

**Example:**
```bash
./commands/validate-position.sh 6 app/root.tsx 5
```

**Output (Valid):**
```
✅ Valid: Position 5 is in range [1-7]

File: app/root.tsx
PR: #6

Diff hunks:
  - @@ -22,7 +22,7 @@ -> positions 1-7
```

**Output (Invalid):**
```
❌ Invalid: Position 25 is out of range.

File: app/root.tsx
PR: #6

Valid positions: [1-7]

Diff hunks:
  - @@ -22,7 +22,7 @@ -> positions 1-7

Suggested fixes:
  1. Use calculate-position.sh to see all positions:
     ./commands/calculate-position.sh 6 app/root.tsx

  2. Check the diff directly:
     gh pr diff 6 -- app/root.tsx
```

### post-review.sh (NEW in v2.1.0)

Post a PR review using JSON payload (avoids markdown escaping issues). This is the recommended way to post reviews with code suggestions.

**Usage:**
```bash
./commands/post-review.sh <pr_number> <json_file> [dry_run]
```

**Examples:**
```bash
# Post the review
./commands/post-review.sh 6 /tmp/review.json

# Dry run to test without posting
./commands/post-review.sh 6 /tmp/review.json dry_run
```

**Features:**
- Validates JSON before posting
- Shows review summary with comment details
- Confirms before posting
- Provides helpful error messages for common issues
- Supports dry-run mode for testing

**Output:**
```
=== GitHub PR Review Poster ===
PR Number: 6
JSON File: /tmp/review.json

1. Validating JSON...
   ✓ JSON is valid

2. Review Summary:
   Commit ID: abc123...
   Event: COMMENT
   Comments: 2
   Body: Found 2 issues that need attention...

3. Comments to be posted:
   app/root.tsx:5 - Missing error handling...
   src/auth.ts:13 - Token validation...

4. Event Type: COMMENT
   Review will be submitted immediately with event=COMMENT

Ready to post this review to PR #6?
Type 'yes' to confirm: yes

5. Posting review...
✓ Review posted successfully!

Review ID: 12345
State: COMMENTED
```

### validate-review.sh

Validate a review JSON file before posting it. This catches common errors like missing fields, invalid positions, or files not in the diff.

**Usage:**
```bash
./commands/validate-review.sh <pr_number> <json_file>
```

**Example:**
```bash
./commands/validate-review.sh 6 /tmp/review_comments.json
```

**Output:**
```
Validating review for PR #6
====================================

1. Validating JSON structure...
   ✓ JSON is valid

2. Checking required fields...
   ✓ commit_id present: c0120254f48e9ef351eea5619b437a17f00d9d88
   ✓ comments array present: 3 comment(s)

3. Validating each comment...
   ✓ app/components/file.ts:13 - Missing error handling...
   ✓ app/components/file.ts:28 - Add loading state...
   ✓ src/auth.ts:5 - Token validation...

4. Checking if files exist in PR diff...
   ✓ app/components/file.ts found in PR diff
   ✓ src/auth.ts found in PR diff

====================================
Validation complete!

Next step: Post the review
  gh api repos/:owner/:repo/pulls/6/reviews --input "/tmp/review_comments.json"
```

## Prerequisites

The `validate-review.sh` command requires `jq` for JSON validation:

```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

## Making Commands Executable

Before using these commands, make them executable:

```bash
chmod +x commands/calculate-position.sh
chmod +x commands/validate-position.sh
chmod +x commands/validate-review.sh
chmod +x commands/post-review.sh
chmod +x commands/multi-agent-review.sh
```

## Complete Workflow

### Multi-Agent Review Workflow (v2.0.0)

1. **Run the multi-agent review orchestrator:**
   ```bash
   ./commands/multi-agent-review.sh 6 c0120254f48e9ef351eea5619b437a17f00d9d88
   ```

2. **Review the consolidated findings:**
   ```bash
   cat /tmp/pr-review-6/consolidated-review.md
   ```

3. **Validate positions before posting:**
   ```bash
   ./commands/validate-review.sh 6 /tmp/pr-review-6/consolidated-review.json
   ```

4. **Get user approval and post the review**

### Manual Workflow (v1.x)

1. **Get the PR diff and find positions:**
   ```bash
   ./commands/calculate-position.sh 6 app/components/file.ts
   ```

2. **Create your review JSON:**
   ```bash
   cp templates/review-template.json /tmp/my_review.json
   # Edit the file with your comments
   ```

3. **Validate before posting:**
   ```bash
   ./commands/validate-review.sh 6 /tmp/my_review.json
   ```

4. **Post the review (recommended):**
   ```bash
   ./commands/post-review.sh 6 /tmp/my_review.json
   ```

   Or post directly with gh api:
   ```bash
   gh api repos/:owner/:repo/pulls/6/reviews \
     -X POST \
     -H "Accept: application/vnd.github+json" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     --input /tmp/my_review.json
   ```
