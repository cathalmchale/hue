<#
 Apparently "modules don't have their own scope"
 - but they are script files, so they get a $scope that way.
 This is a separate script file and so has it's own $scope.
 - however this is a nested module of Hue.Script (see manifest)
 - so it can access private members of the module
 - see awkward syntax in functions - but seems fine for testing only!
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Scope="Function", Target="*")]
Param()


# Encapsulated data to aid unit testing

function Get-ExpectedLightName {
	$const = Get-CopyOfModuleVariable "Const"
	$const.Home.ExpectedLightName
}

function Get-InitializedLightsMap {
	$lights = Get-CopyOfModuleVariable "Lights"
	$lights
}

function Set-InitializedLightsMap {
	param(
		[Parameter(Mandatory=$true)]
		[psobject]$map
	)
	
	Set-ModuleVariable "Lights" $map
	$map
}

function Set-InitializedConstantsMap {
	param(
		[Parameter(Mandatory=$true)]
		[psobject]$map
	)

	Set-ModuleVariable "Const" $map
	$map
}

function Exit-MainThread {

	Set-ModuleVariable "StayAlive" $false
}






# Helpers for this file

function Get-CopyOfModuleVariable {
	param(
		$name
	)

	$m = Get-Module Hue.Script
	& $m Get-Variable $name -ValueOnly
}

function Set-ModuleVariable {
	param(
		$name,
		$value
	)

	$m = Get-Module Hue.Script
	& $m Set-Variable -Name $name -Value $value -Scope Script
}
