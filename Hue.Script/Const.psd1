@{
	Home = @{
		ExpectedLightName = "hallFrontDoor"
		AutoOffDefaultInterval = 10000
		AutoOffLights = @(
			"hallFrontDoor",
			"hallKitchen"
		)
	}

	Url = @{
		LightList = "{0}/api/{1}/lights"
		LightDetails = "{0}/api/{1}/lights/{2}"
		LightState = "{0}/api/{1}/lights/{2}/state"
	}

	Body = @{
		OnOff = @"
{{"on":{0}}}
"@
	}

	Event = @{
		MainMonitorId = "HueLightsMonitor"
		SingleLightId = "HueSingleLightEvent{0}"
		MainMonitorInterval = 10000
	}
}