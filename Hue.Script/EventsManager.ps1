
function Get-LightsMap {
param(
	[Parameter(Mandatory=$true)]
	[hashtable]$const,
	[Parameter(Mandatory=$true)]
	[hashtable]$context
) 
	$url = $const.Url.LightList -f $context.Server, $context.ApiKey
	$result = Invoke-RestMethod -Uri $url -Method GET

	$lights = @{}

	foreach ($Property in $result.PSObject.Properties) {
		$name = $Property.value.name
		$id = $Property.Name

		$lights."$name" = $id
	}

	return $lights
}


function Get-EventSourceId {
param(
	[Parameter(Mandatory=$true)]
	[string]$lightId,
	[Parameter(Mandatory=$true)]
	[hashtable]$const
) 
	return $const.Event.SingleLightId -f $lightId
}



function Get-RegisteredEvents {
param(
	[Parameter(Mandatory=$true)]
	[string]$lightId,
	[Parameter(Mandatory=$true)]
	[hashtable]$const
) 
	$id = Get-EventSourceId $lightId $const
	Get-EventSubscriber -SourceIdentifier $id -ErrorAction SilentlyContinue
}


function Test-RegisterAutoOff {
param(
	[Parameter(Mandatory=$true)]
	[string]$lightId,
	[Parameter(Mandatory=$true)]
	[hashtable]$const,
	[Parameter(Mandatory=$true)]
	[hashtable]$context
) 
	Write-Host "Got here"

	$registeredEvents = Get-RegisteredEvents $lightId $const
	If ($registeredEvents) 
	{
		# Event already registered against this light.
		return $false
	}

	$url = $const.Url.LightDetails -f $($context.Server), $($context.ApiKey), $lightId
	$lightDetails = Invoke-RestMethod -Uri $url -Method GET

	If (-Not $lightDetails.state.on)
	{
		# Light off - no concern.
		return $false
	}

	return $true
}


function Register-BoundLightEvent {
param(
	[Parameter(Mandatory=$true)]
	[string]$sourceIdentifier,
	[Parameter(Mandatory=$true)]
	[int]$interval,
	[Parameter(Mandatory=$true)]
	[ScriptBlock]$action,
	[string]$arg = $null,
	[Alias('Loop')]
	[switch]$autoReset
) 
	$timer = New-Object System.Timers.Timer -Property @{
		Interval = $interval; Enabled = $true; AutoReset = $autoReset
	}

	$thisModule = Get-Command Start-LightsMonitor
	$boundAction = $thisModule.Module.NewBoundScriptBlock($action)

	$start = Register-ObjectEvent $timer Elapsed -SourceIdentifier $sourceIdentifier -Action $boundAction -MessageData $arg
	$timer.start()
}

