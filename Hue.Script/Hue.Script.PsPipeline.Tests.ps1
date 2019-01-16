Remove-Module Hue.Script -ErrorAction SilentlyContinue
Import-Module Hue.Script

Describe ": Given a newly imported script module" {

    Context ": When Set-Context is called with the WhatIf switch" {
        
        $result = Set-Context http://localhost/whatif API/1234-whatif -WhatIf

        It ": Then the run configuration is not actually updated" {
            $result.Server | Should -Not -Be "http://localhost/whatif"
            $result.ApiKey | Should -Not -Be "API/1234-whatif"
        }
    }

}

Describe ": Given a script module with run configuration set" {

    Context ": When start lights monitor with WhatIf switch" {
		
		# InModuleScope can access non-exported functions.
		InModuleScope Hue.Script {
		
			$expectedLight = Get-ExpectedLightName
			$mockLightsMap = @{}
			$mockLightsMap."$expectedLight" = "1"
			
			Mock Write-Debug {}
			Mock Get-EventSubscriber { return $null }
			Mock Get-LightsMap { return $mockLightsMap }
			Mock Get-EventCallback { return { "dummy script block" } }
			Mock Register-BoundLightEvent { return "final return value" }
			
			Start-LightsMonitor -WhatIf
            
			It ": Then the lights event is not registered" {
				Assert-MockCalled Register-BoundLightEvent -Exactly -Times 0
			}
			
		}
	}

}