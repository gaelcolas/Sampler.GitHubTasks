param (
    # Base directory of all output (default to 'output')

    [Parameter()]
    [string]
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    $ChangelogPath = (property ChangelogPath 'CHANGELOG.md'),

    [Parameter()]
    $ReleaseNotesPath = (property ReleaseNotesPath (Join-Path $OutputDirectory 'ReleaseNotes.md')),

    [Parameter()]
    [string]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [string]
    $GitHubToken = (property GitHubToken ''), # retrieves from Environment variable

    [Parameter()]
    [string]
    $ReleaseBranch = (property ReleaseBranch 'master'),

    [Parameter()]
    [string]
    $GitHubConfigUserEmail = (property GitHubConfigUserEmail ''),

    [Parameter()]
    [string]
    $GitHubConfigUserName = (property GitHubConfigUserName ''),

    [Parameter()]
    $GitHubFilesToAdd = (property GitHubFilesToAdd ''),

    [Parameter()]
    $BuildInfo = (property BuildInfo @{ }),

    [Parameter()]
    $SkipPublish = (property SkipPublish ''),

    [Parameter()]
    $MainGitBranch = (property MainGitBranch 'master')
)

task Publish_release_to_GitHub -if ($GitHubToken -and (Get-Module -Name PowerShellForGitHub -ListAvailable)) {

    if ([System.String]::IsNullOrEmpty($ProjectName))
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $BuildRoot
    }

    if (!(Split-Path $OutputDirectory -IsAbsolute))
    {
        $OutputDirectory = Join-Path $BuildRoot $OutputDirectory
    }

    if (!(Split-Path -isAbsolute $ReleaseNotesPath))
    {
        $ReleaseNotesPath = Join-Path $OutputDirectory $ReleaseNotesPath
    }

    $getModuleVersionParameters = @{
        OutputDirectory = $OutputDirectory
        ProjectName     = $ProjectName
    }


    $ModuleVersion = Get-BuiltModuleVersion @getModuleVersionParameters
    $ModuleVersionFolder, $PreReleaseTag = $ModuleVersion -split '\-', 2

    # find Module's nupkg
    $PackageToRelease = Get-ChildItem (Join-Path $OutputDirectory "$ProjectName.$ModuleVersion.nupkg")
    $ReleaseTag = "v$ModuleVersion"

    Write-Build DarkGray "About to release '$PackageToRelease' with tag and release name '$ReleaseTag'"
    $remoteURL = git remote get-url origin

    if ($remoteURL -notMatch 'github')
    {
        Write-Build Yellow "Skipping Publish GitHub release to $RemoteURL"
        return
    }

    # Retrieving ReleaseNotes or defaulting to Updated ChangeLog
    if (Import-Module ChangelogManagement -ErrorAction SilentlyContinue -PassThru)
    {
        $ReleaseNotes = (Get-ChangelogData -Path $ChangeLogPath).Unreleased.RawData -replace '\[unreleased\]', "[v$ModuleVersion]"
    }
    else
    {
        if (-not ($ReleaseNotes = (Get-Content -raw $ReleaseNotesPath -ErrorAction SilentlyContinue)))
        {
            $ReleaseNotes = Get-Content -raw $ChangeLogPath -ErrorAction SilentlyContinue
        }
    }

    # if you want to create the tag on /release/v$ModuleVersion branch (default to master)
    $ReleaseBranch = $ExecutionContext.InvokeCommand.ExpandString($ReleaseBranch)
    $repoInfo = Get-GHOwnerRepoFromRemoteUrl -RemoteUrl $remoteURL
    Set-GitHubConfiguration -DisableTelemetry

    if (!$SkipPublish)
    {
        Write-Build DarkGray "Publishing GitHub release:"
        Write-Build DarkGray ($releaseParams | Out-String)

        $getGHReleaseParams = @{
            Tag            = $ReleaseTag
            AccessToken    = $GitHubToken
            OwnerName      = $repoInfo.Owner
            RepositoryName = $repoInfo.Repository
            ErrorAction    = 'Stop'
        }

        Write-Build DarkGray "Checking if the Release exists: `r`n Get-GithubRelease $($getGHReleaseParams | Out-String)"

        try
        {
            $release = Get-GithubRelease @getGHReleaseParams
        }
        catch
        {
            $release = $null
        }

        if ($null -eq $release)
        {
            $releaseParams = @{
                OwnerName      = $repoInfo.Owner
                RepositoryName = $repoInfo.Repository
                Commitish      = (git @('rev-parse', "origin/$MainGitBranch"))
                Tag            = $ReleaseTag
                Name           = $ReleaseTag
                Prerelease     = [bool]($PreReleaseTag)
                Body           = $ReleaseNotes
                AccessToken    = $GitHubToken
                Verbose        = $true
            }

            Write-Build DarkGray "Creating new GitHub release '$ReleaseTag ' at '$remoteURL'."
            $APIResponse = New-GitHubRelease @releaseParams
            Write-Build Green "Release Created. Adding Asset..."
            if (Test-Path -Path $PackageToRelease)
            {
                $APIResponse | New-GitHubReleaseAsset -Path $PackageToRelease -AccessToken $GitHubToken
                Write-Build Green "Asset '$PackageToRelease' added."
            }

            Write-Build Green "Follow the link -> $($APIResponse.html_url)"
        }
        else
        {
            Write-Build Yellow "Release for $ReleaseTag Already exits. Release: $($release | ConvertTo-Json -Depth 5)"
        }
    }
}

task Create_ChangeLog_GitHub_PR -if ($GitHubToken -and (Get-Module -Name PowerShellForGitHub)) {
    # # This is how AzDO setup the environment:
    # git init
    # git remote add origin https://github.com/gaelcolas/Sampler
    # git config gc.auto 0
    # git config --get-all http.https://github.com/gaelcolas/Sampler.extraheader
    # git @('pull', 'origin', $MainGitBranch)
    # # git fetch --force --tags --prune --progress --no-recurse-submodules origin
    # # git @('checkout', '--progress', '--force' (git @('rev-parse', "origin/$MainGitBranch")))

    foreach ($GitHubConfigKey in @('GitHubFilesToAdd', 'GitHubConfigUserName', 'GitHubConfigUserEmail', 'UpdateChangelogOnPrerelease'))
    {
        if ( -Not (Get-Variable -Name $GitHubConfigKey -ValueOnly -ErrorAction SilentlyContinue))
        {
            # Variable is not set in context, use $BuildInfo.GitHubConfig.<varName>
            $ConfigValue = $BuildInfo.GitHubConfig.($GitHubConfigKey)
            Set-Variable -Name $GitHubConfigKey -Value $ConfigValue
            Write-Build DarkGray "`t...Set $GitHubConfigKey to $ConfigValue"
        }
    }

    git @('pull', 'origin', $MainGitBranch, '--tag')
    # Look at the tags on latest commit for origin/$MainGitBranch (assume we're on detached head)
    $TagsAtCurrentPoint = git @('tag', '-l', '--points-at', (git @('rev-parse', "origin/$MainGitBranch")))
    # Only Update changelog if last commit is a full release
    if ($UpdateChangelogOnPrerelease)
    {
        $TagVersion = [string]($TagsAtCurrentPoint | Select-Object -First 1)
        Write-Build Green "Updating Changelog for PRE-Release $TagVersion"
    }
    elseif ($TagVersion = [string]($TagsAtCurrentPoint.Where{ $_ -notMatch 'v.*\-' }))
    {
        Write-Build Green "Updating the ChangeLog for release $TagVersion"
    }
    else
    {
        Write-Build Yellow "No Release Tag found to update the ChangeLog from"
        return
    }

    $BranchName = "updateChangelogAfter$TagVersion"
    git checkout -B $BranchName

    try
    {
        Write-Build DarkGray "Updating Changelog file"
        Update-Changelog -ReleaseVersion ($TagVersion -replace '^v') -LinkMode None -Path $ChangelogPath -ErrorAction SilentlyContinue
        git add $GitHubFilesToAdd
        git config user.name $GitHubConfigUserName
        git config user.email $GitHubConfigUserEmail
        git commit -m "Updating ChangeLog since $TagVersion +semver:skip"

        $remoteURL =  [URI](git remote get-url origin)
        $repoInfo = Get-GHOwnerRepoFromRemoteUrl -RemoteUrl $remoteURL

        $URI = $remoteURL.Scheme + [URI]::SchemeDelimiter + $GitHubToken + '@' + $remoteURL.Authority + $remoteURL.PathAndQuery

        # Update the PUSH URI to use the Personal Access Token for Auth
        git remote set-url --push origin $URI

        # track this branch on the remote 'origin
        git push -u origin $BranchName

        $NewPullRequestParams = @{
            AccessToken         = $GitHubToken
            OwnerName           = $repoInfo.Owner
            RepositoryName      = $repoInfo.Repository
            Title               = "Updating ChangeLog since release of $TagVersion"
            Head                = $BranchName
            Base                = $MainGitBranch
            ErrorAction         = 'Stop'
            MaintainerCanModify = $true
        }

        $Response = New-GitHubPullRequest @NewPullRequestParams
        Write-Build Green "`n --> PR #$($Response.number) opened: $($Response.url)"
    }
    catch
    {
        Write-Build Red "Error trying to create ChangeLog Pull Request. Ignoring.`r`n $_"
    }
}
