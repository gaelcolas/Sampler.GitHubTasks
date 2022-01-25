# Changelog for Sampler.GitHubTasks

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Created module with GitHub tasks from Sampler.
- Support to add assets to GitHub released by defining the `ReleaseAssets` key in `build.yml` GitHubConfig.
- Added logo.
- Added Get-GHOwnerRepoFromRemoteUrl function.

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

### Fixed

- Fixed task error when the PackageToRelease does not exist (i.e. it's not a module being built creating the .nupkg).
- Fixed typo when adding debug output for GH task.
- Fixed using the `Set-SamplerTaskVariable` in GH tasks.
- Fixed the Azure DevOps pipeline to build on Ubunt latest.
