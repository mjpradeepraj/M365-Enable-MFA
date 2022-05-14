Write-Host "Finding Azure Active Directory Accounts..."
$rundate =(Get-Date).tostring("dd_MMMM_yyyy_hh_m_tt")
try {
    $Users = Get-MsolUser -All -ErrorAction stop | ? { $_.UserType -ne "Guest" }
} catch {
    If ($($PSItem.ToString()) -eq "You must call the Connect-MsolService cmdlet before calling any other cmdlets." ){
        Write-Host "Microsoft 365 Account not connected."
        try {
            Write-Host "Connecting M365 Now....."
            Connect-MsolService -ErrorAction stop
            Write-Host "Successfully connected to M365!"
            $Users = Get-MsolUser -All -ErrorAction stop | ? { $_.UserType -ne "Guest" }
        } catch{
            Write-Host " Error in connecting to M365: $($PSItem.ToString())"
            Write-Host " exiting..!"
            Read-Host -Prompt "Press any key to exit"
            exit 
        }
            } Else {
                If ($($PSItem.ToString()) -like '*Authentication Error*'){
                    write-host "$($PSItem.ToString())"
                    write-host "Try Again..!"
                    Read-Host -Prompt "Press any key to exit"
                    exit
                    
                }Else{
                    Write-Host "Unknown Error: $($PSItem.ToString())"
                    Read-Host -Prompt "Press any key to exit"
                    exit
                }
                
              
             
    }
}

$mf= New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
$mf.RelyingParty = "*"
$mfa = @($mf)
$Report = [System.Collections.Generic.List[Object]]::new()
$title    = 'Warning..!Confirmation to Enable MFA..!'
$choices  = '&Yes', '&No'




Write-Host "Processing" $Users.Count "accounts..." 
Write-Host "";
ForEach ($User in $Users) {
    $MFAEnforced = $User.StrongAuthenticationRequirements.State
    $MFAPhone = $User.StrongAuthenticationUserDetails.PhoneNumber
    $DefaultMFAMethod = ($User.StrongAuthenticationMethods | ? { $_.IsDefault -eq "True" }).MethodType
    If (($MFAEnforced -eq "Enforced") -or ($MFAEnforced -eq "Enabled")) {
        Switch ($DefaultMFAMethod) {
            "OneWaySMS" { $MethodUsed = "One-way SMS" }
            "TwoWayVoiceMobile" { $MethodUsed = "Phone call verification" }
            "PhoneAppOTP" { $MethodUsed = "Hardware token or authenticator app" }
            "PhoneAppNotification" { $MethodUsed = "Authenticator app" }
        }
    }
    Else {
        $MFAEnforced = "Not Enabled"
        $MethodUsed = "MFA Not Used"
        $ReportLine = [PSCustomObject] @{
            UserPrincipalName        = $User.UserPrincipalName
            Name        = $User.DisplayName
            MFAUsed     = $MFAEnforced
            MFAMethod   = $MethodUsed 
            PhoneNumber = $MFAPhone
        }
                 
        $Report.Add($ReportLine)
        Write-host "User:" $User.UserPrincipalName "      MFA Status:" $MFAEnforced
        
    }
    
}


If ($Report.Count -eq 0){
    write-host "All" $Users.Count "users have MFA Enabled..! exiting..!" 
    Read-Host -Prompt "Press any key to exit"
    exit
    
} else {
    $question = 'Are you sure you want to enable MFA for the above '+ $Report.Count +' users?'
    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0) {
        Write-Host 'confirmed'
        $Report | select UserPrincipalName | Set-MsolUser -StrongAuthenticationRequirements $mfa;
        Write-Host '';
        Write-Host 'Successfully enabled MFA for the listed users..!'
        Read-Host -Prompt "Press any key to exit"
        exit
    } else {
        Write-Host '';
        Write-Host 'Cancelled. Bye..!'
        Read-Host -Prompt "Press any key to exit"
        exit
           }
}
