. .\localTestValues.ps1

#Import module
Import-Module .\PoshIssues -Force -Verbose

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