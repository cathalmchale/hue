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