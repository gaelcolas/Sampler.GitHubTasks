BeforeAll {
    $script:moduleName = 'Sampler.GitHubTasks'

    # If the module is not found, run the build task 'noop'.
    if (-not (Get-Module -Name $script:moduleName -ListAvailable))
    {
        # Redirect all streams to $null, except the error stream (stream 2)
        & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
    }

    # Re-import the module using force to get any code changes between runs.
    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:moduleName
}

Describe 'GHOwnerRepoFromRemoteUrl' {
    BeforeDiscovery {
        $testCases = @(
            @{
                Url      = 'git@github.com:gaelcolas/Sampler.GitHubTasks.git'
                Expected = @{
                    Owner      = 'gaelcolas'
                    Repository = 'Sampler.GitHubTasks'
                }
            }
            @{
                Url      = 'https://github.com/gaelcolas/Sampler.GitHubTasks.git'
                Expected = @{
                    Owner      = 'gaelcolas'
                    Repository = 'Sampler.GitHubTasks'
                }
            }
            @{
                Url      = 'https://github.com/gaelcolas/Sampler.GitHubTasks/'
                Expected = @{
                    Owner      = 'gaelcolas'
                    Repository = 'Sampler.GitHubTasks'
                }
            }
        )
    }

    Context 'When URL is <URL>' -ForEach $testCases {
        It 'Should return the correct result' {
            $result = Get-GHOwnerRepoFromRemoteUrl -RemoteUrl $Url

            $result.Owner | Should -Be $Expected.Owner
            $result.Repository | Should -Be $Expected.Repository
        }
    }
}
