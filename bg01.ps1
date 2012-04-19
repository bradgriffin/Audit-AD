##Function Listing##
function fileRefresh {
  param ($filePath)
  $fileExists = test-path $filePath
  if ($fileExists -eq $True) {
    $removeTempFile = Remove-Item $filePath
    $createNewFile = New-Item $filePath -type file}
  else {$createTempFile = New-item $filePath -type file} }
  
function getMembers {
  param ($groups)
    foreach ($g in $groups)
        {$priv = Get-qadgroupmember $g
        $priv | Add-Member -force -type NoteProperty -name RelatedGroup -value $g
        $priv} }
        
function trimFile {
  param ($textFile)
    $textFileContent = gc $textFile | out-string
    $textFileTrim = $textFileContent.trim()
    Out-File -filepath $textFile -encoding Unicode -inputobject $textFileTrim }
"
Loading...
"
#Test to see if the output file has been created. If it has, delete it and start over.
#If not, create it
"Creating output files...
"
$userFile = "C:\TEMP\userFile.txt"
$groupFile = "C:\TEMP\groupFile.txt"
$noExpFile = "C:\TEMP\activeNoPWExp.txt"
fileRefresh($userFile)
fileRefresh($groupFile)
fileRefresh($noExpFile)

"Finding users with non-expiring passwords...
"
$nonExp = get-qaduser * -PasswordNeverExpires -sizelimit 10000 | 
  where-object {$_.AccountIsDisabled -eq $False} |
  where-object {$_.AccountisExpired -eq $False} |
  ft -auto -property LogonName,Name,Type,LastLogonTimestamp
Out-File -filepath $noExpFile -encoding Unicode -inputobject $nonExp 

"Filtering for active users...
"
$nECount = $nonExp.count
"There are $nECount active user with non-expiring passwords.
"

#This text file contains the listing of the groups we want to test for. This was
#created through discussion with the Intel team.
$privGroupFile = "C:\Scripts\Audit\priv_groups.txt"
"Retrieving nested group information...
"
do {
  trimFile($privGroupFile)
  $privGroups = gc $privGroupFile
  $privGroupsCompare = gc $privGroupFile | out-string
  $newGroupsArray = getMembers($privGroups) | 
    where {$_.Type -eq "group"} | 
    where {$_.NTAccountName -notlike "AHS*"} | 
    select NTAccountName | 
    sort NTAccountName -Unique | 
    ft -auto -HideTableHeaders | Out-String -stream
  $newGroupsArrayTrim = foreach ($line in $newGroupsArray)
    {$line.trim()}
                          
  $newGroupsString = $newGroupsArrayTrim | Out-String
  $newGroupsTrim = $newGroupsString.trim()
  Out-File -filepath $privGroupFile -encoding Unicode -append -inputobject $newGroupsTrim

  $updatedPrivGroup = gc $privGroupFile
  $uniquePrivGroup = $updatedPrivGroup | sort | gu | out-string
  Out-File -filepath $privGroupFile -encoding Unicode -inputobject $uniquePrivGroup 
  trimFile($privGroupFile)
  $privGroupsFinalCompare = gc $privGroupFile | out-string
   }
until ($privGroupsFinalCompare -eq $privGroupsCompare)
"Retrieving user information...
"

$privGroups = gc $privGroupFile
$allPriv = getMembers($privGroups)

#Formated output of all objects
#$formatedAllPriv = $allPriv | 
#  Format-Table -auto -property Name,Type,RelatedGroup,PasswordLastSet,LastLogon,AccountIsDisabled,AccountisExpired,AccountisLockedOut

#Formatted output of all active users
"Formatting user output...
"
$uniquePrivUsers = $allPriv | 
  where-object {$_.Type -eq "user"} |
  where-object {$_.AccountIsDisabled -eq $False} |
  where-object {$_.AccountisExpired -eq $False} |  
  sort-object Name -Unique | 
  #sort-object -property @{Expression="RelatedGroup";Descending=$false}, @{Expression="LastLogon";Descending=$false} |
  Format-Table -auto -property LogonName,Name,Type,RelatedGroup,PasswordLastSet,LastLogon,LastLogonTimestamp,AccountIsLockedOut
  
#Formatted output of group memberships
"Retrieving group output...
"
$groupListing = foreach ($g in $privGroups)
  {$groupOutput = $g
   $groupOutput2 = get-qadgroupmember($g) | Format-Table -auto -property LogonName,Name,Type,RelatedGroup,PasswordLastSet,LastLogon,LastLogonTimestamp,AccountIsLockedOut
    Out-File -filepath $groupFile -encoding Unicode -append -inputobject $groupOutput -width 800
    Out-File -filepath $groupFile -encoding Unicode -append -inputobject $groupOutput2 -width 800
    }

#Format, label, and post the output to text file.
"Creating outfiles...
"
Out-File -filepath $userFile -encoding Unicode -append -inputobject 'Unique User Accounts' -width 800
Out-File -filepath $userFile -encoding Unicode -append -inputobject $uniquePrivUsers -width 800

$allPrivCount = $allPriv | where {$_.Type -eq "user"}
$allPrivCount1 = $allPrivCount.count
"Results"
"There are $allPrivCount1 accounts with elevated access to the domain."
""
$uniquePrivUsers 
"For a listing of these users, please see output file at $userFile
"
$admins = getMembers("Administrators") | 
 where {$_.Type -eq "user"}
$adminsCount = $admins.count
"There are $adminsCount accounts in the default Administrators group.
"
$admins
"For more details on the members of each group, see the outfile at $groupFile"

