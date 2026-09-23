param($RootPath)


BeforeAll{

	if (-not $RootPath) { $RootPath = "$PSScriptRoot\..\.." }

	$configRoot = "$rootpath/.build/config/"

	Import-Module Pipeline.Config -Force
	if ($env:OldUsername) { throw "`$env:oldUsername set, copy back to `$env:UserName to ensure you don't lose it" }
	$Env:Oldusername = $env:UserName
}

AfterAll {
	$env:UserName = $Env:Oldusername
	$Env:Oldusername = ""
}
Describe "Config tests" {
	it "when a PR has a complex branch name the prereleaseTag is valid" {
		$originalValue = $env:System_PullRequest_SourceBranch
		try {
			#Load settings from config
			$env:System_PullRequest_SourceBranch = "refs/pull/featurea"
			$settings = (Get-ProjectSettings -environment pr -ConfigRootPath $configRoot -Verbose:$VerbosePreference)

			$settings.prerelease | should -be "prfeaturea"
		}
		finally {
			$env:System_PullRequest_SourceBranch = $originalValue
		}
	}
	it "when a PR has a numbered branch name the prereleaseTag is valid" {
		$originalValue = $env:System_PullRequest_SourceBranch
		try {
			#Load settings from config
			$env:System_PullRequest_SourceBranch = "refs/pull/123_someName"
			$settings = (Get-ProjectSettings -environment pr -ConfigRootPath $configRoot -Verbose:$VerbosePreference )

			$settings.prerelease | should -be "pr123someName"
		}
		finally {
			$env:System_PullRequest_SourceBranch = $originalValue
		}
	}
	it "the project name is the module name" {
		$settings = (Get-ProjectSettings -environment ci -ConfigRootPath $configRoot -Verbose:$VerbosePreference)
		$settings.ProjectName | should -beexactly "Pipeline.Fabric"
	}
}

BeforeDiscovery{
		if (-not $RootPath) { $RootPath = "$PSScriptRoot\..\.." }

		$configRoot = "$rootpath/.build/config/"

	$users = ((Get-ChildItem $configRoot\personal).basename | Select-Object @{n = "user"; e = { $_.split('-')[0] } } -Unique)| %{@{user=$_.user}}
	$environments = (Get-ChildItem $configRoot\env | Select-Object basename -Unique).basename
}
Describe "Ensure Config runs for all users" -ForEach $users{
	BeforeAll{
		 $User= $_.user
		 $OriginalUsername = $env:UserName
	}
	It "test<User>" {
		Write-Host "$user - $($users.Count)"
	}
	Describe "run test <_>" -foreach $environments {
		BeforeAll {
			$environment = $_
		}
		it "ensure settings work for environment:$environment " {
			try {
				$env:UserName = "non existent user"

				Get-ProjectSettings -environment $environment -ConfigRootPath $configRoot -Verbose:$VerbosePreference
			}
			finally {
				$env:UserName = $OriginalUsername
			}
		}
		Describe "User" -Foreach $users {
			BeforeAll {
				$User = $_
			}
			it "ensure settings work for user:$user for environment:$environment " {
				$env:UserName = $user
				try {
					# The personal configs pull the publish key from key vault; supply a dummy so the
					# test does not need access to it.
					$settings = @{PowershellRepositorykey = "."}

					{ Get-ProjectSettings -environment $environment -ConfigRootPath $configRoot @settings -Verbose:$VerbosePreference } | should -not -throw
				}
				finally {
					$env:UserName = $OriginalUsername
				}
			}
		}
	}

}
