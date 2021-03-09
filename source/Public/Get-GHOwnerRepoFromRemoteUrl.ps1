<#
    .SYNOPSIS
        Extract GitHub Owner and Repository Name from Uri (ssh or https).

    .DESCRIPTION
        This function will look into a remote Url (https:// or ssh://) and will extract the GitHub owner
        and the repository name.

        from https://github.com/PowerShell/vscode-powershell/blob/master/tools/GitHubTools.psm1
        Copyright (c) Microsoft Corporation. All rights reserved.
        Licensed under the MIT License.

    .PARAMETER RemoteUrl
        Remote URL of the repository, you can get it in a cloned repository by doing: `git remote get-url origin`

    .EXAMPLE
        Get-GHOwnerRepoFromRemoteUrl -RemoteUrl git@github.com:gaelcolas/Sampler.GitHubTasks.git

#>
function Get-GHOwnerRepoFromRemoteUrl
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter()]
        [System.String]
        $RemoteUrl
    )

    if ($RemoteUrl.EndsWith('.git'))
    {
        $RemoteUrl = $RemoteUrl.Substring(0, $RemoteUrl.Length - 4)
    }
    else
    {
        $RemoteUrl = $RemoteUrl.Trim('/')
    }

    $lastSlashIdx = $RemoteUrl.LastIndexOf('/')
    $repository = $RemoteUrl.Substring($lastSlashIdx + 1)
    $secondLastSlashIdx = $RemoteUrl.LastIndexOfAny(('/', ':'), $lastSlashIdx - 1)
    $Owner = $RemoteUrl.Substring($secondLastSlashIdx + 1, $lastSlashIdx - $secondLastSlashIdx - 1)

    return @{
        Owner      = $Owner
        Repository = $repository
    }
}
