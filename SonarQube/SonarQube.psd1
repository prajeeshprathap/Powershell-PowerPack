@{
	ModuleVersion = '1.0'
	GUID = 'abca3506-e904-44cf-ac70-2cbc3f320531'
	Author = 'Prajeesh Prathap'
	CompanyName = 'Prajeesh'
	Copyright = '(c) 2015 . All rights reserved.'
	Description = 'The module contains functionality to automate the installation of SonarQube'
	NestedModules = @(
						'SqlServer.psm1',
						'SonarQube.psm1',
						'Java.psm1',
						'Infrastructure.psm1'
					)
	FunctionsToExport = '*'
	CmdletsToExport = '*'
	VariablesToExport = '*'
	AliasesToExport = '*'
}

