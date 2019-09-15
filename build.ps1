Import-Module PowerShellGet

#Publish to PSGallery and install/import locally
Publish-Module -Path .\PoshIssues -Repository PSGallery -Verbose
Install-Module -Name .\PoshIssues -Force
Import-Module -Name .\PoshIssues -Force