# CM: NOTE!
# If first event fires, but second doesn't - try pulling the
# includes up to the top of this file. Might need the events manager
# functions to be exported in order to call from triggered events.




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
param(
	[Parameter(Mandatory=$true)]
	[string]$server,
	[Parameter(Mandatory=$true)]
	[string]$apiKey
) 

	$script:Context.Server = $server
	$script:Context.ApiKey = $apiKey
}


function Start-LightsMonitor {

	$mainLoop = Get-EventSubscriber -SourceIdentifier $Const.Event.MainMonitorId -ErrorAction SilentlyContinue
	If ($mainLoop)
	{
		Write-Host "Lights monitor already running"
		return
	}


	$map = Get-LightsMap $Const $Context
	$script:Lights = $map


	$action = {Watch-LightChanges $Event}
	Register-BoundLightEvent $Const.Event.MainMonitorId 10000 $action -Loop


<#
	$timer = New-Object System.Timers.Timer -Property @{
		Interval = 10000; Enabled = $true; AutoReset = $true
	}

	$action = {Watch-LightChanges $Event}

	$thisModule = Get-Command Start-LightsMonitor
	$boundAction = $thisModule.Module.NewBoundScriptBlock($action)

	$start = Register-ObjectEvent $timer Elapsed -SourceIdentifier $Const.Event.MainMonitorId -Action $boundAction
	$timer.start()
#>

}

function Watch-LightChanges {
param(
	$event
)

	Write-Host "hello"
	$event | Out-Host

	Write-Host "Calling Test-RegisterAutoOff for $($Lights.hallFrontDoor) on $($Context.Server)"
	
	$shouldTurnOff = Test-RegisterAutoOff $Lights.hallFrontDoor $Const $Context
	Write-Host "should $shouldTurnOff"
	If ($shouldTurnOff)
	{

		$action = {Invoke-AutoOff $Event}
		$id = Get-EventSourceId $Lights.hallFrontDoor $Const
		Register-BoundLightEvent $id 10000 $action $Lights.hallFrontDoor

<#
		$timer = New-Object System.Timers.Timer -Property @{
			Interval = 10000; Enabled = $true; AutoReset = $false
		}

		$action = {Invoke-AutoOff $Event}

		$thisModule = Get-Command Start-LightsMonitor
		$boundAction = $thisModule.Module.NewBoundScriptBlock($action)

		$id = Get-EventSourceId $Lights.hallFrontDoor $Const
		$start = Register-ObjectEvent $timer Elapsed -SourceIdentifier $id -Action $boundAction -MessageData $Lights.hallFrontDoor
		$timer.start()
#>

	}
	

}

function Invoke-AutoOff {
param(
	$event
)

	Write-Host "Spawned event from $($Context.Server) for light $($event.MessageData)"
	$event | Out-Host

	Get-EventSubscriber -SourceIdentifier $event.SourceIdentifier | Unregister-Event

	$url = $Const.Url.LightState -f $Context.Server, $Context.ApiKey, $event.MessageData
	$body = $Const.Body.OnOff -f "false"
	Invoke-RestMethod -Uri $url -Method PUT -Body $body
}

function Stop-LightsMonitor {

	Get-EventSubscriber | Unregister-Event

}




<#  *****************************************************************************************************************
	* Export the API / Facade
	*****************************************************************************************************************
#>
Export-ModuleMember -Function *



#Includes
. .\EventsManager.ps1