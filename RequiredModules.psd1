@{
    PSDependOptions             = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }

    InvokeBuild                 = 'latest'
    PSScriptAnalyzer            = 'latest'
    Pester                      = 'latest'
    Plaster                     = 'latest'

    Sampler                     = @{
        version    = 'latest'
        Parameters = @{
            AllowPrerelease = $true
        }
    }

    ModuleBuilder               = 'latest'
    MarkdownLinkCheck           = 'latest'
    ChangelogManagement         = 'latest'
    PowerShellForGitHub         = 'latest'
    'DscResource.Test'          = 'latest'
    'DscResource.AnalyzerRules' = 'latest'
    xDscResourceDesigner        = 'latest'

    # Prerequisite modules for documentation.
    'DscResource.DocGenerator'  = 'latest'
    PlatyPS                     = 'latest'
}
