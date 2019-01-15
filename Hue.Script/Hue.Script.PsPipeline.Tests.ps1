Remove-Module Hue.Script -ErrorAction SilentlyContinue
Import-Module Hue.Script

Describe "CallSetContext" {

    Context "With WhatIf switch" {
        
        $result = Set-Context http://localhost/whatif API/1234-whatif -WhatIf

        It "impacting update code not executed" {
            $result.Server | Should -Not -Be "http://localhost/whatif"
            $result.ApiKey | Should -Not -Be "API/1234-whatif"
        }
    }

}

Describe "CallStartLightsMonitor" {

    Context "With WhatIf switch" {
		
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
            
			It "impacting event threading code not executed" {
				Assert-MockCalled Register-BoundLightEvent -Exactly -Times 0
			}
			
		}
	}

}