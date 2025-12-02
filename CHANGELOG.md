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
