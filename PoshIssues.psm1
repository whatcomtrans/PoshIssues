enum IssueFixStatus {
    Ready
    Pending
    Complete
    Error
    Canceled
}

enum IssueCheckStatus {
    Enabled
    Disabled
}

<#
.SYNOPSIS
Creates a new IssueFix object with the passed parameters, using defaults, when provided, from the optional IssueCheck and/or IssueDatabase.

.DESCRIPTION
Creates a new IssueFix object with the passed parameters, using defaults, when provided, from the optional IssueCheck and/or IssueDatabase.

.PARAMETER FixCommand
A ScriptBlock, String that can be converted to a ScriptBlock or arrays of Strings/ScriptBlocks to be added to that fix that will be executed to fix the issue.

.PARAMETER FixDescription
A user friendly description of what the fix does, prefereble specific to this instance.

.PARAMETER Status
The status of this fix.  See IssueFixStatus enum.

.PARAMETER NotificationCount
Set the number of times notices is sent about this fix.  Usefull for scheduled notifications of pending fixes.  Each time a notificaton is sent for a fix the notificationCount is decremented by one. By default, only fixes with a notification count greater then 0 are sent. This allows for control over how often a fix is notified about.

.PARAMETER SequenceNumber
Fix sort order.  Default is the IssueCheck's lastFixSequenceNumber

.PARAMETER CheckName
Name of the issue check that generated this fix.  Provide either CheckName or CheckIssue.  If Database or DatabasePath is provided, will attempt to lookup the associated IssueCheck object from the database.  Otherwise, just stores the name.

.INPUTS
ScriptBlock The fix.

.OUTPUTS
IssueFix The fix object(s) created by the cmdlet

#>
function New-IssueFix {
    [CmdletBinding(SupportsShouldProcess=$false,DefaultParameterSetName="")]
    [OutputType("PoshIssues.Fix")]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [ScriptBlock] $FixCommand,
        [Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
        [String] $FixDescription,
        [Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
        [String] $CheckName,
        [Parameter(Mandatory=$false,Position=3,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
        [IssueFixStatus] $Status,
        [Parameter(Mandatory=$false,Position=4,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
        [System.Int64] $NotificationCount,
        [Parameter(Mandatory=$false,Position=5,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
        [System.Int64] $SequenceNumber
	)
	Begin {
        #Put begin here
    }
	Process {
        $_return = New-Object -TypeName PSObject
        $_return.PSObject.TypeNames.Insert(0,'PoshIssues.Fix')
        Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixCommand" -Value $FixCommand
        
        if ($FixDescription) {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixDescription" -Value $FixDescription
        } else {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixDescription" -Value ""
        }
        
        if ($CheckName) {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "checkName" -Value $CheckName
        } else {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "checkName" -Value ""
        }

        if ($Status) {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "status" -Value $Status
        } else {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "status" -Value 0
        }

        if ($NotificationCount) {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "notificationCount" -Value $NotificationCount
        } else {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "notificationCount" -Value 1
        }

        if ($SequenceNumber) {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "sequenceNumber" -Value $SequenceNumber
        } else {
            Add-Member -InputObject $_return -MemberType NoteProperty -Name "sequenceNumber" -Value 1
        }

        Add-Member -InputObject $_return -MemberType ScriptProperty -Name "fixCommandString" -Value {
            return $this.fixCommand.ToString()
        }

        return $_return
	}
	End {
        #Put end here
	}
}

