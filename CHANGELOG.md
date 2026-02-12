# Changelog for Sampler.GitHubTasks

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Created module with GitHub tasks from Sampler.
- Support to add assets to GitHub released by defining the `ReleaseAssets` key in `build.yml` GitHubConfig.
- Added logo.
- Added Get-GHOwnerRepoFromRemoteUrl function.
- Task `Publish_release_to_GitHub`
  - Added `BuildCommit` parameter for CI-aware commit resolution that automatically detects the actual built commit from CI environment variables (`GITHUB_SHA`, `BUILD_SOURCEVERSION`) or falls back to local `git rev-parse HEAD`.
  - Added `DryRun` parameter to simulate release creation without making actual changes, showing detailed information about what would be performed.

### Removed

- Removed GitHub Access Token from variable being displayed during build. Fixes Issue #17.

### Changed

- Fixed Erroring when "$ProjectName.$ModuleVersion.nupkg" is not available (i.e. when using asset list in `Build.yaml`).
- Fixed tasks to use the new Sampler version and its public functions.
- Fixed RootModule not loaded because of Module Manifest.
- Making this project use the prerelease version of Sampler for testing.
- Display GitHub Release info if already exists.
- GitHub New PR to use Owner/Repo name.
- Updated publish workflow in build.yml to Create GH PR upon release.
- Updated the Readme with the icon.
- Adding delay after creating release to make sure the tag is available at next git pull.
- Updating when to skip the Create Changelog PR task (adding -ListAvailable).
- Task `Publish_release_to_GitHub`
  - Removed unnecessary code line ([issue #22](https://github.com/gaelcolas/Sampler.GitHubTasks/issues/22)).
  - Now the command `New-GitHubRelease` only outputs verbose information
    if `$VerbosePreference` says so.
- Fixed to use the actual built commit instead of latest commit on main branch, improving traceability and preventing CI pipeline conflicts.
- Fix PSGallery preview badge.
- Added DocGeneration
- Upload docs to Wiki ([issue #31](https://github.com/gaelcolas/Sampler.GitHubTasks/issues/31)).
- Update to Pester 5
- Use matrix strategy for azure-pipelines unit tests.
- Add Unit tests for public functions.

### Fixed

- Fixed task error when the PackageToRelease does not exist (i.e. it's not a module being built creating the .nupkg).
- Fixed typo when adding debug output for GH task.
- Fixed using the `Set-SamplerTaskVariable` in GH tasks.
- Fixed the Azure DevOps pipeline to build on Ubuntu latest and Windows latest.
- Fixed adding a release when GitHub immutable releases are enabled. ([gaelcolas/Sampler#542](https://github.com/gaelcolas/Sampler/issues/542)).
