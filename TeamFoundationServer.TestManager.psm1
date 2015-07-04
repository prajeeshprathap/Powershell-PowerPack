$ErrorActionPreference = "Stop"

#Load Reference Assemblies
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")  
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.TestManagement.Client")  
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Build.Client")  

Function Get-TeamProjectCollection
{
	[CmdletBinding()]
	param
    (
		[Parameter()]
		[ValidateNotNull()]
		[Uri]$Uri
	)

	if(-not($Uri))
    {
		$Uri = "http://tfs.pggm.nl:8080/tfs/defaultcollection"
	}

	[Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($Uri)	
}

Function Get-TeamProject 
{
	[CmdletBinding()]
	param
    (
		[Parameter(ValueFromPipeline=$true, Position=1)]
		[ValidateNotNull()]
		[Microsoft.TeamFoundation.Client.TfsTeamProjectCollection]$TeamProjectCollection,

		[Parameter(Mandatory=$true, Position=0)]
		[ValidateNotNullOrEmpty()]
		[String]$Name
	)

    $service = $TeamProjectCollection.GetService([Microsoft.TeamFoundation.TestManagement.Client.TestManagementService])
    $service.GetTeamProject($Name)    
}

Function Get-TestPlan
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
		[ValidateNotNull()]
        $TeamProject,

		[Parameter(Position=1)]
		$Id,

        [Parameter(Position=2)]
        $Name
    )

    if($Id)
    {
        $TeamProject.TestPlans.Find($Id)
    }
    else
    {
        $TeamProject.TestPlans.Query("SELECT * FROM TestPlan WHERE PlanName='$Name'")
    }
}

Function Get-TestSuite 
{
	[CmdletBinding()]
	param 
	(
		[Parameter(Mandatory=$true, Position=0, ParameterSetName="TeamProject")]
		[ValidateNotNull()]
        $TeamProject,

		[Parameter(Mandatory=$true,  ParameterSetName="TeamProject")]
		[Parameter(Mandatory=$false,  ParameterSetName="TestPlan")]
		[ValidateNotNull()]
		$Id,

		[Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="TestPlan")]
		[ValidateNotNull()]
		[Microsoft.TeamFoundation.TestManagement.Client.ITestPlan]$TestPlan
    )

    switch($PsCmdlet.ParameterSetName)
    {
        "TeamProject" 
        {
            $TeamProject.TestSuites.Find($Id)
            break;
        }
        "TestPlan" 
        {
            $TestPlan.Project.TestSuites.Find($Id)
            break;
        }
    }    
}

Function Get-TestEnvironment
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
		[ValidateNotNull()]
        $TeamProject,

		[Parameter(Position=1)]
		$Name
    )

	$TeamProject.TestEnvironments.Query() | ? { $_.Name.EndsWith($Name) }
}

Function Get-TestConfiguration 
{
	[CmdletBinding()]
	param 
    (
		[Parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNull()]
        $TeamProject,
      
		[Parameter(Mandatory=$false,  ParameterSetName="Id", Position = 1)]
		[int]$Id,
      
		[Parameter(Mandatory=$false,  ParameterSetName="Name", Position = 1)]
		[string]$Name
    )

    switch($PsCmdlet.ParameterSetName)
    {
        "Id" 
        {
            $TeamProject.TestConfigurations.Find($Id)
            break;
        }
        "Name" 
        {
            $TeamProject.TestConfigurations.Query("SELECT * FROM TestConfiguration WHERE Name='$Name'")
            break;
        }
    }	
}

Function Get-TfsBuild
{
	[CmdletBinding()]
	param
    (
		[ValidateNotNull()]
		[Microsoft.TeamFoundation.Client.TfsTeamProjectCollection]
		$TeamProjectCollection,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$TeamProject,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$BuildDefinition,

		[string]
		$BuildNumber
	)

	$server = $TeamProjectCollection.GetService([Microsoft.TeamFoundation.Build.Client.IBuildServer])
    if($BuildNumber)
    {
        $server.QueryBuilds($TeamProject, $BuildDefinition) |? {$_.BuildNumber -eq $BuildNumber}
    }
    else
    {
        $server.QueryBuilds($TeamProject, $BuildDefinition) |? {$_.Status -eq "Succeeded"} | Select -Last 1
    }    
}

Function Invoke-TestRun
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
        $TeamProject,

		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
        [string]$Title,

		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		$TestPlan,

		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		$TestSuite,

		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		$TestConfiguration,

		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		$TestEnvironment,

		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Microsoft.TeamFoundation.Build.Client.IBuildDetail]$Build
	)

	  $TestRun = $TestPlan.CreateTestRun($true)
    $TestRun.BuildUri = $Build.Uri
    $TestRun.BuildNumber = $Build.BuildNumber
    $TestRun.BuildDirectory = $Build.DropLocation 
    $QueryText = "SELECT * FROM TestPoint WHERE SuiteId=$($TestSuite.Id) AND ConfigurationId=$($TestConfiguration.Id)"
    $TestPoints = $TestPlan.QueryTestPoints($QueryText)
    $TestPoints | ? { -not($_.State -eq "NotReady" -and $_.MostRecentResultOutcome -eq "Blocked") -and $_.MostRecentResultOutcome -ne "NotApplicable" } | % { $TestRun.AddTestPoint($_, $null) }
    $TestRun.Title = $Title
    $TestRun.Owner = $TestTeamProject.TestManagementService.AuthorizedIdentity
    $TestRun.TestEnvironmentId = $TestEnvironment.Id
    $TestRun.Controller = $TestEnvironment.ControllerName
    $TestRun.Save()
	  return $TestRun
}

Function Receive-TestRun
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, Position=0, ParameterSetName="TeamProject")]
		[ValidateNotNull()]
    $TeamProject,

		[Parameter(Mandatory=$false, ParameterSetName="TestPlan")]
		[Parameter( ParameterSetName="TeamProject")]
		[int]$Id,

		[Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="TestPlan")]
		$TestPlan
	)

    switch($PsCmdlet.ParameterSetName)
    {
        "TeamProject" 
        {
            $TeamProject.TestRuns.Find($Id)
            break;
        }
        "TestPlan" 
        {
            $TestPlan.Project.TestRuns.Query("SELECT * FROM TestRun WHERE TestPlanId=$($TestPlan.Id) AND TestRunId=$Id")
            break;
        }
    }  	
}

Function Wait-TestRun
{
	[CmdletBinding()]
	param
    (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[ValidateNotNull()]
		[Microsoft.TeamFoundation.TestManagement.Client.ITestRun]$TestRun
	)
    
    do
    {
		Start-Sleep -Seconds 5
		$TestRun = Receive-TestRun -Id $TestRun.Id -TeamProject $TestRun.Project
	}while($TestRun.State -ne "Completed" -and $TestRun.State -ne "NeedsInvestigation" -and $TestRun.State -ne "Aborted")

	$TestRun
}
