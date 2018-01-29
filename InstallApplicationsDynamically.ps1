<#
.SYNOPSIS
To install applications dynamically in SCCM during the build process.
.DESCRIPTION
The following is required for the script to work:
 - The device will need to have a primary user assigned to it.
 - A unique container name with the user collections which have applications deployed to it.
 - Application enabled to install during Task Sequence.
The script will n d collecting the information a .csv file is created with an Application ID and the application name.

.EXAMPLE
You will require the Site Server, Sitecode and the unique container name were all the user collections have applications deployed to.

InstallApplicationsDynamically.ps1 - SiteCode "AU1" -ContainerName "Tier 3 Applications" -SiteServer "SiteServerName.astzum.local"

#>
########## Param ####################

Param(

[Parameter(Mandatory=$true)]
[String] $SiteCode,
[Parameter(Mandatory=$true)]
[String] $ContainerName,
[Parameter(Mandatory=$true)]
[String] $SiteServer

)


################# Functions ################# 
Function LogWrite
{
   Param ([string]$logstring)
   Add-content "C:\Windows\Temp\Tier3ApplicationScript.log" -value $logstring
}


################# Setting Variables #################
$Count = 1
$csvfile= @()
$CsvFileCheck = $false 
$ResourceName = $env:COMPUTERNAME

################# Script #################
#Find the Primary User of the Device

$RelationShipArray = Get-WmiObject -ComputerName $SiteServer -Class SMS_UserMachineRelationship -Namespace root\SMS\Site_$SiteCode -Filter "ResourceName='$ResourceName'"
foreach ($user in $RelationShipArray){
    If ($user.Isactive -eq $true){
        $PrimaryUser = $user.UniqueUserName
    }

}
If ($PrimaryUser -eq $null){
    LogWrite "Unable to get the PrimaryUser for the device. Exiting Script."
    Exit 0
    }else{
        LogWrite "PrimaryUser is $PrimaryUser"
    }

#Change the backslash to double backslash for the query to work
$PrimaryUser = $PrimaryUser.Replace('\','\\')

#Find the Resource ID of Primary User
$PrimaryUSerID = (Get-WmiObject -ComputerName $SiteServer  -Namespace root\SMS\Site_$SiteCode -Class SMS_R_USER -Filter "UniqueUserName='$PrimaryUser'").ResourceID
LogWrite "PrimaryUserID is $PrimaryUserID"

#Find USer Collection Continer ID 
$ContainerNodeId = (Get-WmiObject -ComputerName $SiteServer -Class SMS_ObjectContainerNode -Namespace root/SMS/site_$SiteCode -Filter "Name='$ContainerName' and  ObjectTypeName='SMS_Collection_User'").ContainerNodeId

#Query what collection ID's are under the contianer name
$ArrayCollectionId = (Get-WmiObject -ComputerName $SiteServer -Class SMS_ObjectContainerItem -Namespace root/SMS/site_$SiteCode -Filter "ContainerNodeID='$ContainerNodeId'").InstanceKey

#Check every collection under the Tier 3 application container to see if the user is a member of it
Foreach ($collectionid in $ArrayCollectionId){
    
    #There is a class for every collection. Querying each class is the quickest method.
    $class = "SMS_CM_RES_COLL_$collectionid"
    
    #Serach the collection
    $Collection =  (Get-WmiObject -ComputerName $SiteServer -Class $class -Namespace root\SMS\Site_$SiteCode -filter "ResourceID=$PrimaryUSerID").ResourceID
    
    #The search results are successful check to see what applications are being deployed to that collection.
        If ($Collection -ne $null){
        LogWrite "User is a member of the collection:$CollectionId"
        $Applications = (Get-WmiObject -ComputerName $SiteServer -Class SMS_ApplicationAssignment -Namespace root/SMS/site_$SiteCode -Filter "TargetCollectionID='$CollectionId' and OfferTypeID='0'").ApplicationName
            
            If ($Applications -ne $Null){
                foreach ($ApplicationName in $Applications) {
                LogWrite "The collection $collectionId has the Application $ApplicationName deployed to it. "
            
                #Create a Application Variable for every application needing to be installed.
                $Id = "{0:00}" -f $Count
                $AppId = "AppID$Id"
                $Count = $Count + 1
                LogWrite "AppID is $AppID"
            
                #Setting Task Sequence Variable     
                $CsvFileCheck = $true
                $row = New-Object System.Object
                $row | Add-Member -MemberType NoteProperty -Name "AppId" -Value $AppID 
                $row | Add-Member -MemberType NoteProperty -Name "Name" -Value $ApplicationName
                $csvfile += $row
                }    
              }else{
                LogWrite "No Application found for collection $Collection"
                }
        
        
        }
        If ($CsvFileCheck -eq $true){$csvfile | Export-CSV -Path "C:\Windows\Temp\Tier3ApplicationScript.csv" -NoTypeInformation}
}
