enum IssueFixStatus {
    Ready
    Pending
    Complete
    Error
    Canceled
    Hold
}

enum IssueCheckStatus {
    Enabled
    Disabled
}

<#
.SYNOPSIS
Creates a new IssueFix object with the passed parameters

.DESCRIPTION
Creates a new IssueFix object with the passed parameters, using defaults as needed.

.PARAMETER FixCommand
A ScriptBlock to be added to that fix that will be executed to fix the issue.

.PARAMETER FixCommandString
A String that can be converted to a ScriptBlock to be added to that fix that will be executed to fix the issue.

.PARAMETER FixDescription
A user friendly description of what the fix does, prefereble specific to this instance.

.PARAMETER CheckName
Name of the issue check that generated this fix.

.PARAMETER Status
The status of this fix.  See IssueFixStatus enum.  Default is Ready.

.PARAMETER NotificationCount
Set the number of times notices is sent about this fix.  Usefull for scheduled notifications of pending fixes.  Each time a notificaton is sent for a fix the notificationCount is decremented by one. By default, only fixes with a notification count greater then 0 are sent. This allows for control over how often a fix is notified about.  Default is 10000.

.PARAMETER SequenceNumber
Fix sort order.  Default is 1.

.INPUTS
ScriptBlock representing the script that will be invoked by the fix
String representing the script that will be invoked by the fix

.OUTPUTS
IssueFix The fix object(s) created by the cmdlet

#>
function New-IssueFix {
    [CmdletBinding(SupportsShouldProcess=$false,DefaultParameterSetName="Block")]
    [OutputType("PoshIssues.Fix")]
	Param(
                [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false, ParameterSetName="Block")]
                [ScriptBlock] $FixCommand,
                [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false, ParameterSetName="String")]
                [String] $FixCommandString,
                [Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [String] $FixDescription = "",
                [Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [String] $CheckName = "",
                [Parameter(Mandatory=$false,Position=3,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [IssueFixStatus] $Status = 0,
                [Parameter(Mandatory=$false,Position=4,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [System.Int64] $NotificationCount = 10000,
                [Parameter(Mandatory=$false,Position=5,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [System.Int64] $SequenceNumber = 1
	)
	Process {
                $_return = New-Object -TypeName PSObject
                $_return.PSObject.TypeNames.Insert(0,'PoshIssues.Fix')

                If ($FixCommandString) {
                        $FixCommand = [scriptblock]::Create($FixCommandString)
                }

                Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixCommand" -Value $FixCommand
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixDescription" -Value $FixDescription
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "checkName" -Value $CheckName
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "_status" -Value ([Int64] $Status)
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "notificationCount" -Value ([Int64] $NotificationCount)
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "sequenceNumber" -Value ([Int64] $SequenceNumber)
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "creationDateTime" -Value ([DateTime] (Get-Date))
                Add-Member -InputObject $_return -MemberType NoteProperty -Name "statusDateTime" -Value ([DateTime] (Get-Date))

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
}

<#
.SYNOPSIS
Writes (saves) an IssueFix object to the file system as a JSON file.

.DESCRIPTION
Writes (saves) an IssueFix object to the file system as a JSON file.  Supports saving to a specific Path or to a Database folder structure.

.PARAMETER Fix
IssueFix object(s), typically passed via the pipeline, to be written to the file system as a JSON object.

.PARAMETER DatabasePath
A string path representing the folder to use as a simple database.  The IssueFix files will be saved as JSON files using their iD value into a Fixes folder.  Folders will be created as needed.  If the IssueFix has already been saved once, the cmdlet can get the value from the pipeline object.

.PARAMETER Path
A string path representing the path and file name to save the JSON content as.  If the IssueFix has already been saved once, the cmdlet can get the value from the pipeline object.

.PARAMETER NoClobber
Switch to prevent an existing file from being overwritten, otherwise by default, the existing file is overwritten.

.PARAMETER PassThru
Use PassThru switch with NoClobber to get all Fixes passed thru, otherwise only Fixes written are passed thru.

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The fix object(s) passed through the cmdlet

#>
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
                [Switch] $NoClobber,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $PassThru
	)
	Process {
                #Make sure we got a fix passed
                if ($Fix) {
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
                                "creationDateTime" = $Fix.creationDateTime;
                                "statusDateTime" = $Fix.statusDateTime
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

                        #If the file exists AND NoClobber is true not write the file
                        if ((Test-Path $_path) -and ($NoClobber)) {
                                Write-Verbose "JSON file already exists at '$_path' and NoClobber is set."
                                if ($passthru) {
                                        Write-Output $Fix
                                }
                        } else {
                                $_json = ConvertTo-Json -InputObject $_fix
                                Out-File -FilePath $_path -Force:$true -InputObject $_json
                                Write-Verbose "JSON saved to '$_path'."
                                
                                Write-Output $Fix
                        }
                }
	}
}

<#
.SYNOPSIS
Removes (deletes) an IssueFix object from the file system.

.DESCRIPTION
Removes (deletes) an IssueFix object from the file system.  Can use the path information from the fix if present and passed through pipeline.  Just performs a remove-item.

.PARAMETER Fix
IssueFix object(s), typically passed via the pipeline, to be removed from the file system.

.PARAMETER DatabasePath
A string path representing the folder to use as a simple database.  The IssueFix files will be remvoed using their iD value from a Fixes folder.  Folders will be created as needed.  If the IssueFix has already been saved once, the cmdlet can get the value from the pipeline object.

.PARAMETER Path
A string path representing the path and file name to remove.  If the IssueFix has already been saved once, the cmdlet can get the value from the pipeline object.

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The fix object(s) passed through the cmdlet

#>
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
                #Make sure we got a fix passed
                if ($Fix) {
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
                                                Remove-Item $_path
                                        }
                                } else {
                                        Write-Warning "Saved Fix JSON file not found at $_path"
                                }
                        }

                        Write-Output $Fix
                }
	}
}

<#
.SYNOPSIS
Archives (moves) an IssueFix object in the file system.

.DESCRIPTION
Archives (moves) an IssueFix object in the file system.  File must have previousely been written to file system.  Can use the path information from the fix if present and passed through pipeline.  Just performas a move-item.

.PARAMETER Fix
IssueFix object(s), typically passed via the pipeline, to be moved to archive location.

.PARAMETER DatabasePath
A string path representing the folder to use as a simple database.  The IssueFix files will be moved to an Archive folder under the Fixes folder and the filename will be appended with the current datatime.  Folders will be created as needed.  If the IssueFix has already been saved once, the cmdlet can get the value from the pipeline object.

.PARAMETER Path
A string path representing the path and file name to current JSON file.  If the IssueFix has already been saved once, the cmdlet can get the value from the pipeline object.

.PARAMETER Path
A string path representing the path and file name to move the file to.

.PARAMETER Force
Switch to force overwritting any existing file.

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The fix object(s) passed through the cmdlet

#>
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
                #Make sure we got a fix passed
                if ($Fix) {
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
                                        if ($PSCmdlet.ShouldProcess("Move $($Fix.fixDescription) to $_destinationPath?")) {
                                                #Move the JSON file
                                                Write-Verbose "Moved $_path to $_destinationPath"
                                                Move-Item -Path $_path -Destination $_destinationPath -Force:$Force
                                        }
                                } else {
                                        Write-Warning "Saved Fix JSON file not found at $_path"
                                }
                        }

                        Write-Output $Fix
                }
	}
}

<#
.SYNOPSIS
Reads an IssueFix object from the file system.

.DESCRIPTION
Reads an IssueFix object from the file system.  File must have previousely been written to file system.

.PARAMETER DatabasePath
A string path representing the folder to use as a simple database.  The IssueFix files will be moved to an Archive folder under the Fixes folder and the filename will be appended with the current datatime.  Folders will be created as needed.  If the IssueFix has already been saved once, the cmdlet can get the value from the pipeline object.

.PARAMETER IncludeArchive
Include IssueFix files archived in the database. (all)

.PARAMETER OnlyArchive
Read just from the database archive.

.PARAMETER Path
A string path representing the path and file name to current JSON file.  If the IssueFix has already been saved once, the cmdlet can get the value from the pipeline object.

.PARAMETER Path
A string path representing the path and file name to move the file to.

.PARAMETER isPending
Switch to return only IssueFix objects where status is Pending.

.PARAMETER isComplete
Switch to return only IssueFix objects where status is Complete.

.PARAMETER isReady
Switch to return only IssueFix objects where status is Ready.

.PARAMETER isError
Switch to return only IssueFix objects where status is Error.

.PARAMETER isCanceled
Switch to return only IssueFix objects where status is Canceled.

.OUTPUTS
IssueFix The fix object(s) read from file system

#>
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
                [String] $Path,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $isPending,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $isComplete,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $isReady,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $isError,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $isCanceled,
                [Parameter(Mandatory=$false,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $isHold
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
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "creationDateTime" -Value ([DateTime] $_fix.creationDateTime) -Force
                        Add-Member -InputObject $_return -MemberType NoteProperty -Name "statusDateTime" -Value ([DateTime] $_fix.creationDateTime) -Force

                        if ("fixResults" -in $_fix.PSobject.Properties.Name) {
                                Add-Member -InputObject $_return -MemberType NoteProperty -Name "fixResults" -Value $_fix.fixResults -Force
                        }

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
                        if ($isPending -or $isComplete -or $isReady -or $isError -or $isCanceled -or $isHold) {
                                # filtering results based on status
                                if ($isPending -and ($_return.status -eq 'Pending')) {
                                        Write-Output $_return
                                }
                                if ($isComplete -and ($_return.status -eq 'Complete')) {
                                        Write-Output $_return
                                }
                                if ($isReady -and ($_return.status -eq 'Ready')) {
                                        Write-Output $_return
                                }
                                if ($isError -and ($_return.status -eq 'Error')) {
                                        Write-Output $_return
                                }
                                if ($isCanceled -and ($_return.status -eq 'Canceled')) {
                                        Write-Output $_return
                                }
                                if ($isHold -and ($_return.status -eq 'Hold')) {
                                        Write-Output $_return
                                }
                        } else {
                                # return all
                                Write-Output $_return
                        }
                } | Write-Output
	}
}

<#
.SYNOPSIS
Change issue fix properties.

.DESCRIPTION
Allows for changing certain properties of an issue fix object.

.PARAMETER Fix
The issue fix object to change, typically passed via pipeline.

.PARAMETER FixDescription
Set the description of the fix to STRING value.

.PARAMETER CheckName
Set the name of the fix to STRING value.

.PARAMETER Status
Set the status of the fix to STRING value.

.PARAMETER NotificationCount
Set the notification count of the fix to INT value.

.PARAMETER SequenceNumber
Set the sequence number of the fix to INT value.

.EXAMPLE
Set-IssueFix -Fix $aFixObject -Description "This is an issue fix with a new description."

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The changed fix object(s)
#>
function Set-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$false,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
                [PSObject] $Fix,
                [Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [String] $FixDescription,
                [Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [String] $CheckName = "",
                [Parameter(Mandatory=$false,Position=3,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [IssueFixStatus] $Status,
                [Parameter(Mandatory=$false,Position=4,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [System.Int64] $NotificationCount,
                [Parameter(Mandatory=$false,Position=5,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$true)]
                [System.Int64] $SequenceNumber,
                [Parameter(Mandatory=$false,Position=6,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
                [Switch] $DecrementNotificationCount
	)
	Begin {
        #Put begining stuff here
	}
	Process {
                #Make sure we got a fix passed
                if ($Fix) {
                        if ($PSCmdlet.ShouldProcess("Change $($Fix.fixDescription)?")) {
                                if ($CheckName) {
                                        $Fix.CheckName = $CheckName
                                }
                                if ($FixDescription) {
                                        $Fix.fixDescription = $FixDescription
                                }
                                if ($Status) {
                                        if (($Status -ge 0) -and ($Status -le 5)) {
                                                $Fix._status = $Status
                                                $Fix.statusDateTime = Get-Date
                                        } else {
                                                Write-Warning "Invalid status value"
                                        }
                                }
                                If ($NotificationCount) {
                                        $Fix.notificationCount = $NotificationCount
                                }
                                if ($SequenceNumber) {
                                        $Fix.sequenceNumber = $SequenceNumber
                                }
                                if ($DecrementNotificationCount) {
                                        if ($Fix.notificationCount -gt 0) {
                                                $Fix.notificationCount = $Fix.notificationCount - 1
                                        }
                                }
                        }
                        Write-Output $Fix
                }
	}
	End {
        #Put end here
	}
}

<#
.SYNOPSIS
Sets the fix status to Ready.

.DESCRIPTION
Sets the issue fix object status to Ready.  Typically used on those whose status is Pending.

.PARAMETER Fix
The issue fix object to change, typically passed via pipeline.

.EXAMPLE
Read-IssueFix -isPending | Approve-IssueFix | Write-IssueFix

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The approved fix object(s)

#>

function Approve-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
		[PSObject] $Fix
	)
	Process {
                #Make sure we got a fix passed
                if ($Fix) {
                        if ($PSCmdlet.ShouldProcess("Change $($Fix.fixDescription) from $($Fix.status) to Complete?")) {
                                $Fix._status = 0
                                $Fix.statusDateTime = Get-Date
                        }
                        Write-Output $Fix
                }
	}
}

<#
.SYNOPSIS
Sets the issue fix status to Canceled.

.DESCRIPTION
Sets the issue fix object status to Canceled.  Typically used on those whose status is Pending.

.PARAMETER Fix
The issue fix object to change, typically passed via pipeline.

.EXAMPLE
Read-IssueFix -isPending | Deny-IssueFix | Write-IssueFix

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The denied fix object(s)

#>

function Deny-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
		[PSObject] $Fix
	)
	Process {
                #Make sure we got a fix passed
                if ($Fix) {
                        if ($PSCmdlet.ShouldProcess("Change $($Fix.fixDescription) from $($Fix.status) to Complete?")) {
                                $Fix._status = 4
                                $Fix.statusDateTime = Get-Date
                        }
                        Write-Output $Fix
                }
	}
}

<#
TODO:  Need to finish documenting this cmdlet
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Fix
The issue fix object to change, typically passed via pipeline.

.PARAMETER Force
Parameter description

.PARAMETER NoNewScope
Parameter description

.EXAMPLE
An example

.NOTES
General notes

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The fix object(s) passed through the cmdlet

#>

function Invoke-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
                [PSObject] $Fix,
                [Parameter()]
                [Switch] $Force,
                [Parameter()]
                [Switch] $NoNewScope,
                [Parameter()]
                [System.Collections.Hashtable] $DefaultParameterValues
        )
        Begin {
                if ($NoNewScope) {
                        Write-Warning "Parameter switch NoNewScope is no longer supported, all invokes are in a child scope."
                }
<<<<<<< HEAD:PoshIssues/fixes.psm1
=======

>>>>>>> remotes/origin/master:fixes.psm1
                $variablesToPass = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
                if ($DefaultParameterValues) {
                        $variablesToPass.Add((New-Variable -Name "PSDefaultParameterValues" -Value $DefaultParameterValues -PassThru))
                }
        }
	Process {
                #Make sure we got a fix passed
                if ($Fix) {
                        if (($Fix.status -eq 0) -or $Force) {
                                if ($PSCmdlet.ShouldProcess("Invoke $($Fix.fixDescription) from $($Fix.checkName) by running $($Fix.fixCommand)?")) {
                                        Add-Member -InputObject $Fix -MemberType NoteProperty -Name "fixResults" -Value "" -Force
                                        try {
                                                $Fix.fixResults = [String] ($fix.fixCommand.InvokeWithContext(@{}, $variablesToPass))
                                                $Fix.status = 2 #Complete
                                                $Fix.notificationCount = 1
                                                Write-Verbose "$($Fix.checkName): $($Fix.fixDescription) complete with following results: $($Fix.fixResults)"
                                        } catch {
                                                #Error
                                                $Fix.fixResults = [String] $_.Exception.InnerException.Message
                                                $Fix.status = 3 #Error
                                                $Fix.notificationCount = 1
                                                Write-Verbose "$($Fix.checkName): $($Fix.fixDescription) errored with following error: $($Fix.fixResults)"
                                        } finally {
                                                $Fix.statusDateTime = Get-Date
                                        }
                                }
                        }
                        Write-Output $Fix
                }
	}
}

<#
.SYNOPSIS
Removes duplicate issue fix objects from pipeline.

.DESCRIPTION
Removes duplicate issue fix objects from pipeline.  Duplicates are matched by iD.  Only the oldest fix object of each matching by iD is passed on. 

.PARAMETER Fix
The issue fix object, only useful if a collection of them is passed via pipeline.

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The fix object(s) passed through the cmdlet

#>

function Limit-IssueFix {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
		[PSObject] $Fix
        )
        End {
                $_fixes = $input
                #Sort the fixes by iD and creationDateTime
                $_fixes = $_fixes | Sort-Object -Property @("iD", "creationDateTime") -Descending
                #Iterate resutls of sort writing out the first instance of each iD
                $_iD = ""
                forEach ($_fix in $_fixes) {
                        if ($_fix.iD -ne $_iD) {
                                $_iD = $_fix.iD
                                Write-Output $_fix
                        } else {
                                Write-Verbose "Removed from pipelin fix with iD: $($_fix.iD) and creation date/time of $($_fix.creationDateTime)"
                        }
                }

        }
}