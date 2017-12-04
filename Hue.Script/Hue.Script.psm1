
#Includes
#See bottom of file - don't want to export the includes.
#This module is the API / facade and can call onto common includes no problem, 
#but needs to act as the controller e.g. to relay context and authorization.

$Const = Get-Content .\Const.psd1 | Out-String | Invoke-Expression

$Context = @{
	Server = ""
	ApiKey = ""
}

$Lights = @{}


function Set-Context {
	[CmdletBinding()]
    [OutputType([psobject])]
	param(
		[Parameter(Mandatory=$true)]
		[string]$server,
		[Parameter(Mandatory=$true)]
		[string]$apiKey
	) 
	process {
		Write-Verbose "Setting Hue.Script session context for server $server with api key $apiKey"
		$expectedLight = $script:Const.Home.ExpectedLightName
		$initialized = If ($script:Lights["$expectedLight"]) { $true } Else { $false }
		Write-Debug "Session lights map previously initialized? $initialized"

		$script:Context.Server = $server
		$script:Context.ApiKey = $apiKey

		$script:Context
	}
}


function Start-LightsMonitor {
	[CmdletBinding()]
    [OutputType([psobject])]
	param()
	process {
		$mainLoop = Get-EventSubscriber -SourceIdentifier $script:Const.Event.MainMonitorId -ErrorAction SilentlyContinue
		If ($mainLoop)
		{
			Write-Verbose "Lights monitor event $($script:Const.Event.MainMonitorId) detected. No need to setup. Call Stop-LightsMonitor and then reinitialize, if desired."
			return
		}

		$map = Get-LightsMap $script:Const $script:Context
		$expectedLight = $script:Const.Home.ExpectedLightName
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
Export-ModuleMember -Function *



#Includes
. .\EventsManager.ps1