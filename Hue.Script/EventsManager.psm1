#Includes for the Hue.Script module.

function Get-LightsMap {
	[CmdletBinding()]
    [OutputType([psobject])]
	param(
		[Parameter(Mandatory=$true)]
		[hashtable]$const,
		[Parameter(Mandatory=$true)]
		[hashtable]$context
	) 
	process {
		$url = $const.Url.LightList -f $context.Server, $context.ApiKey
		$result = Invoke-RestMethod -Uri $url -Method GET

		$lights = @{}

		foreach ($Property in $result.PSObject.Properties) {
			$name = $Property.value.name
			$id = $Property.Name

			Write-Debug "Add light $name with id $id to map"
			$lights."$name" = $id
		}

		$lights
	}
}


function Get-EventSourceId {
	[CmdletBinding()]
    [OutputType([String])]
	param(
		[Parameter(Mandatory=$true)]
		[string]$lightId,
		[Parameter(Mandatory=$true)]
		[hashtable]$const
	) 
	process {
		$id = $const.Event.SingleLightId -f $lightId
		$id 
	}
}



function Get-RegisteredEvent {
	[CmdletBinding()]
    [OutputType([psobject])]
	param(
		[Parameter(Mandatory=$true)]
		[string]$lightId,
		[Parameter(Mandatory=$true)]
		[hashtable]$const
	) 
	process {
		$id = Get-EventSourceId $lightId $const
		Get-EventSubscriber -SourceIdentifier $id -ErrorAction SilentlyContinue
	}
}


function Test-RegisterAutoOff {
	[CmdletBinding()]
    [OutputType([bool])]
	param(
		[Parameter(Mandatory=$true)]
		[string]$lightId,
		[Parameter(Mandatory=$true)]
		[hashtable]$const,
		[Parameter(Mandatory=$true)]
		[hashtable]$context
	) 
	process {
		Write-Verbose "Testing light $lightId for auto-off."
		$registeredEvent = Get-RegisteredEvent $lightId $const
		If ($registeredEvent) 
		{
			Write-Verbose "Event already registered against light $lightId"
			return
		}

		$url = $const.Url.LightDetails -f $($context.Server), $($context.ApiKey), $lightId
		$lightDetails = Invoke-RestMethod -Uri $url -Method GET

		If (-Not $lightDetails.state.on)
		{
			Write-Verbose "Light $lightId state is NOT on"
			return
		}

		$true
	}
}


function Register-BoundLightEvent {
	[CmdletBinding()]
    [OutputType([psobject])]
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
	process {
		$timer = New-Object System.Timers.Timer -Property @{
			Interval = $interval; Enabled = $true; AutoReset = $autoReset
		}

		$thisModule = Get-Module Hue.Script
		$boundAction = $thisModule.NewBoundScriptBlock($action)

		Register-ObjectEvent $timer Elapsed -SourceIdentifier $sourceIdentifier -Action $boundAction -MessageData $arg
		$timer.start()

		$details = @{
			SourceIdentifier = $sourceIdentifier
			AutoReset = $autoReset
			Interval = $interval
		}
		New-Object -Property $details -TypeName psobject
	}
}


function Get-EventCallback {
	[CmdletBinding()]
    [OutputType([scriptblock])]
	param(
		[Parameter(Mandatory=$true)]
		[string]$functionName
	) 
	process {
		
		$options = ""
		If ($VerbosePreference) { $options = " -Verbose" }
		If ($DebugPreference) { $options = $options + " -Debug" }

		$scriptText = "$functionName `$Event$options"
		$action = [Scriptblock]::Create($scriptText)
		$action
	}
}
