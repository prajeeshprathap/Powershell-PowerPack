$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

function Get-SqlServerProperty
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false)]
		[string] $ServerName = "localhost",

		[Parameter(Mandatory=$true, Position=0)]
		[string] $ServerProperty
	)

	$connection = New-Object System.Data.SqlClient.SqlConnection
	$command = New-Object System.Data.SqlClient.SqlCommand

	try
	{
		$connection.ConnectionString = "Server=$Server;Database=master;Integrated Security=True"
		$connection.Open()

		$command.Connection = $connection
		$command.CommandText = "SELECT SERVERPROPERTY ('$ServerProperty')"

		$command.ExecuteScalar()
		$connection.Close()
	}
	finally
	{
		$connection.Dispose();
	}
}

function Test-SqlServerProperties
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[string] $ServerName = "localhost"
	)

	$collation = Get-SqlServerProperty "Collation" -ServerName $ServerName
	"SQL server collation : $collation" | Write-Verbose

	$lcid = Get-SqlServerProperty "LCID" -ServerName $ServerName
	"SQL server LCID : $lcid" | Write-Verbose

	($collation -eq "LATIN1_General_CI_AS") -and ($lcid -eq 1033)
}

function Set-AuthenticationMode
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[string] $ServerName = "localhost",
		
		[Parameter(Mandatory=$false, Position=1)]
		[string] $AuthenticationMode = "Integrated"
	)

	Initialize-Assembly -Name 'Microsoft.SqlServer.SMO'
	if(-not(Test-AssemblyLoaded -Name 'Microsoft.SqlServer.SMO'))
	{
		throw "Unable to find the SQL server management objects assembly"
	}

	$sqlServer = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
	[string]$currentMode = $sqlServer.Settings.LoginMode

	if($currentMode -eq $AuthenticationMode)
	{
		"Current login mode is already set to $AuthenticationMode. Skipping the step" | Write-Verbose
	}
	else
	{
		switch($AuthenticationMode)
		{
			"Integrated"
			{
				$sqlServer.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Integrated
			}
			"Mixed"	
			{
				$sqlServer.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed
			}
			"Normal"
			{
				$sqlServer.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Normal
			}
			"Unknown"
			{
				$sqlServer.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Unknown
			}
			default
			{
				"Unable to set a login mode with name $AuthenticationMode. Skipping this step" | Write-Error
			}
		}
		$sqlServer.Alter()


		"Restarting the SQL server service" | Write-Verbose
		Restart-Service MSSQLSERVER -Force
	}
}

function Set-SqlLogin
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[string] $ServerName = "localhost",
		
		[Parameter(Mandatory=$true, Position=1)]
		[ValidateNotNullOrEmpty()]
		[string] $Username,

		[Parameter(Mandatory=$true, Position=2)]
		[ValidateNotNullOrEmpty()]
		[string] $Password
	)

	Initialize-Assembly -Name 'Microsoft.SqlServer.SMO'
	if(-not(Test-AssemblyLoaded -Name 'Microsoft.SqlServer.SMO'))
	{
		throw "Unable to find the SQL server management objects assembly"
	}

	$sqlServer = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
	if ($sqlServer.Logins.Contains($Username))  
	{   
		"A login with name $Username already exists." | Write-Verbose
	}
	else
	{
		"Creating a new login : $Username" | Write-Verbose
		$sqlLogin = New-Object Microsoft.SqlServer.Management.Smo.Login $ServerName, $Username
		$sqlLogin.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::SqlLogin
		$sqlLogin.PasswordExpirationEnabled = $false
		$sqlLogin.Create($Password)
		"Added a new login : $Username" | Write-Verbose
	}
}

function New-SqlDatabase
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[string] $ServerName = "localhost",

		[Parameter(Mandatory=$true, Position=1)]
		[ValidateNotNullOrEmpty()]
		[string] $DbName,
		
		[Parameter(Mandatory=$false, Position=2)]
		[string] $RecoveryMode = "Simple"
	)

	Initialize-Assembly -Name 'Microsoft.SqlServer.SMO'
	if(-not(Test-AssemblyLoaded -Name 'Microsoft.SqlServer.SMO'))
	{
		throw "Unable to find the SQL server management objects assembly"
	}

	$sqlServer = new-object Microsoft.SqlServer.Management.Smo.Server $ServerName
	$dbExists = $false

	$sqlServer.Databases |% {
		if ($_.Name -eq $DbName)
		{
			$dbExists = $true
		}
	}
	
	if($dbExists)
	{
		"A database with name $DbName already exists." | Write-Verbose
	}
	else
	{
		"Creating new database $DbName" | Write-Verbose

		$db = new-object Microsoft.SqlServer.Management.Smo.Database $sqlServer, $DbName
		$db.Collation = "Latin1_General_100_CS_AS" 	
		if ($RecoveryMode -eq "Simple")
		{
			"Setting database recovery mode : Simple"
			$db.RecoveryModel = [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Simple
		}
		else
		{
			"Setting database recovery mode : Full"
			$db.RecoveryModel = [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Full
		}
		
		$db.Create()
	}
}


function Set-DbLogin
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[string] $ServerName = "localhost",

		[Parameter(Mandatory=$true, Position=1)]
		[ValidateNotNullOrEmpty()]
		[string] $DbName,
		
		[Parameter(Mandatory=$true, Position=2)]
		[ValidateNotNullOrEmpty()]
		[string] $Username,
		
		[Parameter(Mandatory=$false, Position=3)]
		[string] $Role = "db_owner"
	)

	Initialize-Assembly -Name 'Microsoft.SqlServer.SMO'
	if(-not(Test-AssemblyLoaded -Name 'Microsoft.SqlServer.SMO'))
	{
		throw "Unable to find the SQL server management objects assembly"
	}

	$sqlServer = new-object Microsoft.SqlServer.Management.Smo.Server $ServerName

	$db = $sqlServer.Databases[$DbName]
	if($db -eq $null)
	{
		"Unable to find a database with name $DbName" | Write-Warning
	}
	else
	{
		if($db.Users[$Username] -ne $null)
		{
			"User $Username already exists as login in database $DbName" | Write-Verbose
		}
		else
		{
			$dbUser = New-Object Microsoft.SqlServer.Management.Smo.User $db, $Username
			$dbUser.Login = $Username
			$dbUser.Create()
			"$Username added to database $DbName login" | Write-Verbose

			"Setting $Username as $Role in database $DbName"
			$dbrole = $db.Roles[$Role]
			$dbrole.AddMember($Username)
			$dbrole.Alter()
		}
	}
}