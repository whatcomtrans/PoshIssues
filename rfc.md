Issues can be detected or needed changes identified in systems or syncronizations made between systems.

# Check
Check something and if needed recomend a command to change or fix something.  Some changes can be executed automatically while others should wait pending review.  All should be logged and communicated.  Checks should be processed in order where needed.   Checks must be independent of each other.

Database/storage should be a simple file.

Checks are conducted by executing either ScriptBlocks or scripts that return either a PowerShell string, ScriptBlock or a custom fix object.

The IssueCheck object contains:
+ databaseId (GUID)
+ sequenceNumber (Long Int)
+ checkName (String)
+ checkScriptPath (String)
+ checkScriptBlock (ScriptBlock)
+ checkParameters (Hashtable)
+ status (Int) Enabled | Disabled
+ defaultFixDescription (String)
+ defaultStatus (Int) Ready | Pending | Complete | Error | Canceled
+ defaultNotificationCount (Int)

# Fix
A fix is a ScriptBlock to make the change recomended by the fix.  It supports a number of features to allow for reviewing and documenting the fixes.

The IssueFix object contains:
+ databaseId (GUID)
+ sequenceNumber (Long Int)
+ combinedSequenceNumber (Long Int)
+ checkName (String)
+ fixCommand (ScriptBlock)
+ fixDescription (String)
+ status (Int) Ready | Pending | Complete | Error | Canceled
+ fixResults (String)
+ notificationCount (Int)

# Sequence Number
Both the IssueCheck and the IssueFix have sequence numbers.  IssueFix also has a combinedSequenceNumber.  If the IssueCheck object is available to the IssueFix, then the combinedSequenceNumber is calculated from the IssueCheck.sequenceNumber multiplied by 1,000,000,000 plus the IssueFix sequenceNumber.  If not, the combinedSequenceNumber is the same as sequenceNumber.  It is this combinedSequenceNumber that is used for sorting fixes.

# Notification Count
Each time a notificaton is sent for a fix the notificationCount is decremented by one. By default, only fixes with a notification count greater then 0 are sent. This allows for control over how often a fix is notified about.  If the IssueCheck/IssueFix creator does not want any notifications sent (by default), set to 0.  If only want to be notified once, set to 1.  The notification cmdlets provide control over when this value is used.  For example, parameters allow only using the notification count for "Pending" fixes and instead setting "Completed/Error" fixes to 0 after first notification.  Or the notification cmdlet can send for all fixes and ignore this value.

# cmdlets
## Processing checks
Run a check, either all of them, by checkName, or by providing all fix details.  Returns results, optionally updating database.
### Invoke-IssueCheck

## Issue Checks
Add, changes, removes, enables or disables different checks stored in the database.
### New-IssueCheck
### Set-IssueCheck
### Remove-IssueCheck
### Disable-IssueCheck
### Enable-Check

## Fixes
Review, cancel or complete, remove issue fixes.  Fixes in a pending state can be canceled or completed.  Fixes can come from results or be loaded from the database.  Fixes that are automatically executed ("Completed" or "Error" states) can not be canceled or completed, only those in a "Pending" state.  New-IssueFix creates a fix object for return and use in checks.
### New-IssueFix
Returns a PSObject<PoshIssues.Fix> object.
### Add-IssueFix
Adds a PSObject<PoshIssues.Fix> object to a database.
### Remove-IssueFix
Removes a PSObject<PoshIssues.Fix> object from a database.
### Get-IssueFix
Gets a PSObject<PoshIssues.Fix> object from a database.
### Set-IssueFix
Changes properties of a PSObject<PoshIssues.Fix> object, either directly or in a database.
### Complete-IssueFix
Changes status property of a PSObject<PoshIssues.Fix> object to "Ready".  Used as a verb to change from Pending or Canceled to Ready.
### Cancel-IssueFix
Changes status property of a PSObject<PoshIssues.Fix> object to "Cancel".

## Notification
Support sending notification of either/both completed and pending fixes.  Starting off with email bit could add other channels.
### Send-IssueFixMail
### Set-IssueFixMail

## Database
+ New-IssueDatabase
+ Set-IssueDatabase
+ Import-IssueDatabase
+ Export-IssueDatabase

# Database
The data will be stored in a single complex object called Database.  It will have properties for check and fix defaults.  It will contain arrays of issue checks, issue fixes and notification channel settings.

All of the cmdlets will load the database file using import-clixml, further ending the objects as needed.  Each cmdlet will save changes to the database object using export-clixml.

Since the object only supports a single use at a time, a lock file will be created, checked and deleted.  The file will have the same path and file name but with a .lock extension.  The Import-IssueDatabase will check for the lock file and may create it (default).  Save-IssueDatabase may delete (default) the lock file.

Each cmdlet will have parameters for the database object or a path to the database file.

# Workflow
## On Demand

User adds (New-IssueCheck) checks to the database in the form of ScriptBlocks or paths to script files.  A hashtable of parameters to be passed may also be saved.  Each issue check supports providing defaults foe the fix objects such as fixDescription, checkName, "Pending" or "Ready" status.

User calls Invoke-IssueCheck to run through all (or filtered) IssueChecks, executing each check.  Checks return 0 or more fix objects.  If the command returns Strings or ScriptBlocks these will be converted to Fix objects using New-IssueFix using the defaults saved with the IssueCheck.  Depending on invoke parameters, any fixes returned in the "Ready" state will be executed in sequenceNumber order.  They will also be returned as results and may (parameter) be added to the database.  Fixes are executed after each check, before the next check to allow check processes to build on each other.

Checks can be run multiple times but will only allow one fix to exist by comparing the fixCommand.  The Invoke-IssueCheck, by parameter, can run through the checks repeatedly until no new fixes are generated.  This allows checks to build upon each other and respond to fixes.  It also allows for single notification of issues.

After invoking, the user can review the results either by iterating the return or by querying the database with Get-IssueFix.

Fixes in the "Pending" state can be changed to "Ready" through either the Set-IssueFix or the Complete-IssueFix cmdlets.  If instead a fix should be skipped or canceled, use either Set-IssueFix changing status to "Canceled".

Re-running Invoke-IssueCheck will find any fixes in the ready state and execute those first.

When finished a notification of all fixes, either still pending or finished, can be sent with the Send-IssueFixMail cmdlet. Each time a notificaton is sent for a fix the notificationCount is decremented by one. By default, only fixes with a notification count greater then 0 are sent. This allows for control over how often a fix is notified about. Parameters for the cmdlet can be saved in the database using Set-IssueFixMail cmdlet.

If all done, fixes that are completed or errored can be removed using Remove-IssueFix, from the database, allowing those same fixes to be presented again.  For example, an issue can be raised, addressed and then removed so the user can be notified if it comes up again.

## Scheduled
Most issues processes will be scheduled.  In fact there coukd be different databases for different schedules.

The scheduled job will:
1) Invoke-IssueCheck using saved database
2) Send-IssueFixMail notifications
3) Remove-IssueFix fixes that have completed or errored, perhaps based on the notificationCount.

Users then recieve the the notification and can review both ezecuted fixes and "Pendong" fixes.  The user can use fix cmdlets to change the status of pending fixes which will then be processed at the next scheduled Invoke.

# Use Cases
Detect system irregularities or failures.  Check coukd be to ping one or more systems.  If a system doesn't respond a fix could be generated in the "Pending" state to just provide notice or maybe the fix is a command to restart something.  Notification count could be set high so users keep getting the notice.

Note, the module currently does not have a method for removing a fix that is resolved out of band.

Don't let the words "issue" or "fix" limit how this module can be used.

For example one of the first uses of this module was to keep Active Directory up to date with a HR system.  So the check compares all employee AD User object titles with those that are set in the HR database.  Fixes with a "Set-ADUser -Identity [distinguishedName] -Title [new title]" are generated for each descrepency.  These fixes are either executed imediately ("Ready") or await review ("Pending").  In either case IT is notified through email.

# Common Cmdlet Parameters

## Database Parameters
All cmdlets except New-IssueFix take the datatbase parameters.  Use either Database or DatabasePath.  However the database parameters are not required.  If not provided, the cmdlets will not save the created/modified objects.

### Database
Takes a database object, preventing it feom having to be imported and saved each time.  Most cmdlets return the results but when combined with -PassThru switch parameter, the cmdlet will return the datatbasr object instead.  Database may be piped in.

### PassThru
Used to return the database object rather then the resulting objects.

### DatabasePath
The full path and filename of the database file.  When this is used the cmdlet will use the import and export cmdlets to load and save the database to this file.

### ReadOnly
The ReadOnly switch will not modify the database object.  It will not save back to the database path or create a lock file on import.
