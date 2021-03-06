# =========================================================================  
#   Copyright 2012 Brad Griffin
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
# =========================================================================


##Function Listing##
function fileRefresh {
  param ($filePath)
  $fileExists = Test-Path $filePath
  if ($fileExists -eq $True) {
    $removeTempFile = Remove-Item $filePath
    $createNewFile = New-Item $filePath -type file}
  else {$createTempFile = New-Item $filePath -type file} }
  
function getMembers {
  param ($groups)
    foreach ($g in $groups)
        {$priv = Get-QADGroupmember $g
        $priv | Add-Member -force -type NoteProperty -name RelatedGroup -value $g
        $priv} }
        
function trimFile {
  param ($textFile)
    $textFileContent = gc $textFile | Out-String
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
$nonExp = Get-QADUser * -PasswordNeverExpires -sizelimit 0 | 
  Where-Object {$_.AccountIsDisabled -eq $False} |
  Format-Table -auto -property LogonName,Name,Type,LastLogonTimestamp,AccountIsExpired,AccountIsLockedOut
Out-File -filepath $noExpFile -encoding Unicode -inputobject $nonExp 

"Filtering for active users...
"
$nECount = $nonExp.count
"There are $nECount active user with non-expiring passwords.
"

#This text file should contain the groups you want to test for.
$privGroupFile = "C:\Scripts\Audit\priv_groups.txt"

"Retrieving nested group information...
"
do {
  trimFile($privGroupFile)
  $privGroups = Get-Content $privGroupFile
  $privGroupsCompare = Get-Content $privGroupFile | out-string
  $newGroupsArray = getMembers($privGroups) | 
    Where-Object {$_.Type -eq "group"} | 
    Where-Object {$_.NTAccountName -notlike "AHS*"} | 
    Select-Object NTAccountName | 
    Sort-Object NTAccountName -Unique | 
    Format-Table -auto -HideTableHeaders | Out-String -stream
  $newGroupsArrayTrim = foreach ($line in $newGroupsArray)
    {$line.trim()}
                          
  $newGroupsString = $newGroupsArrayTrim | Out-String
  $newGroupsTrim = $newGroupsString.trim()
  Out-File -filepath $privGroupFile -encoding Unicode -append -inputobject $newGroupsTrim

  $updatedPrivGroup = gc $privGroupFile
  $uniquePrivGroup = $updatedPrivGroup | sort | gu | Out-String
  Out-File -filepath $privGroupFile -encoding Unicode -inputobject $uniquePrivGroup 
  trimFile($privGroupFile)
  $privGroupsFinalCompare = gc $privGroupFile | Out-String
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
  Where-Object {$_.Type -eq "user"} |
  Where-Object {$_.AccountIsDisabled -eq $False} |  
  Sort-Object Name -Unique | 
  #sort-object -property @{Expression="RelatedGroup";Descending=$false}, @{Expression="LastLogon";Descending=$false} |
  Format-Table -auto -property LogonName,Name,Type,RelatedGroup,PasswordLastSet,PasswordExpires,LastLogon,LastLogonTimestamp,AccountIsExpired,AccountIsLockedOut
  
#Formatted output of group memberships
"Retrieving group output...
"
$groupListing = foreach ($g in $privGroups)
  {$groupOutput = $g
   $groupOutput2 = Get-QADGroupmember($g) | Format-Table -auto -property LogonName,Name,Type,RelatedGroup,PasswordLastSet,LastLogon,LastLogonTimestamp,AccountIsDisabled,AccountIsExpired,AccountIsLockedOut
    Out-File -filepath $groupFile -encoding Unicode -append -inputobject $groupOutput -width 800
    Out-File -filepath $groupFile -encoding Unicode -append -inputobject $groupOutput2 -width 800
    }

#Format, label, and post the output to text file.
"Creating outfiles...
"
Out-File -filepath $userFile -encoding Unicode -append -inputobject 'Unique User Accounts' -width 800
Out-File -filepath $userFile -encoding Unicode -append -inputobject 'Note: This output excludes accounts that are disabled.'
Out-File -filepath $userFile -encoding Unicode -append -inputobject $uniquePrivUsers -width 800

$allPrivCount = $allPriv | Where-Object {$_.Type -eq "user"}
$allPrivCount1 = $allPrivCount.count
"Results"
"There are $allPrivCount1 accounts with elevated access to the domain."
""
"For a listing of these users, please see output file at $userFile
"
$admins = getMembers("Administrators") | 
 Where-Object {$_.Type -eq "user"}
$adminsCount = $admins.count
"There are $adminsCount accounts in the default Administrators group.
"
"For more details on the members of each group, see the outfile at $groupFile"

