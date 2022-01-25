param
(
    [Parameter()]
    [System.String]
    $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory ''),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $VersionedOutputDirectory = (property VersionedOutputDirectory $true),

    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [System.String]
    $SourcePath = (property SourcePath ''),

    [Parameter()]
    $ChangelogPath = (property ChangelogPath 'CHANGELOG.md'),

    [Parameter()]
    $ReleaseNotesPath = (property ReleaseNotesPath (Join-Path $OutputDirectory 'ReleaseNotes.md')),

    [Parameter()]
    [string]
    $GitHubToken = (property GitHubToken ''), # retrieves from Environment variable

    [Parameter()]
    [string]
    $ReleaseBranch = (property ReleaseBranch 'main'),

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
    $MainGitBranch = (property MainGitBranch 'main')
)

task Publish_release_to_GitHub -if ($GitHubToken -and (Get-Module -Name PowerShellForGitHub -ListAvailable)) {

    . Set-SamplerTaskVariable

    $ReleaseNotesPath = Get-SamplerAbsolutePath -Path $ReleaseNotesPath -RelativeTo $OutputDirectory
    "`tRelease Notes Path            = '$ReleaseNotesPath'"

    $ChangelogPath = Get-SamplerAbsolutePath -Path $ChangeLogPath -RelativeTo $ProjectPath
    "`Changelog Path                 = '$ChangeLogPath'"

    "`tProject Path                  = $ProjectPath"

    # find Module's nupkg if it exists
    $packagedProjectNupkg = Join-Path -Path $OutputDirectory -ChildPath "$ProjectName.$moduleVersion.nupkg"
    $PackageToRelease = Get-ChildItem -Path $packagedProjectNupkg -ErrorAction Ignore
    # If the Project nupkg is not found, don't fail. You can still create a release and specify the
    # assets in the build.yml (i.e. Chocolatey packages or Azure Policy Guest Config Packages)
    $ReleaseTag = "v$ModuleVersion"

    Write-Build DarkGray "About to release '$PackageToRelease' with tag and release name '$ReleaseTag'"
    $remoteURL = git remote get-url origin

    # Retrieving ReleaseNotes or defaulting to Updated ChangeLog
    if (Import-Module ChangelogManagement -ErrorAction SilentlyContinue -PassThru)
    {
        $ReleaseNotes = (Get-ChangelogData -Path $ChangeLogPath).Unreleased.RawData -replace '\[unreleased\]', "[$ReleaseTag]"
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

        $displayGHReleaseParams = $getGHReleaseParams.Clone()
        $displayGHReleaseParams['AccessToken'] = 'Redacted'

        Write-Build DarkGray "Checking if the Release exists: `r`n Get-GithubRelease $($displayGHReleaseParams | Out-String)"

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
            Write-Build Green "Release Created. Adding Assets..."
            if ((-not [string]::IsNullOrEmpty($PackageToRelease)) -and (Test-Path -Path $PackageToRelease))
            {
                $APIResponse | New-GitHubReleaseAsset -Path $PackageToRelease -AccessToken $GitHubToken
                Write-Build Green "Asset '$PackageToRelease' added."
            }
            else
            {
                Write-Build DarkGray 'No Module nupkg found for this release.'
            }

            if ($ReleaseAssets = $BuildInfo.GitHubConfig.ReleaseAssets)
            {
                foreach ($assetToRelease in $ReleaseAssets)
                {
                    $assetToRelease = $ExecutionContext.InvokeCommand.ExpandString($assetToRelease)
                    if (Test-Path -Path $assetToRelease -ErrorAction SilentlyContinue)
                    {
                        (Get-Item -Path $assetToRelease -ErrorAction 'SilentlyContinue').FullName | ForEach-Object -Process {
                            $APIResponse | New-GitHubReleaseAsset -Path $_ -AccessToken $GitHubToken
                            Write-Build Green "    + Adding asset '$_' to the relase $ReleaseTag."
                        }
                    }
                    else
                    {
                        Write-Build Yellow "    ! Asset '$_' not found."
                    }
                }
            }
            else
            {
                Write-Build DarkGray 'No extra asset to add to release.'
            }

            Write-Build Green "Follow the link -> $($APIResponse.html_url)"
            Start-Sleep -Seconds 5 # Making a pause to make sure the tag will be available at next Git Pull
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

    . Set-SamplerTaskVariable

    $ChangelogPath = Get-SamplerAbsolutePath -Path $ChangeLogPath -RelativeTo $ProjectPath
    "`Changelog Path                 = '$ChangeLogPath'"

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

    &git @('config', 'user.name', $GitHubConfigUserName)
    &git @('config', 'user.email', $GitHubConfigUserEmail)
    &git @('config', 'pull.rebase', 'true')
    &git @('pull', 'origin', $MainGitBranch, '--tag')
    # Look at the tags on latest commit for origin/$MainGitBranch (assume we're on detached head)
    Write-Build DarkGray "git rev-parse origin/$MainGitBranch"
    $MainHeadCommit = (git @('rev-parse', "origin/$MainGitBranch"))
    Write-Build DarkGray "git tag -l --points-at $MainHeadCommit"
    $TagsAtCurrentPoint = git @('tag', '-l', '--points-at', $MainHeadCommit)
    Write-Build DarkGray ($TagsAtCurrentPoint -join '|')

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
        Write-Build Yellow "No Release Tag found to update the ChangeLog from in '$TagsAtCurrentPoint'"
        return
    }

    $BranchName = "updateChangelogAfter$TagVersion"
    Write-Build DarkGray "Creating branch $BranchName"

    git checkout -B $BranchName

    try
    {
        Write-Build DarkGray "Updating Changelog file"
        Update-Changelog -ReleaseVersion ($TagVersion -replace '^v') -LinkMode None -Path $ChangelogPath -ErrorAction SilentlyContinue
        git add $GitHubFilesToAdd
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
