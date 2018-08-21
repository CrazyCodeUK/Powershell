$credential = Get-Credential
Test-ComputerSecureChannel -Server ad.kent.ac.uk -Credential $credential -Repair -Verbose