<#

.SYNOPSIS
Outputs a list of all users in specified groups, including nested groups.

.DESCRIPTION
Outputs a list of all users in specified groups, including nested groups. Can output to multiple formats including CSV, JSON to file or just CLI

.PARAMETER OutputPath
Specifies the path for file based output

.PARAMETER SingleOutput
Tells the script to output all top level groups to a single file instead of a file per top level group

.PARAMETER DontRecurseNested
Tells the script to not search through nested groups

.PARAMETER AutoConfirm
Skips the confirmation stage

.PARAMETER OutputFormat
What format the script should output in:
CLI (Default), JSON, CSV

.EXAMPLE
./UsersInGroups.ps1 SomeHostName
Outputs to CLI all users in that group and nested groups after user confirms requirements

./UsersInGroups.ps1 -SingleOutput -DontRecurseNested -Autoconfirm -OutputFormat JSON
Will prompt user to imput hostnames. Will not ask user to confirm and will not recurse through nested group. Outputting into a single json file for all hosts.

.NOTES
  Version:        1.0
  Author:         Julian A Andreae

.LINK
-- public github location will go here

#>
Param (
    [CmdletBinding(PositionalBinding=$false)]
    [Parameter(ParameterSetName='DefaultSet')]
    [String]$OutputPath = $Env:USERPROFILE + "\Desktop\",

    [Parameter(ParameterSetName='DefaultSet')]
    [switch]$SingleOutput = $false,

    [Parameter(ParameterSetName='DefaultSet')]
    [switch]$DontRecurseNested = $false,

    [Parameter(ParameterSetName='DefaultSet')]
    [switch]$AutoConfirm = $false,

    [Parameter(ParameterSetName='DefaultSet')]
    [ValidateSet('CSV','JSON', 'CLI')]
    [String]$OutputFormat = "CLI",

    [Parameter(Mandatory=$true, ParameterSetName='DefaultSet', ValueFromRemainingArguments=$true)]
    [ValidateNotNullOrEmpty()]
    [String[]]$Groups
)

$timestamp = (Get-Date -Format “yyyyMMddTHHmmssffff”)

if (!$AutoConfirm){
    #Confirm with user that the details are correct
    $UserConfirmed = $false
    Write-Host -ForegroundColor White "Please confirm the following is correct:"
    Write-Host -ForegroundColor White ""
    Write-Host -ForegroundColor White "Groups to check:     $groups"
    Write-Host -ForegroundColor White "Ouput format:        $OutputFormat"
    if ($OutputFormat -ne "CLI"){
        Write-Host -ForegroundColor White "Output path:         $OutputPath"
        Write-Host -ForegroundColor White "Single output file:  $SingleOutput"
    }
    Write-Host -ForegroundColor White "Dont recurse nested: $DontRecurseNested"
    Write-Host -ForegroundColor White ""
    $UserConfirmed = Read-Host "Continue? [y/n]"
    while($UserConfirmed -ne "y")
    {
        if ($UserConfirmed -eq 'n') {exit}
        $UserConfirmed = Read-Host "Ready? [y/n]"
    }
}

Write-Host -ForegroundColor Yellow "Loading Active Directory Module"
import-module activedirectory

function getGroupMembers([string] $groupName, [System.Collections.ArrayList] $outputObject){
    Write-Host -ForegroundColor Yellow "Reading from group $groupName"
    $groupMembers = Get-ADGroupMember -identity $groupName | Sort-Object -Property objectClass,Name
    ForEach($groupMember in $groupMembers){
        if ($groupMember.objectClass -eq "group"){        
            $ID =  $groupMember.distinguishedName
            $Name = $groupMember.name
            if(!$DontRecurseNested){
                getGroupMembers $Name $outputObject
            }
        }
        elseif ($groupMember.objectClass -eq "user"){
            $user = Get-ADUser -Property DisplayName $groupMember | Select-Object Name,DisplayName | Sort-Object -Property Name
            $ID = $user.Name
            $Name = $user.DisplayName
        }
     
        $resultItem = New-Object System.Object
        $resultItem | Add-Member -MemberType NoteProperty  -Name "Group" -Value $groupName
        $resultItem | Add-Member -MemberType NoteProperty  -Name "Type" -Value $groupMember.objectClass
        $resultItem | Add-Member -MemberType NoteProperty  -Name "ID" -Value $ID
        $resultItem | Add-Member -MemberType NoteProperty  -Name "Name" -Value $Name
        $outputObject.Add($resultItem)| Out-Null
    }

}

function output($outputResults){
    $outputResults = $outputResults | Sort-Object -Property Group, Type, ID
    switch ($OutputFormat){
        CSV {
            $outputResults = $outputResults |
            ConvertTo-Csv|
            Select-Object -Skip 1
            outputToFile $outputResults
        }
        JSON {
            $outputResults = $outputResults |
            ConvertTo-Json
            outputToFile $outputResults
        }
        CLI {
            $outputResults |
            Select-Object
        }
    }
}

function outputToFile($outputResults){
    if($SingleOutput){
        if([System.IO.File]::Exists($path)){
            $outputResults | Set-Content -Encoding UTF8 -Path ($OutputPath + $timestamp + "UsersInGroup." + ($OutputFormat.ToLower()))
        }else{
            $outputResults | Add-Content -Path ($OutputPath + $timestamp + "UsersInGroup." + ($OutputFormat.ToLower()))
        }
    }else{
        $outputResults | Set-Content -Encoding UTF8 -Path ($OutputPath + $group + "." + ($OutputFormat.ToLower()))
    }
}

ForEach($group in $Groups){

    $outputResults = New-Object System.Collections.ArrayList
    getGroupMembers $group $outputResults

    output $outputResults
}