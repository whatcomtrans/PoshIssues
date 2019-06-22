. .\localTestValues.ps1

#Load Pester
Import-Module Pestr

#Test Script
Clear-Host
#Import module
Import-Module .\PoshIssues -Force -Verbose

describe "New-IssueFix" {
    $result = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
    $result2 = New-IssueFix -FixCommandString "echo 'Hello World'" -FixDescription "First fix" -CheckName "Greetings"
    
    it "should return a fix with checkName Greetings" {
        $result.checkName | should be "Greetings"
    }

    it "should return a Status of Ready" {
        $result.status | should be 0
    }
    
    it "should return a fix with an scriptblock" {
        $result2.fixCommand.InvokeReturnAsIs() | should be "Hello World"
    }
}

describe "Write-IssueFix" {
    $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"

    it "should create a JSON file in the database folder" {
        #Delete file if it exists
        remove-item "$($DatabasePath)\Fixes\$($fix.id).json" -ErrorAction SilentlyContinue
        $result = $fix | Write-IssueFix -DatabasePath $DatabasePath
        "$($DatabasePath)\Fixes\$($fix.id).json" | should exist
    }

    it "should create a JSON file at a specific location" {
        #Delete file if it exists
        remove-item $filePath -ErrorAction SilentlyContinue
        $result = $fix | Write-IssueFix -Path $filePath
        $filePath | should exist
    }

    it "should return the fix object with path set for further pipeline usage with path added" {
        #Delete file if it exists
        remove-item $filePath -ErrorAction SilentlyContinue
        $result = $fix | Write-IssueFix -Path $filePath
        $result.path | should be $filePath
    }

    it "should return the fix object with databasePath set for further pipeline usage with path added" {
        $filePath = "$($DatabasePath)\Fixes\$($fix.id).json"
        #Delete file if it exists
        remove-item $filePath -ErrorAction SilentlyContinue
        $result = $fix | Write-IssueFix -DatabasePath $DatabasePath
        $result.databasePath | should be $DatabasePath
    }
}

describe "Remove-IssueFix" {

    it "should remove a JSON file in the database folder" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        #Delete file if it exists
        remove-item "$($DatabasePath)\Fixes\$($fix.id).json" -ErrorAction SilentlyContinue
        $fix = $fix | Write-IssueFix -DatabasePath $DatabasePath

        $fix | Remove-IssueFix
        "$($DatabasePath)\Fixes\$($fix.id).json" | should not exist
    }

    it "should remove a JSON file at a specific location" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        #Delete file if it exists
        remove-item $filePath -ErrorAction SilentlyContinue
        $result = $fix | Write-IssueFix -Path $filePath

        $result | Remove-IssueFix
        $filePath | should not exist
    }
}

describe "Archive-IssueFix" {
    it "should move the fix to the database archive folder" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        #Delete file if it exists
        remove-item "$($DatabasePath)\Fixes\$($fix.id).json" -ErrorAction SilentlyContinue
        $fix = $fix | Write-IssueFix -DatabasePath $DatabasePath

        Get-ChildItem "$($DatabasePath)\Fixes\Archive" | Remove-Item
        
        $fix | Archive-IssueFix
        (Get-ChildItem "$($DatabasePath)\Fixes\Archive" | Measure-Object).Count | should be 1        
    }

    it "should move the fix to the ArchivePath specified" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        #Delete file if it exists
        remove-item $filePath -ErrorAction SilentlyContinue
        $result = $fix | Write-IssueFix -Path $filePath
        remove-item $archivePath
        $result | Archive-IssueFix -ArchivePath $archivePath
        $archivePath | should exist
    }
}

describe "Read-IssueFix" {
    it "should read IssueFix(s) from the database" {

        Get-ChildItem "$($DatabasePath)\Fixes" -File | Remove-Item

        New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings" | Write-IssueFix -DatabasePath $DatabasePath
        New-IssueFix -FixCommand {echo "Hello Josh"} -FixDescription "First fix" -CheckName "Greetings" | Write-IssueFix -DatabasePath $DatabasePath

        $fix = Read-IssueFix -DatabasePath $DatabasePath
        ($fix | Measure-Object).Count | should be 2
    }

    it "should read Pending IssueFix(s) from the database" {

        Get-ChildItem "$($DatabasePath)\Fixes" -File | Remove-Item

        New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings" -Status Ready | Write-IssueFix -DatabasePath $DatabasePath
        New-IssueFix -FixCommand {echo "Hello Josh"} -FixDescription "First fix" -CheckName "Greetings" -Status Pending | Write-IssueFix -DatabasePath $DatabasePath

        $fix = Read-IssueFix -DatabasePath $DatabasePath -isPending
        ($fix | Measure-Object).Count | should be 1
    }

    it "should read Complete IssueFix(s) from the database" {

        Get-ChildItem "$($DatabasePath)\Fixes" -File | Remove-Item

        New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings" -Status Ready | Write-IssueFix -DatabasePath $DatabasePath
        New-IssueFix -FixCommand {echo "Hello Josh"} -FixDescription "First fix" -CheckName "Greetings" -Status Complete | Write-IssueFix -DatabasePath $DatabasePath

        $fix = Read-IssueFix -DatabasePath $DatabasePath -isComplete
        ($fix | Measure-Object).Count | should be 1
    }

    it "should read IssueFix(s) from the path" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        #Delete file if it exists
        remove-item $filePath -ErrorAction SilentlyContinue
        $result = $fix | Write-IssueFix -Path $filePath

        $fix = Read-IssueFix -Path $filePath
        ($fix | Measure-Object).Count | should be 1
    }
}

describe "should change IssueFix object" {
    it "should change the description of the IssueFix" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        ($fix | Set-IssueFix -FixDescription "Test").fixDescription | should be "Test"
    }

    it "should change the Status of the IssueFix" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        ($fix | Set-IssueFix -Status Pending).status | should be Pending
    }

    it "should change the NofiticationCount of the IssueFix" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        ($fix | Set-IssueFix -NotificationCount 100).notificationCount | should be 100
    }

    it "should change the SequenceNumber of the IssueFix" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        ($fix | Set-IssueFix -SequenceNumber 66).sequenceNumber | should be 66
    }

    it "should change the NofiticationCount of the IssueFix by 1" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings" -NotificationCount 101
        ($fix | Set-IssueFix -DecrementNotificationCount).notificationCount | should be 100
    }
}

describe "Approve-IssueFix" {
    it "should change the Status of the IssueFix from Pending to Ready" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        ($fix | Set-IssueFix -Status Pending | Approve-IssueFix).status | should be Ready
    }
}

describe "Deny-IssueFix" {
    it "should change the Status of the IssueFix from Pending to Canceled" {
        $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
        ($fix | Set-IssueFix -Status Pending | Deny-IssueFix).status | should be Canceled
    }
}

describe "Invoke-IssueFix" {
    $fix = New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
    it "should invoke the ScriptBlock in the IssueFix, add the results to the IssueFix and update Status and statusDateTime" {
        $fix = $fix | Invoke-IssueFix
        $fix.fixResults | should be "Hello World"
    }

    it "should have updated the IssueFix status after results to be Completed" {
        $fix.status | should be "Complete"
    }

    $lastD = $fix.statusDateTime

    it "should not invoke again as status is not Ready" {
        $fix = $fix | Invoke-IssueFix
        $fix.statusDateTime | should be $lastD
    }

    it "should invoke again as Force is set" {
        Sleep -Seconds 5
        $fix = $fix | Invoke-IssueFix -Force
        $fix.statusDateTime | should not be  $lastD
    }

    $fix = New-IssueFix -FixCommand {echo (5 / 0)} -FixDescription "First error" -CheckName "Greetings"

    it "should return an error string" {
        $fix = $fix | Invoke-IssueFix
        $fix.fixResults | Should BeLike "Attempted to divide by zero*"
    }

    it "should have updated the IssueFix status after results to be Completed" {
        $fix.status | should be "Error"
    }

    $fix = New-IssueFix -FixCommand {echo $message} -FixDescription "First error" -CheckName "Greetings"

    it "should not change current scope" {
        $message = "Hi"
        $fix = $fix | Invoke-IssueFix
        $fix.fixResults | Should be "Hi"
    }

    $fix = New-IssueFix -FixCommand {Write-Host} -FixDescription "First error" -CheckName "Greetings"

    it "should use passed DefaultParameterValues" {
        $defaultParamValues = @{"Write-Host:Object" = "Hi"}
        $fix = $fix | Invoke-IssueFix -DefaultParameterValues $defaultParamValues
        $fix.fixResults | Should be "Hi"
    }
}

describe "Limit-IssueFix" {
    $fixes = @()
    $fixes += New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
    $fixes += New-IssueFix -FixCommand {echo "Hello World"} -FixDescription "First fix" -CheckName "Greetings"
    $fixes += New-IssueFix -FixCommand {echo "Hi World"} -FixDescription "First fix" -CheckName "Greetings"

    it "should only return the unique IssueFix objects" {
        $results = $fixes | Limit-IssueFix
        ($results | Measure-Object).Count | Should be 2
    }
}

describe "Send-IssueMailMessage" {
    $fixes = @()
    $fixes += New-IssueFix -FixCommand {echo "Hello Completed"} -FixDescription "Completed fix" -CheckName "Greetings" -Status Complete -NotificationCount 1
    $fixes += New-IssueFix -FixCommand {echo "Hello Pending 1"} -FixDescription "Pending fix 1" -CheckName "Greetings" -Status Pending -NotificationCount 1
    $fixes += New-IssueFix -FixCommand {echo "Hello Pending 2"} -FixDescription "Pending fix 2" -CheckName "Greetings" -Status Pending
    $fixes += New-IssueFix -FixCommand {echo "Hello Error"} -FixDescription "Error fix" -CheckName "Greetings" -Status Error -NotificationCount 1

    it "Message should be sent and four fixes returned" {
        $results = $fixes | Send-IssueMailMessage
        #Save fixes with notification counts decremented for next test
        $fixes = $results
        ($results | Measure-Object).Count | Should be 4
    }

    it "Message should be sent and 1 fixe returned" {
        $results = $fixes | Send-IssueMailMessage
        ($results | Measure-Object).Count | Should be 1
    }
}