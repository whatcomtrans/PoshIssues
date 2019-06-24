. .\localTestValues.ps1

#Import module
Import-Module .\PoshIssues -Force

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

    it "Message should be sent and 1 fix returned" {
        $results = $fixes | Send-IssueMailMessage
        ($results | Measure-Object).Count | Should be 1
    }

    $heldFix = New-IssueFix -FixCommand {echo "Hello Hold"} -FixDescription "Held fix" -CheckName "Greetings" -Status Hold -NotificationCount 2
    it "Message should NOT be sent and 0 fixes returned" {
        $results = $heldFix | Send-IssueMailMessage
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