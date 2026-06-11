---
name: github-pr-review
description: Use when reviewing GitHub pull requests with gh CLI - creates pending reviews with code suggestions, batches comments, and chooses appropriate event types (COMMENT/APPROVE/REQUEST_CHANGES)
allowed-tools: AskUserQuestion, Bash
---

# GitHub PR Review

## Overview

Workflow for reviewing GitHub pull requests using `gh api` to create pending reviews with code suggestions. **Always use pending reviews to batch comments, even under time pressure.**

**CRITICAL: Always get explicit user approval before posting any review comments.** Show exactly what will be posted and ask for yes/no confirmation using AskUserQuestion.

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

1. **Check gh CLI is installed** - Run `gh --version` to verify
2. **Draft the review** - Analyze PR and prepare all comments
3. **Show user exactly what will be posted** - Use AskUserQuestion with yes/no
4. **Get explicit approval** - Wait for user confirmation
5. **Post the review** - Only after approval
6. **Verify inline placement** - Confirm every comment landed on the correct line

### Approval Pattern

Before posting ANY review, use AskUserQuestion to show:
- File and line number for each comment
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

### Technical Workflow

**ALWAYS use the pending review pattern, even for single comments.**

**CRITICAL: Use `python3` to build the JSON payload and pipe it with `--input -`.** Do NOT use `-f 'comments[][field]=value'` flags — `gh api` appends each `[][...]` as a separate scalar array element rather than grouping fields into objects, so comments end up as a flat list instead of an array of objects. GitHub then ignores the line information and falls back to posting everything as a single review body.

```bash
# Step 1: Create PENDING review — build JSON with python3, pipe to gh api
python3 -c '
import json
payload = {
    "commit_id": "COMMIT_SHA",
    "comments": [
        {
            "path": "path/to/file.ts",
            "line": LINE_NUMBER,
            "side": "RIGHT",
            "body": "Comment text\n\n```suggestion\n// suggested code here\n```\n\nAdditional explanation..."
        }
    ]
}
print(json.dumps(payload))
' | gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews \
  -X POST \
  --input - \
  --jq '{id, state}'

# Returns: {"id": REVIEW_ID, "state": "PENDING"}

# Step 2: Submit the pending review
gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews/REVIEW_ID/events \
  -X POST \
  -f event="COMMENT" \
  -f body="Optional overall review message"

# Step 3: Verify every comment landed on the correct line
gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews/REVIEW_ID/comments \
  --jq '.[] | {path, line, preview: .body[0:80]}'
```

**What to look for in Step 3:** Every comment should have a non-null `line` matching what you intended. A null `line` means the comment fell back to the review body — re-check the `path` (must match the diff exactly) and `line` (must be a line present in the diff).

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

# Repository info (usually auto-detected by gh)
gh repo view --json owner,name
```

### JSON Payload Fields

Build the payload as a Python dict and pipe with `--input -`:

| Field | Type | Notes |
|-------|------|-------|
| `commit_id` | string | Latest commit SHA from the PR |
| `comments[].path` | string | File path relative to repo root |
| `comments[].line` | integer | End line number in the file |
| `comments[].side` | string | `"RIGHT"` for added/modified lines, `"LEFT"` for deleted |
| `comments[].body` | string | Comment text; embed suggestion block with `\n\`\`\`suggestion\n...\n\`\`\`` |
| `comments[].start_line` | integer | (optional) Start line for multi-line suggestions |
| `comments[].start_side` | string | (optional) Required when `start_line` is set |

### Construction Rules

✅ **DO:**
- Build the payload as a Python dict and use `json.dumps()` to serialize it
- Pipe the JSON to `gh api` with `--input -`
- Use `\n` for newlines inside body strings (Python handles escaping automatically)
- Embed suggestion blocks inside the body string: `"body": "explanation\n\n\`\`\`suggestion\n...\n\`\`\`"`
- Verify after posting that every comment has a non-null `line`

❌ **DON'T:**
- Use `-f 'comments[][path]=...'` / `-F 'comments[][line]=...'` flags — they create a flat scalar array, not an array of objects
- Hand-write JSON strings with literal backticks or newlines in the shell — use Python to serialize
- Forget to get the commit SHA before building the payload

## Code Suggestions Format

Place the suggestion block inside the `body` string using `\n` for newlines. Python's `json.dumps` will escape the content correctly:

```python
{
    "path": "src/utils.ts",
    "line": 42,
    "side": "RIGHT",
    "body": "Use optional chaining here to avoid the null-check boilerplate.\n\n```suggestion\nconst value = obj?.nested?.field;\n```"
}
```

For multi-line suggestions, also set `start_line` (and `start_side`) to span the replacement range:

```python
{
    "path": "src/utils.ts",
    "start_line": 40,
    "start_side": "RIGHT",
    "line": 42,
    "side": "RIGHT",
    "body": "Collapse these three lines.\n\n```suggestion\nconst value = obj?.nested?.field;\n```"
}
```

**Important**: The suggestion replaces the entire line range. Make sure the suggested code is complete and correct.

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
| Using `-f 'comments[][path]=...'` flags | Build a Python dict and pipe with `--input -` — `-f [][]` creates flat scalar arrays, not objects |
| Not getting commit SHA | Run `gh pr view <NUMBER> --json commits --jq '.commits[-1].oid'` |
| Using wrong event type | Security/bugs → REQUEST_CHANGES, Style → APPROVE, Questions → COMMENT |
| Skipping post-post verification | Run `gh api .../reviews/REVIEW_ID/comments --jq '.[] | {path, line}'` to confirm inline placement |

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
- **"I'll use `-f 'comments[][]...'` flags, it's simpler"**
- **"I'll skip the verification step, the post succeeded so it must be fine"**

**All of these mean: STOP. Check gh first, get explicit approval, use pending review with JSON payload, then verify.**

**Why pending reviews?** Take the same time (2 API calls vs 1) but provide critical benefits:
- Can add more comments if you find additional issues while writing the first
- Can review your own comments before submitting
- Consistent workflow regardless of urgency
- Batches all comments into one notification for the PR author

**Why JSON payload (not `-f` flags)?** The `gh api` `-f 'comments[][field]=value'` syntax appends each value as a separate scalar element in the array. GitHub receives `"comments": ["file.ts", 20, "RIGHT", "text"]` instead of `"comments": [{"path": "file.ts", "line": 20, ...}]`. Without the object structure, GitHub has no line information and falls back to attaching everything to the review body.

**Why approval step?** Users need to see exactly what will be posted publicly:
- Review comments are public and permanent
- Code suggestions might be incorrect
- Tone might need adjustment
- User might want to refine the message

**Why verification step?** Even with the correct JSON approach, a wrong `path` or a `line` not present in the diff will silently drop the inline placement. Verification catches this before the user discovers it on GitHub.

## Complete Example with Approval

**Step 1: Draft and show for approval**

First, analyze the PR and draft your comments. Then use AskUserQuestion:

```
I've reviewed PR #123 and found 3 issues. Here's what I'll post:

**Comment 1:** src/auth.ts line 20
Token expiry validation is missing...
[code suggestion shown]

**Comment 2:** src/auth.ts line 35
Missing error handling...
[code suggestion shown]

**Comment 3:** tests/auth.test.ts line 12
Missing error case test...
[code suggestion shown]

**Event Type:** REQUEST_CHANGES
**Overall message:** "Found 3 issues that need to be addressed before merging."

Ready to post this review?
```

**Step 2: After approval, post the review**

```bash
# Create pending review — JSON payload ensures comments are objects with line info
python3 -c '
import json
payload = {
    "commit_id": "abc123",
    "comments": [
        {
            "path": "src/auth.ts",
            "line": 20,
            "side": "RIGHT",
            "body": "Token expiry validation is missing.\n\n```suggestion\nif (token.expiresAt < Date.now()) throw new AuthError(\"token expired\");\n```"
        },
        {
            "path": "src/auth.ts",
            "line": 35,
            "side": "RIGHT",
            "body": "Missing error handling for the fetch call.\n\n```suggestion\nconst res = await fetch(url).catch(err => { throw new NetworkError(err); });\n```"
        },
        {
            "path": "tests/auth.test.ts",
            "line": 12,
            "side": "RIGHT",
            "body": "Add a test case for the expired-token error path."
        }
    ]
}
print(json.dumps(payload))
' | gh api repos/OWNER/REPO/pulls/123/reviews \
  -X POST \
  --input - \
  --jq '{id, state}'

# Submit with appropriate event type
gh api repos/OWNER/REPO/pulls/123/reviews/REVIEW_ID/events \
  -X POST \
  -f event="REQUEST_CHANGES" \
  -f body="Found 3 issues that need to be addressed before merging."
```

**Step 3: Verify inline placement**

```bash
gh api repos/OWNER/REPO/pulls/123/reviews/REVIEW_ID/comments \
  --jq '.[] | {path, line, preview: .body[0:80]}'
```

Expected output — every comment should have a non-null `line`:

```json
{"path": "src/auth.ts", "line": 20, "preview": "Token expiry validation is missing."}
{"path": "src/auth.ts", "line": 35, "preview": "Missing error handling for the fetch call."}
{"path": "tests/auth.test.ts", "line": 12, "preview": "Add a test case for the expired-token error path."}
```

If any `line` is `null`, that comment fell back to the review body. Check that the `path` exactly matches the filename in the diff and that the `line` number is present in the diff hunk.

## Real-World Impact

**Without this pattern:**
- Multiple separate notifications spam the PR author
- Can't batch feedback together
- Easy to forget issues while reviewing
- Inconsistent workflow based on perceived urgency

**With this pattern:**
- All feedback in one coherent review
- PR author gets one notification with full context
- Can refine comments before posting
- Professional, organized reviews
- Inline comments confirmed to land on the correct lines
