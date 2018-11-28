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
        
		Mock -ModuleName Hue.Script Write-Debug {}
		
        $firstCall = Set-Context http://localhost API/1234 -Debug
		$subsequentCall = Set-Context http://localhost API/1234 -Debug

		It "first call finds empty lights map" {
			Assert-MockCalled -ModuleName Hue.Script Write-Debug -Times 1 -ParameterFilter {
				$Message -match "^.*False$"
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
        
		Mock -ModuleName Hue.Script Write-Verbose {}
		Mock -ModuleName Hue.Script Get-EventSubscriber { return $null }
		Mock -ModuleName Hue.Script Get-LightsMap { return @{} }
		Mock -ModuleName Hue.Script Get-EventCallback { return { "Dummy script block" } }
		Mock -ModuleName Hue.Script Register-BoundLightEvent { return "final return value" }
		
        $result = Start-LightsMonitor

		It "cannot find expected light" {
			Assert-MockCalled -ModuleName Hue.Script Get-LightsMap -Times 1
		}
		
		It "returns result at end of function" {
			$result | Should -Be "final return value"
		}

    }
	
}
