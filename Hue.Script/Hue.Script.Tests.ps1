param(
	[string]$rootPath
) 

# NOTE: No longer need root path, now that using modules properly (manifest + imported from PSModulePath).
# Leaving as an optional param for documentation only.
# E.g. passed to test file via Pester invoke: >Invoke-Pester -Script @{Path='C:\dev\saftrare\IoT\hue\Hue.Script'; Parameters=@{rootPath='C:\dev\saftrare\IoT\hue\Hue.Script'}}
# The param is then copied to a global for use within "InModuleScope" - otherwise can use $rootPath directly.
$global:hueModuleRootPathForTests = $rootPath


Remove-Module Hue.Script -ErrorAction SilentlyContinue
Import-Module Hue.Script

Describe ": Given a newly imported script module" {

    Context ": When run configuration is set" {
        
        $result = Set-Context http://localhost API/1234

        It ": Then it should echo the specified configuration" {
            $result.Server | Should -Be "http://localhost"
            $result.ApiKey | Should -Be "API/1234"
        }
    }

}

Describe ": Given a script module with run configuration set" {

	Context ": When run configuration is updated" {
        
		# InModuleScope can access non-exported functions.
		# But note that it can't access the test script param $rootPath - had to create a global var for this.
		InModuleScope Hue.Script {
		
			Mock Write-Debug {}
			
			$expectedLight = Get-ExpectedLightName
			$mockLightsMap = @{}
			$mockLightsMap."$expectedLight" = "1"
			
			$firstCall = Set-Context http://localhost API/1234 -Debug -Confirm:$false
			# Now fake lights map initialization.
			Set-InitializedLightsMap $mockLightsMap
			# Call again.
			$subsequentCall = Set-Context http://localhost/2 API/1234/2 -Debug -Confirm:$false

			It ": Then valid configuration is retrievable" {
				$expectedLight | Should -Not -Be $null
			}
			
			It ": Then run configuration echos the latest settings" {
				# First call to Set-Context finds empty lights map (unintialized)
				Assert-MockCalled Write-Debug -Exactly -Times 1 -ParameterFilter {
					$Message -match "^.*False$"
				}
				# Subsequent call finds lights map already initialized
				Assert-MockCalled Write-Debug -Exactly -Times 1 -ParameterFilter {
					$Message -match "^.*True$"
				}
				# Context is set
				$firstCall.Server | Should -Be "http://localhost"
				$firstCall.ApiKey | Should -Be "API/1234"
				# Context is overridden
				$subsequentCall.Server | Should -Be "http://localhost/2"
				$subsequentCall.ApiKey | Should -Be "API/1234/2"
			}

		}
    }

}


Describe ": Given mocked script module" {

	Context ": When attempt to start an already running lights monitor" {
        
		Mock -ModuleName Hue.Script Write-Verbose {}
		Mock -ModuleName Hue.Script Get-EventSubscriber { return "Dummy non-null value" }
		
        $result = Start-LightsMonitor

		It ": Then an error is logged and no further action is taken" {
			Assert-MockCalled -ModuleName Hue.Script Write-Verbose -Exactly -Times 1
			$result | Should -Be $null
		}

    }
	
	Context ": When start lights monitor with an unexpected configuration" {
        
		Mock -ModuleName Hue.Script Write-Debug {} -Verifiable -ParameterFilter {
			$Message -like "Get-LightsMap called, but doesn't contain expected light *"
		}
		Mock -ModuleName Hue.Script Get-EventSubscriber { return $null }
		Mock -ModuleName Hue.Script Get-LightsMap { return @{} }
		Mock -ModuleName Hue.Script Get-EventCallback { return { "dummy script block" } }
		Mock -ModuleName Hue.Script Register-BoundLightEvent { return "final return value" } -Verifiable -ParameterFilter {
			$autoReset -eq $true
		}
		
        $result = Start-LightsMonitor

		It ": Then lights config anomaly is logged" {
			# Below asserts that mock called. 
			# Above see that mock returns empty (invalid) lights map.
			Assert-MockCalled -ModuleName Hue.Script Get-LightsMap -Times 1
			# And a debug message was logged to warn that expected light not found.
			Assert-VerifiableMock
		}
		
		It ": Then lights monitor is started" {
			$result | Should -Be "final return value"
		}

    }
	
	Context ": When start lights monitor with valid configuration" {
		
		# InModuleScope can access non-exported functions.
		InModuleScope Hue.Script {
		
			$expectedLight = Get-ExpectedLightName
			$mockLightsMap = @{}
			$mockLightsMap."$expectedLight" = "1"
			
			Mock Write-Debug {}
			Mock Get-EventSubscriber { return $null }
			Mock Get-LightsMap { return $mockLightsMap }
			Mock Get-EventCallback { return { "dummy script block" } }
			Mock Register-BoundLightEvent { return "final return value" } -Verifiable -ParameterFilter {
				$autoReset -eq $true
			}
			
			$result = Start-LightsMonitor
			

			It ": Then lights config is successfully validated" {			
				# Below asserts that mock called. 
				# Above see that mock returns lights map with the expected light.
				Assert-MockCalled Get-LightsMap -Times 1
				# And, unlike context "Invalid lights map", no warning debug message is emitted.
				Assert-MockCalled Write-Debug -Exactly -Times 0
			}
			
			It ": Then lights monitor is started" {
				$result | Should -Be "final return value"
			}
			
			It ": Then light events for the house are preserved" {
				$moduleLightsMap = Get-InitializedLightsMap
				$moduleLightsMap["$expectedLight"] | Should -Be "1"
			}
			
		}
	}
	
}


Describe ": Given script module running in Powershell Core on Pi" {

	Context ": When start lights monitor in keep-alive mode" {
        
		# InModuleScope can access non-exported functions.
		InModuleScope Hue.Script {
		
			Mock Write-Host {} -Verifiable -ParameterFilter {
				$Object -eq 'Press any key to stop the lights monitor'
			}
			Mock Write-Debug {}
			Mock Get-EventSubscriber { return $null }
			Mock Get-LightsMap { return @{} }
			Mock Get-EventCallback { return { "dummy script block" } }
			Mock Register-BoundLightEvent { return "final return value" }
			Mock Stop-LightsMonitor {}
			Mock Start-Sleep { Exit-MainThread }
			
			# NOTE: Even though the -KeepAlive switch should cause the command to loop infinitely;
			# in Pester "$host.UI.RawUI.KeyAvailable" appears to evaluate to true and so the loop breaks immediately.
			$result = Start-LightsMonitor -KeepAlive
			
			
			It ": Then lights monitor is started" {
				$result | Should -Be "final return value"
			}
			
			It ": Then polling loop is entered" {
				# Verify that write host called with expected message
				Assert-VerifiableMock
			}
		
		}
    }
	
}


# NOTE: Watch-ForLightStateChange normally called on background thread. But the calling context is actually irrelevant
#  because the only context used is that of the module - see $thisModule.NewBoundScriptBlock($action).
# So I can call and test directly - the function doesn't even use the input $event object.
Describe ": Given a running lights monitor" {

	Context ": When no house lights events are configured" {
		# InModuleScope can access non-exported functions.
		InModuleScope Hue.Script {
			# Arrange
			Mock Write-Verbose {}
			$mockConstantsMap = @{
				Home = @{
					AutoOffLights = @()
				}
			}
			
			# Act
			Set-InitializedConstantsMap $mockConstantsMap
			$result = Watch-ForLightStateChange

			# Assert
			It ": Then no auto-off event is triggered" {
				$result | Should -BeNullOrEmpty
			}

			It ": Then no auto-off logic executes" {
				Assert-MockCalled Write-Verbose -Exactly -Times 1
			}

		}
	}

	Context ": When house lights events are configured" {
		# InModuleScope can access non-exported functions.
		InModuleScope Hue.Script {
			# Arrange
			Mock Write-Verbose {}
			Mock Test-RegisterAutoOff { return $true }
			Mock Get-EventCallback { return { "dummy script block" } } -Verifiable
			Mock Get-EventSourceId { return "1234" } -Verifiable
			Mock Register-BoundLightEvent {} -Verifiable
			$expectedLight = Get-ExpectedLightName
			$mockLightsMap = @{}
			$mockLightsMap."$expectedLight" = "1"
			$mockConstantsMap = @{
				Home = @{
					AutoOffLights = @("$expectedLight")
					AutoOffDefaultInterval = 10000
				}
			}
			
			# Act
			Set-InitializedLightsMap $mockLightsMap
			Set-InitializedConstantsMap $mockConstantsMap
			$result = Watch-ForLightStateChange

			# Assert
			It ": Then auto-off events are included" {
				$result | Should -Not -BeNullOrEmpty
			}

			It ": Then house lights events are raised" {
				Assert-MockCalled Write-Verbose -Times 3
				Assert-VerifiableMock
			}

		}
	}

	Context ": When a known auto-off house light event is configured" {
		# InModuleScope can access non-exported functions.
		InModuleScope Hue.Script {
			# Arrange
			Mock Write-Verbose {}
			Mock Test-RegisterAutoOff { return $false } -Verifiable -ParameterFilter {
				$lightId -eq "1" -and 
					$const.Home.AutoOffDefaultInterval -eq 5000 -and
					$context.Server -eq "http://localhost/test-input"
			}
			$expectedLight = Get-ExpectedLightName
			$mockLightsMap = @{}
			$mockLightsMap."$expectedLight" = "1"
			$mockConstantsMap = @{
				Home = @{
					AutoOffLights = @("$expectedLight")
					AutoOffDefaultInterval = 5000
				}
			}
			
			# Act
			Set-Context "http://localhost/test-input" "API/1234"
			Set-InitializedLightsMap $mockLightsMap
			Set-InitializedConstantsMap $mockConstantsMap
			$result = Watch-ForLightStateChange

			# Assert
			It ": Then the hub is queried to see if the light is on" {
				$result | Should -BeNullOrEmpty
			}

			It ": Then the known light data is included in this query" {
				Assert-VerifiableMock
			}

		}
	}

	Context ": When auto-off light event is allowed to fire, unhindered (no mocking)" {
		# InModuleScope can access non-exported functions.
		InModuleScope Hue.Script {
			# Arrange
			Mock Write-Verbose {}
			Mock Test-RegisterAutoOff { return $true }
			$expectedLight = Get-ExpectedLightName
			$mockLightsMap = @{}
			$mockLightsMap."$expectedLight" = "1"
			$mockConstantsMap = @{
				Home = @{
					AutoOffLights = @("$expectedLight")
					AutoOffDefaultInterval = 500
				}
				Event = @{
					SingleLightId = "HueSingleLightEvent{0}"
				}
			}
			
			# Act
			Set-Context "http://localhost/test-bkgrnd-event" "API/1234"
			Set-InitializedLightsMap $mockLightsMap
			Set-InitializedConstantsMap $mockConstantsMap
			Watch-ForLightStateChange
			# Sleep to give time for background event to fire
			Start-Sleep -Milliseconds 2000

			# Assert
			It ": Then a background thread receives the event" {
				Assert-MockCalled Write-Verbose -Exactly -Times 1 -ParameterFilter {
					$Message -eq "Spawned event from http://localhost/test-bkgrnd-event for light 1"
				}
			}

		}
	}

	Context ": When Stop-LightsMonitor is called" {
		
		# Register an arbitrary event (mimic running lights monitor)
		Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
			Write-Host "PowerShell.Exiting event fired"
		}

        Stop-LightsMonitor

        It ": Then event subscribers are unregistered" {
			$m = Get-EventSubscriber | Measure-Object
			$m.Count | Should -Be 0

			# Cleanup
			Get-EventSubscriber | Unregister-Event
        }
    }

}