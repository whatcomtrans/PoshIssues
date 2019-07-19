. .\localTestValues.ps1

#Import module
Import-Module .\PoshIssues -Force

describe "Send-IssueMailMessage" {
    $fixes = @()
    $fixes += New-IssueFix -FixCommand {echo "Hello Completed"} -FixDescription "Completed fix" -CheckName "Greetings" -Status Complete -NotificationCount 1
    $fixes += New-IssueFix -FixCommand {echo "Hello Pending 1"} -FixDescription "Pending fix 1" -CheckName "Greetings" -Status Pending -NotificationCount 1
    $fixes += New-IssueFix -FixCommand {echo "Hello Pending 2"} -FixDescription "Pending fix 2" -CheckName "Greetings" -Status Pending
    $fixes += New-IssueFix -FixCommand {echo "Hello Error"} -FixDescription "Error fix" -CheckName "Greetings" -Status Error -NotificationCount 1
    $fixes += New-IssueFix -FixCommand {echo "Hello Canceled"} -FixDescription "Canceled fix" -CheckName "Greetings" -Status Canceled
    $fixes += New-IssueFix -FixCommand {echo "Hello Held"} -FixDescription "Held fix" -CheckName "Greetings" -Status Hold -NotificationCount 1

    it "Message should be sent and 6 fixes returned" {
        $results = $fixes | Send-IssueMailMessage
        #Save fixes with notification counts decremented for next test
        $fixes = $results
        ($results).Count | Should be 6
    }

    it "Message should be sent and 1 fix returned" {
        $results = $fixes | Send-IssueMailMessage -ReturnOnlySent
        ($results | Where-Object NotificationCount -gt 0).Count | Should be 2
    }

    $heldFix = New-IssueFix -FixCommand {echo "Hello Hold"} -FixDescription "Held fix" -CheckName "Greetings" -Status Hold -NotificationCount 2
    it "Message should NOT be sent as it is held and 0 fixes returned" {
        $results = $heldFix | Send-IssueMailMessage -ReturnOnlySent
        ($results | Measure-Object).Count | Should be 0
    }

    $heldFixes = @()
    $heldFixes += New-IssueFix -FixCommand {echo "Hello Hold 1"} -FixDescription "Held fix 1" -CheckName "Greetings" -Status Hold -NotificationCount 2
    $heldFixes += New-IssueFix -FixCommand {echo "Hello Hold 2"} -FixDescription "Held fix 2" -CheckName "Greetings" -Status Hold -NotificationCount 2
    it "Messages should NOT be sent as they are held and 0 fixes returned" {
        $results = $heldFixes | Send-IssueMailMessage -ReturnOnlySent
        ($results | Measure-Object).Count | Should be 0
    }

    $fixes = @()
    $fixes += New-IssueFix -FixCommand {echo "Hello Completed"} -FixDescription "Completed fix" -CheckName "Greetings" -Status Complete -NotificationCount 1
    $fixes += $heldFix
    it "Message should be sent and 2 fix returned" {
        $results = $fixes | Send-IssueMailMessage
        ($results | Measure-Object).Count | Should be 2
    }
}