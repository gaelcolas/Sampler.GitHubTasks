# Changelog for Sampler.GitHubTasks

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Created module with GitHub tasks from Sampler.
- Added logo.
- Added Get-GHOwnerRepoFromRemoteUrl function.

### Changed

- Fixed RootModule not loaded because of Module Manifest.
- Making this project use the prerelease version of Sampler for testing.
- Display GitHub Release info if already exists.
- GitHub New PR to use Owner/Repo name.
- Updated publish workflow in build.yml to Create GH PR upon release.

### Fixed

- Fixed typo when adding debug output for GH task.
