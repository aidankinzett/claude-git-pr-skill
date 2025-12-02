# GitHub PR Review Skill for Claude Code

A Claude Code skill that ensures consistent, professional GitHub pull request reviews using the `gh` CLI with pending reviews and code suggestions.

## What This Skill Does

This skill teaches Claude to:
- **Always use pending reviews** to batch comments (even under time pressure)
- **Create code suggestions** using the ```suggestion syntax
- **Choose the right event type** (COMMENT, APPROVE, or REQUEST_CHANGES)
- **Use correct `gh api` syntax** with proper quoting and flags

## Installation

### Option 1: Direct Installation (Recommended)

**For personal skills** (available across all your projects):

```bash
# Create the skills directory if it doesn't exist
mkdir -p ~/.claude/skills

# Clone into the skills directory
cd ~/.claude/skills
git clone https://github.com/YOUR_USERNAME/claude-git-pr-skill.git
```

This creates `~/.claude/skills/claude-git-pr-skill/skills/github-pr-review/SKILL.md`

**For project-specific skills** (shared with your team via git):

```bash
# In your project root
mkdir -p .claude/skills
cd .claude/skills
git clone https://github.com/YOUR_USERNAME/claude-git-pr-skill.git

# Commit to your project
git add .claude/skills/claude-git-pr-skill
git commit -m "Add github-pr-review skill"
```

### Option 2: Manual Copy

Simply copy the `skills/github-pr-review` folder:

```bash
# Personal
cp -r skills/github-pr-review ~/.claude/skills/

# Project
cp -r skills/github-pr-review .claude/skills/
```

## Usage

Once installed, Claude will automatically use this skill when you ask it to review pull requests. For example:

```
You: "Review PR #123 and suggest improvements"
Claude: *Uses github-pr-review skill to create pending review with batched comments*
```

## What Makes This Skill Different

**Without this skill**, Claude might:
- Post comments immediately without showing you first
- Skip pending reviews under time pressure
- Use incorrect `gh api` syntax
- Choose the wrong event type
- Post comments you didn't approve

**With this skill**, Claude will:
- ✅ **Show you exactly what will be posted** before posting
- ✅ **Ask for explicit approval** using yes/no questions
- ✅ Always create pending reviews first
- ✅ Batch all comments together
- ✅ Use code suggestions with ```suggestion blocks
- ✅ Choose appropriate event types (APPROVE for minor suggestions, REQUEST_CHANGES for blocking issues)
- ✅ Use correct syntax (single quotes around `comments[][]` parameters)

## Workflow Pattern

The skill enforces this workflow:

**1. Draft → 2. Show & Approve → 3. Post**

### Step 1: Draft Review
Claude analyzes the PR and prepares comments with code suggestions.

### Step 2: Show & Get Approval
Claude shows you EXACTLY what will be posted:
- Each comment with file and line number
- Code suggestions formatted
- Event type (APPROVE/REQUEST_CHANGES/COMMENT)
- Overall review message

You review and approve (or request changes).

### Step 3: Post Review (Technical)

After your approval, Claude posts using this pattern:

```bash
# Step 1: Create PENDING review with all comments
gh api repos/:owner/:repo/pulls/123/reviews \
  -X POST \
  -f commit_id="<SHA>" \
  -f 'comments[][path]=file.ts' \
  -F 'comments[][line]=42' \
  -f 'comments[][side]=RIGHT' \
  -f 'comments[][body]=Comment with ```suggestion block...' \
  --jq '{id, state}'

# Step 2: Submit when ready
gh api repos/:owner/:repo/pulls/123/reviews/<REVIEW_ID>/events \
  -X POST \
  -f event="APPROVE" \
  -f body="Overall review message"
```

## Benefits

- **Consistent workflow** across all PR reviews
- **Professional batched comments** instead of scattered notifications
- **Correct syntax** every time
- **Better decision making** on event types
- **Time-tested pattern** that works under pressure

## Prerequisites

- Claude Code
- GitHub CLI (`gh`) installed and authenticated

## License

MIT (or specify your license)

## Contributing

This skill was created using Test-Driven Development for skills:
1. Baseline tests identified violations (posting immediately under time pressure)
2. Skill was written to address those violations
3. Tests verified the skill works correctly
4. Edge cases were tested and handled

If you find edge cases where the skill doesn't work correctly, please open an issue!
