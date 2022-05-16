### Initialize Global Variables
$computers = Get-ADComputer -Filter * | ForEach-Object {$_.Name} | Sort-Object
$session = $null

### Loop through all Domain Computers and set the Password Never Expires flag to False if possible for the desired account, create the account if it doesn't exist, 
### make sure the account is in the Administrators group, and disable the built-in local Administrator account if it's enabled
foreach ($computer in $computers) {
    Write-Host "`n$computer" -ForegroundColor Green
    if (Test-Connection -TargetName $computer -Count 1 -Quiet) {
        try {
            $session = New-PSSession -ComputerName $computer
        }
        catch {
            Write-Host "The computer cannot start a PowerShell Session!"
        }
        if ($null -ne $session) {
            ### Anything inside Invoke-Command's SciptBlock is locally run on the target machine so variables are only scoped inside it
            Invoke-Command -Session $session -ScriptBlock {
                $account = "YourAccountHere"
                $disableAccount = "Administrator"
                $group = "Administrators"
                $password = ConvertTo-SecureString "T3mp0r@ry123" -AsPlainText -Force ## This assumes you're using LAPS to manage the account you're creating, otherwise create a stronger password
                if ($null -eq (Get-LocalUser -Name $account)) {
                    New-LocalUser -Name $account -PasswordNeverExpires $false -Password $password
                    Add-LocalGroupMember -Group $group -Member $account
                    Write-Host "The account $account has been successfully created on this computer!"
                }
                elseif ($null -eq (Get-LocalGroupMember -Group $group -Member $account)) {
                    Add-LocalGroupMember -Group $group -Member $account
                    Write-Host "The account $account has been successfully added to the $group group on this computer!"
                }
                else {
                    Set-LocalUser -Name $account -PasswordNeverExpires $false
                    Write-Host "The account $account has successfully had it's PasswordNeverExpires flag set to false!"
                }
                if ($true -eq (Get-LocalUser -Name $disableAccount | ForEach-Object {$_.Enabled})) {
                    Set-LocalUser -Name $disableAccount -PasswordNeverExpires $false
                    Disable-LocalUser -Name $disableAccount
                    Write-Host "The account $disableAccount has been successfully disabled on this computer!"
                }
            }
            Remove-PSSession $session
        }
        $session = $null
    }
    else {
        Write-Host "The computer is currently offline!"
    }
}

### Let user know they've reached the end of the script
Write-Host "`nYou've reached the end of the script!"