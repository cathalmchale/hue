# TODO: See comment at bottom - not using module properly.

#Includes
#See bottom of file - don't want to export the includes.
#This module is the API / facade and can call onto common includes no problem, 
#but needs to act as the controller e.g. to relay context and authorization.

$Const = $null

$Context = @{
	Server = ""
	ApiKey = ""
	RootPath = ""
}

$Lights = @{}

$StayAlive = $false


function Set-Context {
	[CmdletBinding()]
    [OutputType([psobject])]
	param(
		[Parameter(Mandatory=$true)]
		[string]$server,
		[Parameter(Mandatory=$true)]
		[string]$apiKey,
		[string]$rootPath
	) 
	process {
		Write-Verbose "Setting Hue.Script session context for server $server with api key $apiKey. Script root path is $rootPath."

		# TODO: See comment at bottom - not using module properly. Need to figure out how to include other
		# files and dependencies, then maybe how this data file is bootstrapped will change also.

		# Root path is used to bootstrap dependencies. To allow the build box to run Pester tests, I'm never going
		# to assume relative paths, so will use "Const" as a sentinel to decide if dependencies already bootstrapped.
		$rootPath = If ($rootPath) { $rootPath } Else { "." }
		if(-Not $script:Const) {
			$script:Const = Get-Content "$rootPath\Const.psd1" | Out-String | Invoke-Expression
		}

		$expectedLight = Get-ExpectedLightName
		$initialized = If ($script:Lights["$expectedLight"]) { $true } Else { $false }
		Write-Debug "Session lights map previously initialized? $initialized"

		$script:Context.Server = $server
		$script:Context.ApiKey = $apiKey
		$script:Context.RootPath = $rootPath

		$copy = $script:Context.PsObject.Copy()
		$copy
	}
}


function Start-LightsMonitor {
	[CmdletBinding()]
    [OutputType([psobject])]
	param(
		[Alias('KeepAlive')]
		[switch]$stayAlive
	)
	begin {
		$script:StayAlive = $stayAlive
	}
	process {
		$mainLoop = Get-EventSubscriber -SourceIdentifier $script:Const.Event.MainMonitorId -ErrorAction SilentlyContinue
		If ($mainLoop)
		{
			Write-Verbose "Lights monitor event $($script:Const.Event.MainMonitorId) detected. No need to setup. Call Stop-LightsMonitor and then reinitialize, if desired."
			return
		}

		$map = Get-LightsMap $script:Const $script:Context
		$expectedLight = Get-ExpectedLightName
		$initialized = If ($map["$expectedLight"]) { $true } Else { $false }
		If (-Not $initialized) {
			Write-Debug "Get-LightsMap called, but doesn't contain expected light $expectedLight"
		}
		$script:Lights = $map

		Write-Verbose "Registering main events loop to monitor lights"
		# NOTE: Within the (async) action script block, module and function variables are not in scope.
		# Building appropriate callback dynamically from a string instead.
		$action = Get-EventCallback "Watch-LightChanges" -Verbose:$VerbosePreference -Debug:$DebugPreference

		$details = Register-BoundLightEvent $script:Const.Event.MainMonitorId $script:Const.Event.MainMonitorInterval $action -Loop
		$details
	}
	end {
		while ($true -And $script:StayAlive) {
			Write-Host "Press any key to stop the lights monitor"
			if ($host.UI.RawUI.KeyAvailable) {
				Stop-LightsMonitor
				break
			}
			Start-Sleep -Milliseconds 2000
		}
	}

}


function Watch-LightChanges {
	[CmdletBinding()]
    [OutputType([psobject])]
	param(
		$event
	)
	process {
		Write-Verbose "Testing for auto-off events"
		
		$script:Const.Home.AutoOffLights | ForEach-Object {

			$autoOffLightId = $script:Lights."$_"
			Write-Verbose "Testing auto-off for Light $_ with ID $autoOffLightId"

			$shouldTurnOff = Test-RegisterAutoOff $autoOffLightId $script:Const $script:Context
			If ($shouldTurnOff)
			{
				Write-Verbose "Registering auto-off for Light $_ with ID $autoOffLightId"

				# NOTE: Within the (async) action script block, module and function variables are not in scope.
				# Instead translate local variables to a static script text which will work regardless of when invoked.
				# The $Event variable in Get-EventCallback is always available to async timer events.
				$action = Get-EventCallback "Invoke-AutoOff" -Verbose:$VerbosePreference -Debug:$DebugPreference

				$eventId = Get-EventSourceId $autoOffLightId $script:Const
				Register-BoundLightEvent $eventId $script:Const.Home.AutoOffDefaultInterval $action $autoOffLightId

				$details = @{
					SourceIdentifier = $eventId
					AutoReset = $false
					Interval = $script:Const.Home.AutoOffDefaultInterval
				}
				New-Object -Property $details -TypeName psobject
			}

		}
	
	}
	
}


function Invoke-AutoOff {
	[CmdletBinding()]
    [OutputType([psobject])]
	param(
		$event
	)
	process {
		Write-Verbose "Spawned event from $($script:Context.Server) for light $($event.MessageData)"

		Get-EventSubscriber -SourceIdentifier $event.SourceIdentifier | Unregister-Event

		$url = $script:Const.Url.LightState -f $script:Context.Server, $script:Context.ApiKey, $event.MessageData
		$body = $script:Const.Body.OnOff -f "false"
		Invoke-RestMethod -Uri $url -Method PUT -Body $body

		$event
	}
}


function Stop-LightsMonitor {
	[CmdletBinding()]
	param()
	process {
		$m = Get-EventSubscriber | measure
		Write-Debug "Clearing event subscriptions. Active count currently: $($m.Count)"

		Get-EventSubscriber | Unregister-Event

		$m = Get-EventSubscriber | measure
		Write-Debug "Unregister-Event called for all subscriptions. Active count currently: $($m.Count)"
	}
}








<#  *****************************************************************************************************************
	* Export the API / Facade
	*****************************************************************************************************************
#>
#Export-ModuleMember -Function *



<#  *****************************************************************************************************************
	* Private helper methods
	*****************************************************************************************************************
#>

# Encapsulated data to aid unit testing
function Get-ExpectedLightName {
	[CmdletBinding()]
	[OutputType([String])]
	param()
	process {
		$expectedLight = $script:Const.Home.ExpectedLightName
		$expectedLight
	}
}

function Get-InitializedLightsMap {
	[CmdletBinding()]
	[OutputType([psobject])]
	param()
	process {
		
		$copy = $script:Lights.PsObject.Copy()
		$copy
	}
}

function Set-InitializedLightsMap {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[psobject]$map
	)
	process {
		$script:Lights = $map
		$map
	}
}

function Exit-MainThread {
	$script:StayAlive = $false
}



<#  *****************************************************************************************************************
	* TODO: All the below used to be "dot sourced" from .\EventsManager.ps1.
	*		This was unworkable when it come to getting a build box to run Pester tests against the module.
	*		Really it just highlighted that I wasn't using the module properly
	*		- modules can have dependencies and include other files etc.
	*		- https://stackoverflow.com/questions/27713844/dot-source-a-script-within-a-function
	*
	* For now, this should get the module back to a usable state until I've figured out how to do it properly!
	*****************************************************************************************************************
#>

#function Get-LightsMap {
#	[CmdletBinding()]
#    [OutputType([psobject])]
#	param(
#		[Parameter(Mandatory=$true)]
#		[hashtable]$const,
#		[Parameter(Mandatory=$true)]
#		[hashtable]$context
#	) 
#	process {
#		$url = $const.Url.LightList -f $context.Server, $context.ApiKey
#		$result = Invoke-RestMethod -Uri $url -Method GET

#		$lights = @{}

#		foreach ($Property in $result.PSObject.Properties) {
#			$name = $Property.value.name
#			$id = $Property.Name

#			Write-Debug "Add light $name with id $id to map"
#			$lights."$name" = $id
#		}

#		$lights
#	}
#}


#function Get-EventSourceId {
#	[CmdletBinding()]
#    [OutputType([String])]
#	param(
#		[Parameter(Mandatory=$true)]
#		[string]$lightId,
#		[Parameter(Mandatory=$true)]
#		[hashtable]$const
#	) 
#	process {
#		$id = $const.Event.SingleLightId -f $lightId
#		$id 
#	}
#}



#function Get-RegisteredEvents {
#	[CmdletBinding()]
#    [OutputType([psobject])]
#	param(
#		[Parameter(Mandatory=$true)]
#		[string]$lightId,
#		[Parameter(Mandatory=$true)]
#		[hashtable]$const
#	) 
#	process {
#		$id = Get-EventSourceId $lightId $const
#		Get-EventSubscriber -SourceIdentifier $id -ErrorAction SilentlyContinue
#	}
#}


#function Test-RegisterAutoOff {
#	[CmdletBinding()]
#    [OutputType([bool])]
#	param(
#		[Parameter(Mandatory=$true)]
#		[string]$lightId,
#		[Parameter(Mandatory=$true)]
#		[hashtable]$const,
#		[Parameter(Mandatory=$true)]
#		[hashtable]$context
#	) 
#	process {
#		Write-Verbose "Testing light $lightId for auto-off."
#		$registeredEvents = Get-RegisteredEvents $lightId $const
#		If ($registeredEvents) 
#		{
#			Write-Verbose "Event already registered against light $lightId"
#			return
#		}

#		$url = $const.Url.LightDetails -f $($context.Server), $($context.ApiKey), $lightId
#		$lightDetails = Invoke-RestMethod -Uri $url -Method GET

#		If (-Not $lightDetails.state.on)
#		{
#			Write-Verbose "Light $lightId state is NOT on"
#			return
#		}

#		$true
#	}
#}


#function Register-BoundLightEvent {
#	[CmdletBinding()]
#    [OutputType([psobject])]
#	param(
#		[Parameter(Mandatory=$true)]
#		[string]$sourceIdentifier,
#		[Parameter(Mandatory=$true)]
#		[int]$interval,
#		[Parameter(Mandatory=$true)]
#		[ScriptBlock]$action,
#		[string]$arg = $null,
#		[Alias('Loop')]
#		[switch]$autoReset
#	) 
#	process {
#		$timer = New-Object System.Timers.Timer -Property @{
#			Interval = $interval; Enabled = $true; AutoReset = $autoReset
#		}

#		$thisModule = Get-Command Start-LightsMonitor
#		$boundAction = $thisModule.Module.NewBoundScriptBlock($action)

#		$start = Register-ObjectEvent $timer Elapsed -SourceIdentifier $sourceIdentifier -Action $boundAction -MessageData $arg
#		$timer.start()

#		$details = @{
#			SourceIdentifier = $sourceIdentifier
#			AutoReset = $autoReset
#			Interval = $interval
#		}
#		New-Object -Property $details -TypeName psobject
#	}
#}


#function Get-EventCallback {
#	[CmdletBinding()]
#    [OutputType([scriptblock])]
#	param(
#		[Parameter(Mandatory=$true)]
#		[string]$functionName
#	) 
#	process {
		
#		$options = ""
#		If ($VerbosePreference) { $options = " -Verbose" }
#		If ($DebugPreference) { $options = $options + " -Debug" }

#		$scriptText = "$functionName `$Event$options"
#		$action = [Scriptblock]::Create($scriptText)
#		$action
#	}
#}
