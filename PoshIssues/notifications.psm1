
enum IssueFixStatus {
    Ready
    Pending
    Complete
    Error
    Canceled
    Hold
}

<#
.SYNOPSIS
Sends a mail message with error, pending and completed fixes listed in simple HTML tables.

.DESCRIPTION
Sends a mail message with error, pending and completed fixes listed in simple HTML tables.  Uses the Send-MailMessage cmdlet and thus inherits all of its parameters.  It overrides the Body and BodyAsHTML parameers.  Returns issue fix objects with notification count potentially changed.

.PARAMETER Fix
The issue fix object to change, typically passed via pipeline.

.PARAMETER IgnoreNotificationCount
For fixes in Error or Pending status, sends them even if notification count is equal or less then zero and does not decrement the notification count.

.PARAMETER SkipStatus
When determining if there are fixes to send, ignore fixes with these status values.  They will still be sent but only if there are others justifying the notification.  Defaults to "Hold"

.PARAMETER Attachments
Specifies the path and file names of files to be attached to the email message. You can use this parameter or pipe the paths and file names to Send-MailMessage.

.PARAMETER Bcc
Specifies the email addresses that receive a copy of the mail but are not listed as recipients of the message. Enter names (optional) and the email address, such as Name <someone@fabrikam.com>.

.PARAMETER Body
Specifies additional content to append to end of the email message.

.PARAMETER Encoding
Specifies the type of encoding for the target file. The default value is UTF8NoBOM.

.PARAMETER Cc
Specifies the email addresses to which a carbon copy (CC) of the email message is sent. Enter names (optional) and the email address, such as Name <someone@fabrikam.com>.

.PARAMETER DeliveryNotificationOption
Specifies the delivery notification options for the email message. You can specify multiple values. None is the default value. The alias for this parameter is DNO.

.PARAMETER From
The From parameter is required. This parameter specifies the sender's email address. Enter a name (optional) and email address, such as Name <someone@fabrikam.com>.

.PARAMETER SmtpServer
Specifies the name of the SMTP server that sends the email message.

.PARAMETER Priority
Specifies the priority of the email message. Normal is the default. The acceptable values for this parameter are Normal, High, and Low.

.PARAMETER Subject
The Subject parameter is not required. This parameter specifies the subject of the email message.  Defaults to "Results of Invoke-IssueCheck $(Get-Date)"

.PARAMETER To
The To parameter is required. This parameter specifies the recipient's email address. If there are multiple recipients, separate their addresses with a comma (,). Enter names (optional) and the email address, such as Name <someone@fabrikam.com>.

.PARAMETER Credential
Specifies a user account that has permission to perform this action. The default is the current user.

.PARAMETER UseSsl
The Secure Sockets Layer (SSL) protocol is used to establish a secure connection to the remote computer to send mail. By default, SSL is not used.

.PARAMETER Port
Specifies an alternate port on the SMTP server. The default value is 25, which is the default SMTP port.

.EXAMPLE
Read-IssueFix | Send-IssueMailMessage -From no-reply@contoso.com -To cares@contoso.com | Write-IssueFix

.INPUTS
IssueFix 

.OUTPUTS
IssueFix The fix object(s) that were send out via mailmessage, with nofiticatonCount updated (if not IgnoreNotificationCount)

#>

function Send-IssueMailMessage {
    Param (
        [Parameter(Mandatory=$false,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$false)]
        [PSObject] $Fix,
        
        [Parameter(Mandatory=$false,Position=1,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
        [Switch] $IgnoreNotificationCount,

        [Parameter(Mandatory=$false,Position=2,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
        [String[]] $SkipStatus = @("Hold"),

        [Parameter(Mandatory=$false,Position=3,ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false)]
        [Switch] $ReturnOnlySent,

        [Parameter(ValueFromPipeline=$false)]
        [Alias('PsPath')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        ${Attachments},

        [ValidateNotNullOrEmpty()]
        [string[]]
        ${Bcc},

        [Parameter(Position=4)]
        [ValidateNotNullOrEmpty()]
        [string]
        ${Body},

        [Alias('BE')]
        [ValidateNotNullOrEmpty()]
        [System.Text.Encoding]
        ${Encoding},

        [ValidateNotNullOrEmpty()]
        [string[]]
        ${Cc},

        [Alias('DNO')]
        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.DeliveryNotificationOptions]
        ${DeliveryNotificationOption},

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        ${From},

        [Parameter(Position=3)]
        [Alias('ComputerName')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${SmtpServer},

        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.MailPriority]
        ${Priority},

        [Parameter(Mandatory=$false, Position=3)]
        [Alias('sub')]
        [string]
        ${Subject},

        [Parameter(Mandatory=$true, Position=2)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        ${To},

        [ValidateNotNullOrEmpty()]
        [pscredential]
        [System.Management.Automation.CredentialAttribute()]
        ${Credential},

        [switch]
        ${UseSsl},

        [ValidateRange(0, 2147483647)]
        [int]
        ${Port}
    )
    Begin {
        [PSObject[]] $fixes = @()
    }
    Process {
        $fixes += $fix
    }

    End {
        $count = 0

        #Store all of the fixes for the return
        $allfixes = $fixes

        # Calculate the count, based on SkipStatus
        if (!$SkipStatus) {
            if (!$IgnoreNotificationCount) {
                $count = ($fixes | Where-Object NotificationCount -gt 0).Count
            } else {
                $count = $fixes.Count
            }
        } else {
            if (!$IgnoreNotificationCount) {
                $count = ($fixes | Where-Object NotificationCount -gt 0 | Where-Object {$SkipStatus -notcontains $_.Status}).Count
            } else {
                $count = ($fixes | Where-Object Status -NotIn $SkipStatus).Count
            }
        }
               
        # As long as count is -gt 0, we should build the email
        If ($count -gt 0) { 
            # If we are not ignoring notification count then we need to filter and decrement, BUT ONLY IF SENDING A MESSAGE
            if (!$IgnoreNotificationCount) {
                $fixes = $fixes | Set-IssueFix -DecrementNotificationCount
                #Re-store AllFixes post change for the return
                $allfixes = $fixes
            }       
            $fixes = $fixes | Where-Object Status -NotIn $SkipStatus  | Sort-Object -Property sequenceNumber, statusDateTime

            [String] $messagePart = ""
            [PSObject[]] $theseFixes = @()
            forEach($status in ([enum]::getValues([IssueFixStatus]))) {
                if ($status -notin $SkipStatus) {
                    $theseFixes = $fixes | Where-Object Status -eq $status
                    if ($theseFixes.Count -gt 0) {
                        $messagePart += "<p>$($status)</p>"
                        $messagePart += $theseFixes | ConvertTo-Html -Fragment -Property @("statusDateTime", "checkName", "fixDescription", "fixResults")
                    }
                }
            }

            [String] $head = @"
            <style>
                table {
                    border-collapse: collapse;
                }
                
                table, th, td {
                    border: 1px solid black;
                }
                tr:nth-child(even) {
                    background-color: #f2f2f2;
                }
        
                th, td {
                    padding: 15px;
                    text-align: left;
                }
            </style>
"@
            if ($Body) {
                $passedBody = "<p><i>$Body</i></p>"
                $PSBoundParameters.Remove("Body") | Out-Null
            } else {
                $passedBody = ""
            }

            if (!$Subject) {
                $Subject = "Results of Invoke-IssueCheck $(Get-Date)"
            } else {
                $PSBoundParameters.Remove("Subject") | Out-Null
            }

            [String] $theBody = "$messagePart $passedBody"

            [String] $message = ConvertTo-Html -Head $head -Title $Subject -PreContent $theBody -As List

            $PSBoundParameters.Remove("Fix") | Out-Null
            if ($PSBoundParameters.ContainsKey("IgnoreNotificationCount")) {
                $PSBoundParameters.Remove("IgnoreNotificationCount") | Out-Null
            }
            if ($PSBoundParameters.ContainsKey("SkipStatus")) {
                $PSBoundParameters.Remove("SkipStatus") | Out-Null
            }
            if ($PSBoundParameters.ContainsKey("ReturnOnlySent")) {
                $PSBoundParameters.Remove("ReturnOnlySent") | Out-Null
            }
            
        
            Send-MailMessage -Body $message -BodyAsHtml -Subject $Subject @PSBoundParameters | Out-Null
        } else {
            #If count = 0 then there are not fixes to send, clear the variable so that the return is correct
            $fixes = @()
        }

        if ($ReturnOnlySent) {
            #Return just the fixes that were sent
            Write-Output $fixes
        } else {
            # Return all fixes
            Write-Output $allfixes
        }
    }
}