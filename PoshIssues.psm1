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
                [Switch] $NoClobber
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
                        } else {
                                $_json = ConvertTo-Json -InputObject $_fix
                                Out-File -FilePath $_path -Force:$true -InputObject $_json
                                Write-Verbose "JSON saved to '$_path'."
                        }

                        Write-Output $Fix
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
                        Write-Output $_return
                } | Write-Output
	}
}

function Set-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
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
                [System.Int64] $SequenceNumber
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
                                        if (($Status -ge 0) -and ($Status -le 4)) {
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
                        }
                        Write-Output $Fix
                }
	}
	End {
        #Put end here
	}
}

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

function Invoke-IssueFix {
	[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
	Param(
		[Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
                [PSObject] $Fix,
                [Parameter()]
                [Switch] $Force,
                [Parameter()]
                [Switch] $NoNewScope
	)
	Process {
                #Make sure we got a fix passed
                if ($Fix) {
                        if (($Fix.status -eq 0) -or $Force) {
                                if ($PSCmdlet.ShouldProcess("Invoke $($Fix.fixDescription) from $($Fix.checkName) by running $($Fix.fixCommand)?")) {
                                        Add-Member -InputObject $Fix -MemberType NoteProperty -Name "fixResults" -Value "" -Force
                                        try {
                                                $Fix.fixResults = [String] (Invoke-Command -ScriptBlock $fix.fixCommand -NoNewScope:$NoNewScope)
                                                $Fix.status = 2 #Complete
                                                Write-Verbose "$($Fix.checkName): $($Fix.fixDescription) complete with following results: $($Fix.fixResults)"
                                        } catch {
                                                #Error
                                                $Fix.fixResults = [String] $_.Exception.Message
                                                $Fix.status = 3 #Error
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