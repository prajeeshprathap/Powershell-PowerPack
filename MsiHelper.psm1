Function Export-MsiContents
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_})]
        [ValidateScript({$_.EndsWith(".msi")})]
        [String] $MsiPath,

        [Parameter(Mandatory=$false, Position=1)]
        [String] $TargetDirectory
	)

    if(-not($TargetDirectory))
    {
        $currentDir = [System.IO.Path]::GetDirectoryName($MsiPath)
        Write-Warning "A target directory is not specified. The contents of the MSI will be extracted to the location, $currentDir\Temp"
        $TargetDirectory = Join-Path $currentDir "Temp"
    }

    $MsiPath = Resolve-Path $MsiPath

    Write-Verbose "Extracting the contents of $MsiPath to $TargetDirectory"
    Start-Process "MSIEXEC" -ArgumentList "/a $MsiPath /qn TARGETDIR=$TargetDirectory" -Wait -NoNewWindow
}

Function Get-MsiProperties
{
    param
    (
		[Parameter(Mandatory = $true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_})]
        [ValidateScript({$_.EndsWith(".msi")})]
        [String]$MsiPath
    )

    $MsiPath = Resolve-Path $MsiPath
    #Create the type
    $type = [Type]::GetTypeFromProgID("WindowsInstaller.Installer") 
    $installer = [Activator]::CreateInstance($type)

    #The OpenDatabase method of the Installer object opens an existing database or creates a new one, returning a Database object
    #For our case, we need to open the database in read only. The open mode is 0
    $db = Invoke-MemberOnType "OpenDatabase" $installer @($MsiPath,0)
    
    #The OpenView method of the Database object returns a View object that represents the query specified by a SQL string.
    $view = Invoke-MemberOnType "OpenView" $db ('SELECT * FROM Property')

    #The Execute method of the View object uses the question mark token to represent parameters in an SQL statement.
    Invoke-MemberOnType "Execute" $view $null

    #The Fetch method of the View object retrieves the next row of column data if more rows are available in the result set, otherwise it is Null.
    $record = Invoke-MemberOnType "Fetch" $view $null
    while($record -ne $null)
    {
        $property = Invoke-MemberOnType "StringData" $record 1 "GetProperty"
        $value = Invoke-MemberOnType "StringData" $record 2 "GetProperty"
        Write-Output "Property = $property : Value = $value"
        $record = Invoke-MemberOnType "Fetch" $view $null
    }

    #The Close method of the View object terminates query execution and releases database resources.
    Invoke-MemberOnType "Close" $view $null
}


Function Invoke-MemberOnType
{
    param
    (
        #The string containing the name of the method to invoke
        [Parameter(Mandatory=$true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$Name, 
        
        #A bitmask comprised of one or more BindingFlags that specify how the search is conducted. 
        #The access can be one of the BindingFlags such as Public, NonPublic, Private, InvokeMethod, GetField, and so on
        [Parameter(Mandatory=$false, Position = 3)]
        [System.Reflection.BindingFlags]$InvokeAttr = "InvokeMethod", 

        #The object on which to invoke the specified member
        [Parameter(Mandatory=$true, Position = 1)]
        [ValidateNotNull()]
        [Object]$Target, 

        #An array containing the arguments to pass to the member to invoke.
        [Parameter(Mandatory=$false, Position = 2)]
        [Object[]]$Arguments = $null
    )

    #Invokes the specified member, using the specified binding constraints and matching the specified argument list.

    $Target.GetType().InvokeMember($Name,$InvokeAttr,$null,$Target,$Arguments)
}

Export-ModuleMember 'Export-MsiContents',  'Get-MsiProperties'
