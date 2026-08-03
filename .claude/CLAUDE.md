# GitHub PR Review Skill for Claude Code

A Claude Code skill that enforces consistent, professional GitHub PR reviews using the `gh` CLI. It creates pending reviews for batching comments, requires explicit user approval before posting, and applies correct syntax for code suggestions and event types.

## Changelog Maintenance

When making changes to this skill, **ALWAYS update the CHANGELOG.md** file:

### Workflow

1. **During development:**
   - Add all changes under the `[Unreleased]` section
   - Use appropriate categories: Added, Changed, Fixed, Deprecated, Removed, Security

2. **Before committing:**
   - Review CHANGELOG.md to ensure all changes are documented
   - Be specific about what changed and why

3. **When releasing a new version:**
   - Move `[Unreleased]` items to a new version section (e.g., `[1.0.1]`)
   - Add the release date in format: `[1.0.1] - 2025-12-02`
   - Update the version in `.claude-plugin/marketplace.json` to match
   - Create a git tag for the version

### Categories to Use

- **Added:** New features, new capabilities
- **Changed:** Changes to existing functionality
- **Deprecated:** Features that will be removed soon
- **Removed:** Removed features
- **Fixed:** Bug fixes
- **Security:** Security-related fixes

### Example

```markdown
## [Unreleased]

### Fixed
- Corrected gh api syntax for multi-line code suggestions
- Fixed approval prompt not showing code suggestion preview

### Added
- Support for reviewing draft PRs
```

## Version Number Guidelines

Use Semantic Versioning (SemVer):

- **PATCH version** (1.0.1) - Bug fixes, typo corrections, documentation improvements
  - Examples: Fix incorrect command syntax, clarify instructions, fix typos

- **MINOR version** (1.1.0) - New features that don't break existing behavior
  - Examples: Add support for draft PRs, add new approval options, improve error messages

- **MAJOR version** (2.0.0) - Breaking changes that change how the skill works
  - Examples: Change required workflow steps, remove features, restructure approval flow

## Release Checklist

When creating a new release:

- [ ] All changes documented in CHANGELOG.md under appropriate version
- [ ] Version updated in `.claude-plugin/marketplace.json`
- [ ] README updated if needed
- [ ] Git tag created: `git tag -a v1.0.1 -m "Release v1.0.1"`
- [ ] Changes pushed with tags: `git push --tags`
- [ ] GitHub release created (optional but recommended)

## Testing Changes

Before releasing:

1. Test the skill with subagents to ensure it still prevents violations
2. Verify approval flow works correctly
3. Check that all gh api commands have correct syntax
4. Ensure red flags still catch common rationalizations
