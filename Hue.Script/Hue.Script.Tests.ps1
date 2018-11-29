Remove-Module Hue.Script -ErrorAction SilentlyContinue
Import-Module .\Hue.Script.psm1

Describe "CallSetContext" {

    Context "When first called" {
        
        $result = Set-Context http://localhost API/1234

        It "returns the input parameters as object" {
            $result.Server | Should -Be "http://localhost"
            $result.ApiKey | Should -Be "API/1234"
        }
    }
	
	Context "When already initialized" {
        
		# InModuleScope can access non-exported functions.
		InModuleScope Hue.Script {
		
			Mock Write-Debug {}
			
			$expectedLight = Get-ExpectedLightName
			$mockLightsMap = @{}
			$mockLightsMap."$expectedLight" = "1"
			
			$firstCall = Set-Context http://localhost API/1234 -Debug
			# Now fake lights map initialization.
			Set-InitializedLightsMap $mockLightsMap
			# Call again.
			$subsequentCall = Set-Context http://localhost/2 API/1234/2 -Debug

			It "first call finds empty lights map" {
				Assert-MockCalled Write-Debug -Times 1 -ParameterFilter {
					$Message -match "^.*False$"
				}
			}
			
			It "subsequent call finds lights map with expected member" {
				Assert-MockCalled Write-Debug -Times 1 -ParameterFilter {
					$Message -match "^.*True$"
				}
			}
			
			It "context is set" {
				$firstCall.Server | Should -Be "http://localhost"
				$firstCall.ApiKey | Should -Be "API/1234"
			}
			
			It "context is overridden" {
				$subsequentCall.Server | Should -Be "http://localhost/2"
				$subsequentCall.ApiKey | Should -Be "API/1234/2"
			}
		
		}
    }

}


Describe "CallStartLightsMonitor" {

	Context "Already running" {
        
		Mock -ModuleName Hue.Script Write-Verbose {}
		Mock -ModuleName Hue.Script Get-EventSubscriber { return "Dummy non-null value" }
		
        $result = Start-LightsMonitor

		It "detects running and exits" {
			Assert-MockCalled -ModuleName Hue.Script Write-Verbose -Times 1
			$result | Should -Be $null
		}

    }
	
	Context "Invalid lights map" {
        
		Mock -ModuleName Hue.Script Write-Debug {} -Verifiable -ParameterFilter {
			$Message -like "Get-LightsMap called, but doesn't contain expected light *"
		}
		Mock -ModuleName Hue.Script Get-EventSubscriber { return $null }
		Mock -ModuleName Hue.Script Get-LightsMap { return @{} }
		Mock -ModuleName Hue.Script Get-EventCallback { return { "dummy script block" } }
		Mock -ModuleName Hue.Script Register-BoundLightEvent { return "final return value" }
		
        $result = Start-LightsMonitor

		It "cannot find expected light" {
			# Below asserts that mock called. 
			# Above see that mock returns empty (invalid) lights map.
			Assert-MockCalled -ModuleName Hue.Script Get-LightsMap -Times 1
			# And a debug message was logged to warn that expected light not found.
			Assert-VerifiableMock
		}
		
		It "returns result at end of function" {
			$result | Should -Be "final return value"
		}

    }
	
	Context "Valid lights map" {
		
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
			
			$result = Start-LightsMonitor
			

			It "finds expected light" {
				# Below asserts that mock called. 
				# Above see that mock returns lights map with the expected light.
				Assert-MockCalled -ModuleName Hue.Script Get-LightsMap -Times 1
				# And, unlike context "Invalid lights map", no warning debug message is emitted.
				Assert-MockCalled -ModuleName Hue.Script Write-Debug -Times 0
			}
			
			It "returns result at end of function" {
				$result | Should -Be "final return value"
			}
			
			It "module lights map is set" {
				$moduleLightsMap = Get-InitializedLightsMap
				$moduleLightsMap["$expectedLight"] | Should -Be "1"
			}
			
		}
	}
	
}
