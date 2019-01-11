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
                [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
                [ScriptBlock] $FixCommand,
                [Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [String] $FixDescription = "",
                [Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [String] $CheckName = "",
                [Parameter(Mandatory=$false,Position=3,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [IssueFixStatus] $Status = 0,
                [Parameter(Mandatory=$false,Position=4,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [System.Int64] $NotificationCount = 1,
                [Parameter(Mandatory=$false,Position=5,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [System.Int64] $SequenceNumber = 1
	)
        Begin {
                #Put begin here
        }
	Process {
                $_return = New-Object -TypeName PSObject
                $_return.PSObject.TypeNames.Insert(0,'PoshIssues.Fix')
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixCommand" -Value $FixCommand
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixDescription" -Value $FixDescription
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "checkName" -Value $CheckName
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "_status" -Value ([Int64] $Status)
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "notificationCount" -Value ([Int64] $NotificationCount)
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "sequenceNumber" -Value ([Int64] $SequenceNumber)

                #Calculate iD
                $StringBuilder = New-Object System.Text.StringBuilder 
                [System.Security.Cryptography.HashAlgorithm]::Create('MD5').ComputeHash([System.Text.Encoding]::UTF8.GetBytes($FixCommand.ToString())) | ForEach-Object{ 
                        [Void]$StringBuilder.Append($_.ToString("x2")) 
                } 
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "iD" -Value $StringBuilder.ToString()

                Add-Member -InputObject $_return -MemberType ScriptProperty -Name "status" -Value `
                { #Get
                        return [IssueFixStatus]::([enum]::getValues([IssueFixStatus]) | Where-Object value__ -eq $this._status)
                } `
                { #Set
                        param (
                        [IssueFixStatus] $status
                        )
                        $this._status = ([IssueFixStatus]::$Status).value__
                }

                Write-Output $_return
	}
	End {
                #Put end here
	}
}

function Write-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$false,DefaultParameterSetName="DatabasePath")]
	Param(
                [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
                [PSObject] $Fix,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="DatabasePath")]
                [String] $DatabasePath,
                [Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="Path")]
                [String] $Path,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $Force
	)
	Process {
                #Create an object to save as JSON
                $_fix = @{
                        "id" = $Fix.id;
                        "sequenceNumber" = $Fix.sequenceNumber;
                        "checkName" = $Fix.checkName;
                        "fixCommandBase64" = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Fix.fixCommand));
                        "fixDescription" = $Fix.fixDescription;
                        "fixResults" = $Fix.fixResults;
                        "statusInt" = $Fix._status;
                        "notificationCount" = $Fix.notificationCount;
                }
                $_path = ""
                If ($DatabasePath) {
                        #Save to database path, overwriting only if Force
                        $_fix.Add("databasePath", $DatabasePath)
                        Add-Member -InputObject $Fix -MemberType NoteProperty -Name "databasePath" -Value $DatabasePath -Force
                        
                        if (!(Test-Path $DatabasePath)) {
                                New-Item $DatabasePath -ItemType Directory
                        }
                        if (!(Test-Path "$($DatabasePath)\Fixes")) {
                                New-Item "$($DatabasePath)\Fixes" -ItemType Directory
                        }
                        $_path = "$($DatabasePath)\Fixes\$($Fix.id).json"
                 } else {
                        #Save to path, overwriting only if Force
                        $_fix.Add("path", $Path)
                        Add-Member -InputObject $Fix -MemberType NoteProperty -Name "path" -Value $Path -Force
                        $_path = $Path
                }
                if ($Force) { $_Force = $true} else {$_Force = $false}
                
                <#
                TODO: Think about when to overwrite and when to skip.  Goal is to prevent duplicate Fix objects 
                from being created/saved when a Check generates a duplicate.  Is this the correct place to catch this?
                Does catching it here require excesive use of the Force command to catch legitimate changes (status. etc)?
                Should I only check if no DatabasePath/Path is not set on the object already?
                #>

                #If the file exists AND Force is False/not set do not write the file
                if ((Test-Path $_path) -and ($_Force -eq $false)) {
                        Write-Verbose "JSON file already exists at '$_path'.  Will not overwrite unless Force is set."
                } else {
                        $_json = ConvertTo-Json -InputObject $_fix
                        Out-File -FilePath $_path -Force:$_Force -InputObject $_json
                        Write-Verbose "JSON saved to '$_path'."
                }

                Write-Output $Fix
	}
}

function Remove-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName="DatabasePath")]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
                [PSObject] $Fix,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="DatabasePath")]
                [String] $DatabasePath,
                [Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="Path")]
                [String] $Path
	)
	Process {
                $_path = ""
                #Calculate path
                If ($DatabasePath) {
                        $_path = "$($DatabasePath)\Fixes\$($Fix.id).json"
                 } else {
                        $_path = $Path
                }
                if ($_path -eq "") {
                        Write-Error "Unable to determine path to saved Fix"
                } else {
                        if (Test-Path $_path) {
                                if ($PSCmdlet.ShouldProcess("Remove $($Fix.fixDescription) from file/database?")) {
                                        #Delete the JSON file
                                        Write-Verbose "Removed $_path"
                                        Remote-Item $_path
                                }
                        } else {
                                Write-Warning "Saved Fix JSON file not found at $_path"
                        }
                }

                Write-Output $null      #TODO: Should this return the Fix or NULL?
	}
}
function Archive-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName="DatabasePath")]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
                [PSObject] $Fix,
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="DatabasePath")]
                [String] $DatabasePath,
                [Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="Path")]
                [String] $Path,
                [Parameter(Mandatory=$true,Position=2,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="Path")]
                [String] $ArchivePath,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $Force
	)
	Process {
                $_path = ""
                $_destinationPath = ""
                #Calculate path
                If ($DatabasePath) {
                        $_path = "$($DatabasePath)\Fixes\$($Fix.id).json"
                        $_destinationPath = "$($DatabasePath)\Fixes\Archive\$($Fix.id)_$(Get-Date -Format yyyyMMddHHmmss).json"
                        if (!(Test-Path $DatabasePath)) {
                                New-Item $DatabasePath -ItemType Directory
                        }
                        if (!(Test-Path "$($DatabasePath)\Fixes")) {
                                New-Item "$($DatabasePath)\Fixes" -ItemType Directory
                        }
                        if (!(Test-Path "$($DatabasePath)\Fixes\Archive")) {
                                New-Item "$($DatabasePath)\Fixes\Archive" -ItemType Directory
                        }
                 } else {
                        $_path = $Path
                        $_destinationPath = $ArchivePath
                }
                if ($_path -eq "") {
                        Write-Error "Unable to determine path to saved Fix"
                } else {
                        if (Test-Path $_path) {
                                if ($PSCmdlet.ShouldProcess("Remove $($Fix.fixDescription) from file/database?")) {
                                        #Move the JSON file
                                        Write-Verbose "Removed $_path"
                                        Move-Item -Path $_path -Destination $_destinationPath
                                }
                        } else {
                                Write-Warning "Saved Fix JSON file not found at $_path"
                        }
                }

                Write-Output $null      #TODO: Should this return the Fix or NULL?
	}
}

function Read-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName="DatabasePath")]
	Param(
		[Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="DatabasePath")]
                [String] $DatabasePath,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,ParameterSetName="DatabasePath")]
                [Switch] $IncludeArchive,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,ParameterSetName="DatabasePath")]
                [Switch] $OnlyArchive,
                [Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true, ParameterSetName="Path")]
                [String] $Path
        )
	Process {
                $items = @()
                if ($Path) {
                        $items = Get-Item $Path
                } elseif ($DatabasePath) {
                        $_folder = "$($DatabasePath)\Fixes"
                        if ($OnlyArchive) {
                                $_folder = "$($_folder)\Archive"
                        }
                        if ($IncludeArchive) {
                                $_recurse = $true
                        } else {
                                $_recurse = $false
                        }
                        $items = Get-ChildItem -Path $_folder -Recurse:$_recurse -Filter "*.json"
                }
                $items | Get-Content -Raw | ConvertFrom-Json | ForEach-Object {
                        #Take the object from the JSON import and build a fix object
                        $_fix = $_
                        $_return = New-Object -TypeName PSObject
                        $_return.PSObject.TypeNames.Insert(0,'PoshIssues.Fix')
                        [ScriptBlock] $_script = [ScriptBlock]::Create([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($_fix.fixCommandBase64)))
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixCommand" -Value $_script
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixDescription" -Value $_fix.fixDescription
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "checkName" -Value $_fix.checkName
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "_status" -Value ([Int64] $_fix.statusInt)
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "notificationCount" -Value ([Int64] $_fix.notificationCount)
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "sequenceNumber" -Value ([Int64] $_fix.sequenceNumber)
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "iD" -Value $_fix.id
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "databasePath" -Value $DatabasePath -Force

                        if ("fixResults" -in $_fix.PSobject.Properties.Name) {
                                Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixResults" -Value $_fix.fixResults -Force
                        }

                        #TODO: Add an archived flag?

                        Add-Member -InputObject $_return -MemberType ScriptProperty -Name "status" -Value `
                        { #Get
                                return [IssueFixStatus]::([enum]::getValues([IssueFixStatus]) | Where-Object value__ -eq $this._status)
                        } `
                        { #Set
                                param (
                                [IssueFixStatus] $status
                                )
                                $this._status = ([IssueFixStatus]::$Status).value__
                        }
                        Write-Output $_return
                } | Write-Output
	}
}

function Set-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
                [PSObject]$Fix,
                [Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [String] $FixDescription,
                [Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [IssueFixStatus] $Status,
                [Parameter(Mandatory=$false,Position=3,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [System.Int64] $NotificationCount,
                [Parameter(Mandatory=$false,Position=4,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [System.Int64] $SequenceNumber
	)
	Begin {
        #Put begining stuff here
	}
	Process {
                if ($PSCmdlet.ShouldProcess("Change $($Fix.fixDescription)?")) {
                        if ($FixDescription) {
                                $Fix.fixDescription = $FixDescription
                        }
                        if ($Status) {
                                #TODO: Validate input?
                                $Fix._status = $Status
                        }
                        If ($NotificationCount) {
                                $Fix.notificationCount = $NotificationCount
                        }
                        if ($SequenceNumber) {
                                $Fix.sequenceNumber = $SequenceNumber
                        }
                }
                Write-Output $Fix
	}
	End {
        #Put end here
	}
}

# TODO: is this confusing, does this change it to Ready or Complete, will this be confused with Invoke-IssueFix?
function Complete-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
		[PSObject]$Fix
	)
	Process {
                if ($PSCmdlet.ShouldProcess("Change $($Fix.fixDescription) from $(Fix.status) to Complete?")) {
                        $Fix._status = 0
                }
                Write-Output $Fix
	}
}

function Cancel-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
		[PSObject]$Fix
	)
	Process {
                if ($PSCmdlet.ShouldProcess("Change $($Fix.fixDescription) from $($Fix.status) to Complete?")) {
                        $Fix._status = 4
                }
                Write-Output $Fix
	}
}

