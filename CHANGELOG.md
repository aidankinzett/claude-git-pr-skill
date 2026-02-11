# Changelog

All notable changes to the github-pr-review skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-02

### Added
- **Initial release** of github-pr-review skill
- **Pending review workflow** - Always creates pending reviews before submitting
- **User approval flow** - Shows exact comment text and asks for confirmation using AskUserQuestion
- **Code suggestions** - Proper ```suggestion block syntax with correct formatting
- **Event type selection** - Smart decision making between APPROVE/REQUEST_CHANGES/COMMENT
- **Correct gh api syntax** - Single quotes around `comments[][]` parameters, -f/-F flag usage
- **Comment batching** - Groups all comments into single review for better UX
- **Red flags section** - Warns against common rationalizations like "ASAP means skip pending"
- **Real-world impact section** - Explains benefits vs drawbacks
- **Plugin marketplace support** - Can be installed via `/plugin install github-pr-review`
- **TDD-tested** - Created using Test-Driven Development for skills methodology

### Features
- 4-step workflow: Draft → Show → Approve → Post
- Shows file path, line number, comment text, code suggestions, and event type before posting
- Prevents posting immediately under time pressure
- Enforces consistent workflow regardless of urgency
- Batches multiple comments into one PR notification

### Documentation
- Complete README with installation instructions
- Plugin marketplace integration
- Team-wide deployment examples
- Local testing instructions
- TDD process documentation

## [1.1.0] - 2025-12-02

### Added
- **gh CLI detection** - Checks if gh is installed before attempting review workflow
- **Installation instructions** - Provides link to https://cli.github.com/ if gh not found
- **Prerequisites section** - Clear guidance on required tools before starting
- **Authentication reminder** - Instructions to run `gh auth login` after installing
- **New red flags** - Warns against skipping gh detection step

### Changed
- **Core workflow** - Now includes gh CLI check as first required step (5 steps instead of 4)
- **Error handling** - Stops immediately if gh not installed instead of failing later

## [1.1.1] - 2025-12-02

### Changed
- **Clarified `side` parameter usage** - Updated documentation to explain `RIGHT` vs `LEFT` (added/modified vs deleted lines)
- **Added nested backticks documentation** - Documented how to handle code suggestions in markdown files with triple backticks

### Fixed
- **Nested backticks syntax** - Fixed markdown rendering issue in code example (5 backticks for outer block)

## [1.3.0] - 2025-12-10

### Fixed
- **Critical API parameter errors** - Fixed HTTP 422 errors caused by incorrect API parameters:
  - Removed invalid `side` parameter from draft review comments (not supported by DraftPullRequestReviewComment)
  - Changed `comments[][line]` to `comments[][position]` (GitHub API requires diff position, not line number)
  - Added required API headers: `-H "Accept: application/vnd.github+json"` and `-H "X-GitHub-Api-Version: 2022-11-28"`
- **Null value handling** - Added validation for null/empty path, body, and position values

### Changed
- **Added "GitHub API Limitations" section** - Documents that pending reviews cannot be updated with new comments
- **Added "Step-by-Step: How to Calculate Position"** - Detailed guide with visual examples for calculating position from diff hunks
- **Added "Validation Checklist"** - Pre-posting checklist to verify all parameters are valid
- **Added "Error Reference" table** - Maps error messages to their causes and fixes
- **Added "Error Handling Guide"** - Strategies for handling position calculation failures and batch post failures
- **Added "Fallback Strategy" section** - Individual comment posting when batch fails
- **Updated Core Workflow** - Now includes 7 steps with diff fetching and validation
- **Updated Common Mistakes table** - Added entries for null path values, invalid position values, trying to update pending reviews
- **Updated Red Flags** - Added warnings against updating pending reviews and estimating positions

### Added
- **Position calculation validation** - Bash command to verify positions before posting
- **Common position mistakes** - List of common errors when calculating positions
- **Real-world position example** - Concrete example showing position vs line number difference
- **Individual comment fallback** - Complete workflow for posting comments one-by-one when batch fails

## [1.4.0] - 2025-12-10

### Fixed
- **gh CLI flag type issues** - Fixed "is not a number" error by documenting `-F` vs `--raw-field`
  - `--raw-field` sends values as strings - use `-F` for numeric position values
  - Added clear documentation on flag usage for different data types
- **Array parsing issues** - Fixed null value errors when mixing `-f` and `-F` flags
  - Mixing flag types for array parameters causes gh CLI parsing issues
  - Recommend JSON payload approach for multiple comments

### Changed
- **Added "Common Pitfalls" section** - Documents three critical pitfalls:
  - Using `--raw-field` for numeric values
  - Mixing `-f` and `-F` flags for array parameters
  - Array syntax fragility with multiple comments
- **Added "Recommended Approach: JSON Payload" section** - Complete guide for using JSON payload:
  - Step-by-step instructions for creating JSON file with comments
  - Using `--input` flag to send JSON payload
  - Helper function template for easier reuse
  - Comparison with array syntax approach
- **Updated Syntax Rules** - Clarified flag usage:
  - Use `-F` for numeric values (NOT `--raw-field`)
  - Recommend JSON payload for multiple comments
- **Updated Error Reference table** - Added new error entries:
  - `"13" is not a number` - `--raw-field` sends strings
  - Position values null for some indices - flag mixing issue
- **Updated Common Mistakes table** - Added new entries:
  - Using `--raw-field` for position
  - Mixing `-f` and `-F` for arrays
  - Array syntax with multiple comments
- **Updated Red Flags** - Added warnings against using `--raw-field` and mixing flags

### Added
- **JSON payload template** - Complete working example for multiple comments
- **Helper function template** - `create_pr_review` bash function for reuse
- **Type safety guidance** - Clear explanation of why `-F` sends numbers vs strings
- **Validation guidance** - How to validate JSON before sending

## [1.6.0] - 2025-12-10

### Fixed
- **Auto-submit behavior documentation** - Clarified that including `event` in JSON payload auto-submits review
- **"Could not comment pull request review" errors** - Documented that calling events API on already-submitted review fails
- **Inconsistent workflow documentation** - Separated single-call and two-call patterns clearly

### Changed
- **Added "CRITICAL: Single-Call vs Two-Call Workflow" section** - Clear table explaining behavior difference
- **Reorganized JSON Payload section** - Now clearly shows Option 1 (single-call) and Option 2 (two-call)
- **Updated Helper Functions** - Separate functions for single-call and two-call patterns
- **Updated "Single Comment with Array Syntax" section** - Added auto-submit behavior clarification
- **Added Common Pitfall #4** - Documents auto-submit behavior with `event` field
- **Updated Error Reference table** - Added new entry for "Could not comment pull request review"
- **Updated Common Mistakes table** - Added entry for including `event` then calling events API
- **Updated Red Flags** - Added warnings about auto-submit assumptions

### Added
- **State explanation** - Clarified that state="COMMENTED" means already submitted vs state="PENDING"
- **Decision tree** - Clear guidance on when to use single-call vs two-call approach
- **Validation tip** - Check review state before calling events API

## [1.5.0] - 2025-12-10

### Fixed
- **Position calculation fragility** - Added helper command for automatic position calculation
- **Shell escaping issues** - Added file-based approach documentation for complex bodies
- **"Position could not be resolved" errors** - Clarified that ALL lines in diff hunk count (including context)
- **`body@-` syntax errors** - Documented correct syntax: `-F body@-` not `--raw-field body@-`

### Added
- **Helper commands** directory with two utility scripts:
  - `calculate-position.sh` - Automatically calculates position numbers for any file in PR
  - `validate-review.sh` - Validates review JSON before posting (checks fields, positions, file paths)
- **templates** directory with JSON template for review creation
- **"Handling Complex Comment Bodies" section** - Complete guide for file-based approach
- **commands/README.md** - Full documentation for helper commands

### Changed
- **Updated position calculation section** - Now emphasizes using helper command
- **Added visual position mapping** - Shows how to count positions with numbered examples
- **Updated Error Reference table** - Added 3 new error entries:
  - `Position could not be resolved`
  - `invalid key: "body@-"`
  - Shell command not found errors
- **Enhanced Core Workflow** - Now references helper commands for easier workflow

### Structure
- Added `commands/` directory for helper scripts
- Added `templates/` directory for reusable templates
- Both directories are now part of the plugin distribution

## [2.0.0] - 2026-02-10

### Added
- **Multi-Agent Parallel Review System** - Launch 5 specialized review agents in parallel:
  - solid-reviewer: SOLID principles + Architecture issues
  - security-reviewer: Security vulnerabilities
  - performance-reviewer: Performance bottlenecks
  - error-handling-reviewer: Error handling problems
  - boundary-reviewer: Boundary condition errors
- **P0-P3 Severity Level System** - Consistent severity labeling across all agents:
  - P0 (Critical): Must fix, blocks merge
  - P1 (High): Should fix before merge
  - P2 (Medium): Fix or create follow-up
  - P3 (Low): Optional improvement
- **Hybrid Event Type Mapping** - Automatic event type selection based on findings:
  - P0/P1 findings → REQUEST_CHANGES
  - P2 findings → COMMENT
  - P3 findings → APPROVE with notes
- **Agent Attribution** - Consolidated reviews maintain transparency about which agent found each issue
- **Confidence Scoring** - All agents use 80+ confidence threshold to minimize false positives
- **agents/ directory** - Agent definition files with specialized focus areas and checklists
- **references/ directory** - Customized review checklists for each agent category
- **multi-agent-review.sh** - Orchestrator script for parallel agent execution and result consolidation
- **Commands README update** - Documentation for the new multi-agent workflow

### Changed
- **SKILL.md** - Added comprehensive multi-agent review documentation with:
  - 5-agent overview table
  - Severity level definitions and event type mapping
  - Multi-agent workflow steps
  - Agent output format examples
  - Consolidation examples
  - Updated Core Workflow section
- **skill description** - Updated to mention multi-agent capability
- **marketplace.json** - Updated to version 2.0.0 with new keywords

### Breaking Changes
- **MAJOR version bump** - v2.0.0 introduces significant new functionality
- Existing v1.x manual workflow remains fully supported
- Multi-agent workflow is opt-in - use manual workflow for quick/focused reviews

## [2.1.0] - 2026-02-10

### Fixed
- **Position validation errors** - Added position range validation to prevent HTTP 422 "could not be resolved" errors
- **Markdown rendering issues** - Emphasized JSON payload approach as primary method to avoid backslash escaping problems
- **Position calculation reliability** - Enhanced validate-review.sh to check if positions are within valid range for each file

### Added
- **validate-position.sh** - New command to validate a single position before posting:
  - Shows valid position range for each file
  - Returns ✅ Valid or ❌ Invalid with expected range
  - Provides helpful error messages with diff hunk context
- **post-review.sh** - New command to post reviews using JSON payload:
  - Validates JSON before posting
  - Shows review summary with comment details
  - Supports dry-run mode for testing
  - Provides helpful error messages for common issues
- **Position range validation** - validate-review.sh now checks if each position is within valid range
- **SKILL.md CRITICAL section** - Added prominent warning about markdown escaping issues with JSON payload vs array syntax comparison table
- **Commands README** - Documented new validate-position.sh and post-review.sh commands

### Changed
- **validate-review.sh** - Added step 5 for position range validation:
  - Checks each comment's position is within valid range for its file
  - Shows valid range [min-max] for each file
  - Provides helpful fix suggestions when validation fails
- **Documentation emphasis** - JSON payload approach now documented as PRIMARY method
- **Error messages** - More detailed error messages for position validation failures

## [Unreleased]

### Planned
- Multi-line code suggestion examples
- Additional event type scenarios
- Integration with PR templates
- Support for review threads and conversations

---

## How to Update This Changelog

When making changes to the skill:

1. **Add entries under [Unreleased]** as you work
2. **Use these categories:**
   - `Added` - New features
   - `Changed` - Changes to existing functionality
   - `Deprecated` - Soon-to-be removed features
   - `Removed` - Removed features
   - `Fixed` - Bug fixes
   - `Security` - Security fixes

3. **When releasing a new version:**
   - Move [Unreleased] items to a new version section
   - Update version in `.claude-plugin/marketplace.json`
   - Create git tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
   - Push tags: `git push --tags`

4. **Version numbering (SemVer):**
   - **MAJOR** (2.0.0) - Breaking changes (skill behavior significantly different)
   - **MINOR** (1.1.0) - New features, backwards compatible
   - **PATCH** (1.0.1) - Bug fixes, backwards compatible

### Example Update

```markdown
## [Unreleased]

### Added
- Support for draft PR reviews

### Fixed
- Incorrect line number formatting in suggestions

---

## When ready to release v1.1.0:

## [1.1.0] - 2025-12-05

### Added
- Support for draft PR reviews

### Fixed
- Incorrect line number formatting in suggestions
```
