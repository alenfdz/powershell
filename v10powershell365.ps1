[CmdletBinding()]

Param(
  [string] $AccessKey,
  [string] $SecurityKey,
  [string] $BucketName,
  [string] $USERNAME,
  [string] $PASSWORD
 )


# Modify the $url 
#Variables
$url = "http://download.veeam.com/VeeamBackupOffice365_4.0.0.2516.zip"
$output = "C:\install\VeeamBackupOffice365_4.0.0.2516.zip"
$source = "C:\install"

#Create install directory
New-Item -itemtype directory -path $source

#Get Veeam Backup for Office 365 zip
(New-Object System.Net.WebClient).DownloadFile($url, $output)


#Initialize Data Disks
#Get-Disk | ` 
#Where partitionstyle -eq 'raw' | ` 
#Initialize-Disk -PartitionStyle GPT -PassThru | ` 
#New-Partition -AssignDriveLetter -UseMaximumSize | ` 
#Format-Volume -FileSystem ReFS -NewFileSystemLabel "datadisk" -Confirm:$false

Expand-Archive C:\install\VeeamBackupOffice365_4.0.0.2516.zip -DestinationPath C:\install\ -Force

### Veeam Backup Office 365
$MSIArguments = @(
"/i"
"$source\Veeam.Backup365_4.0.0.2516.msi"
"/qn"
"/norestart"
"ADDLOCAL=BR_OFFICE365,CONSOLE_OFFICE365,PS_OFFICE365"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

Sleep 60

### Veeam Explorer for Microsoft Exchange
$MSIArguments = @(
"/i"
"$source\VeeamExplorerForExchange_10.0.0.443.msi"
"/qn"
"/norestart"
"ADDLOCAL=BR_EXCHANGEEXPLORER,PS_EXCHANGEEXPLORER"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

Sleep 60


### Veeam Explorer for Microsoft SharePoint
$MSIArguments = @(
"/i"
"$source\VeeamExplorerForSharePoint_10.0.0.443.msi"
"/qn"
"/norestart"
"ADDLOCAL=BR_SHAREPOINTEXPLORER,PS_SHAREPOINTEXPLORER"
"ACCEPT_THIRDPARTY_LICENSES=1"
"ACCEPT_EULA=1"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

Sleep 60


#Create a credential
#log "Creating credentials"
#$osname = $env:computername
#$fulluser = "$($osname)\$($USERNAME)"
#$secpasswd = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
# How to do this in AWS?
#$mycreds = New-Object System.Management.Automation.PSCredential($fulluser, $secpasswd)
$seckey = ConvertTo-SecureString $SecurityKey -AsPlainText -Force




$Driveletter = get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" | where-object {$_.DriveLetter -like "D*"}
$VeeamDrive = $DriveLetter.DriveLetter
$repo = "$($VeeamDrive)\backup repository"
New-Item -ItemType Directory -path $repo -ErrorAction SilentlyContinue



$scriptblock= {
Import-Module Veeam.Archiver.PowerShell
Connect-VBOServer
$proxy = Get-VBOProxy 
Add-VBORepository -Proxy $proxy -Name "Default Backup Repository 1" -Path "D:\backup repository" -Description "Default Backup Repository 1" -RetentionType ItemLevel
$repository = Get-VBORepository -Name "Default Backup Repository"
Remove-VBORepository -Repository $repository -Confirm:$false
Add-VBOAmazonS3Account -AccessKey $AccessKey -SecurityKey $seckey 
$account = Get-VBOAmazonS3Account -AccessKey $AccessKey
$connection = New-VBOAmazonS3ServiceConnectionSettings -Account $account -RegionType Global
 
$container = Get-VBOAmazonS3Bucket -AmazonS3ConnectionSettings $connection  -name $BucketName

Add-VBOAmazonS3Folder -bucket $container -Name "Veeam"
$folder = Get-VBOAmazonS3Folder -bucket $container
Add-VBOAmazonS3ObjectStorageRepository -Folder $folder -Name "VBORepository"
}

# $session = New-PSSession -cn $env:computername -Credential $mycreds 
$session = New-PSSession -cn $env:computername -Credential $mycreds
	Invoke-Command -Session $session -ScriptBlock $scriptblock 
	Remove-PSSession -VMName $env:computername