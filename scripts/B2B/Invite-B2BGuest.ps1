#Requires -Modules Microsoft.Graph.Users

<#
.SYNOPSIS
    Invites guest users to collaborate via B2B.

.DESCRIPTION
    Invites external users as guest users to access your organization's resources.
    Supports individual invitations and bulk invitation via CSV.

.PARAMETER Email
    Email address of the guest user to invite.

.PARAMETER DisplayName
    Display name for the guest user.

.PARAMETER RedirectUrl
    URL to redirect after invitation redemption.

.PARAMETER Groups
    Array of group IDs or names to add the guest to.

.PARAMETER Roles
    Array of directory role IDs to assign to the guest.

.PARAMETER SendInvitation
    Whether to send invitation email (default: true).

.PARAMETER InvitedByMessage
    Custom message to include in invitation email.

.PARAMETER BulkFile
    CSV file containing guest information (Email, DisplayName, Groups).

.PARAMETER ListOnly
    Only list existing guest users, don't invite new ones.

.EXAMPLE
    .\Invite-B2BGuest.ps1 -Email "partner@example.com" -DisplayName "John Doe"
    Invites a single guest user.

.EXAMPLE
    .\Invite-B2BGuest.ps1 -BulkFile "guests.csv"
    Invites multiple guests from CSV file.
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Single", Mandatory = $true)]
    [string]$Email,

    [Parameter(ParameterSetName = "Single")]
    [string]$DisplayName,

    [Parameter(ParameterSetName = "Single")]
    [string]$RedirectUrl = "https://myapps.microsoft.com",

    [Parameter(ParameterSetName = "Single")]
    [string[]]$Groups = @(),

    [Parameter(ParameterSetName = "Single")]
    [string[]]$Roles = @(),

    [Parameter(ParameterSetName = "Single")]
    [bool]$SendInvitation = $true,

    [Parameter(ParameterSetName = "Single")]
    [string]$InvitedByMessage,

    [Parameter(ParameterSetName = "Bulk", Mandatory = $true)]
    [string]$BulkFile,

    [Parameter(ParameterSetName = "List")]
    [switch]$ListOnly
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  B2B Guest Invitation" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Verify connection
$context = Get-MgContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Error "Not connected. Run .\Connect-EntraB2B.ps1 first."
    return
}

$TenantId = $context.TenantId
Write-Host "Current Tenant: $TenantId" -ForegroundColor Yellow
Write-Host ""

function Invite-B2BGuestUser {
    param(
        [string]$GuestEmail,
        [string]$GuestDisplayName,
        [string]$Redirect,
        [string[]]$GroupIds,
        [string[]]$RoleIds,
        [bool]$SendMail,
        [string]$CustomMessage
    )

    Write-Host "Inviting guest: $GuestEmail" -ForegroundColor Yellow

    # Check if user already exists
    $existingUser = Get-MgUser -All -Filter "mail eq '$GuestEmail'" -ErrorAction SilentlyContinue

    if ($existingUser) {
        Write-Host "  User already exists: $($existingUser.UserPrincipalName)" -ForegroundColor Green
        Write-Host "  User Type: $($existingUser.UserType)" -ForegroundColor Gray
        
        if ($existingUser.UserType -eq "Guest") {
            Write-Host "  User is already a guest" -ForegroundColor Yellow
            return $existingUser
        }
        else {
            Write-Warning "  User exists as member - cannot re-invite"
            return $null
        }
    }

    # Build invitation parameters
    $params = @{
        InvitedUserEmailAddress = $GuestEmail
        SendInvitationMessage = $SendMail
        InviteRedirectUrl = $Redirect
    }

    if ($GuestDisplayName) {
        $params.InvitedUserDisplayName = $GuestDisplayName
    }

    if ($CustomMessage) {
        $params.InvitedUserMessageInfo = @{
            CustomizedMessageBody = $CustomMessage
        }
    }

    try {
        Write-Host "  Sending invitation..." -ForegroundColor Gray
        $invitation = New-MgUserInvitation -BodyParameter $params -ErrorAction Stop

        Write-Host "  Invitation sent successfully!" -ForegroundColor Green
        Write-Host "  Invitation ID: $($invitation.Id)" -ForegroundColor Gray
        
        if ($SendMail) {
            Write-Host "  Guest will receive invitation email" -ForegroundColor Gray
        }

        # Add to groups
        if ($GroupIds -and $GroupIds.Count -gt 0) {
            Write-Host "  Adding to groups..." -ForegroundColor Gray
            Start-Sleep -Seconds 2  # Wait for user to be created
            
            foreach ($groupId in $GroupIds) {
                try {
                    $group = Get-MgGroup -GroupId $groupId -ErrorAction SilentlyContinue
                    if ($group) {
                        New-MgGroupMember -GroupId $groupId -DirectoryObjectId $invitation.InvitedUser.Id -ErrorAction SilentlyContinue
                        Write-Host "    Added to: $($group.DisplayName)" -ForegroundColor Gray
                    }
                }
                catch {
                    Write-Warning "    Could not add to group: $groupId"
                }
            }
        }

        # Assign roles
        if ($RoleIds -and $RoleIds.Count -gt 0) {
            Write-Host "  Assigning roles..." -ForegroundColor Gray
            foreach ($roleId in $RoleIds) {
                try {
                    $role = Get-MgDirectoryRole -DirectoryRoleId $roleId -ErrorAction SilentlyContinue
                    if ($role) {
                        New-MgDirectoryRoleMemberByRef -DirectoryRoleId $roleId -BodyParameter @{
                            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($invitation.InvitedUser.Id)"
                        } -ErrorAction SilentlyContinue
                        Write-Host "    Role: $($role.DisplayName)" -ForegroundColor Gray
                    }
                }
                catch {
                    Write-Warning "    Could not assign role: $roleId"
                }
            }
        }

        return $invitation
    }
    catch {
        Write-Error "  Failed to send invitation: $_"
        return $null
    }
}

function Get-B2BGuestUsers {
    Write-Host "Listing all guest users..." -ForegroundColor Yellow

    try {
        $guests = Get-MgUser -All -Filter "userType eq 'Guest'" -Property "id,displayName,mail,userPrincipalName,invitedBy,userType,createdDateTime"

        if ($guests) {
            Write-Host ""
            Write-Host "Found $($guests.Count) guest users:" -ForegroundColor Green
            Write-Host ""
            
            $guests | Format-Table DisplayName, Mail, UserPrincipalName, CreatedDateTime -AutoSize
            
            return $guests
        }
        else {
            Write-Host "No guest users found." -ForegroundColor Yellow
            return @()
        }
    }
    catch {
        Write-Error "Failed to list guests: $_"
        return $null
    }
}

function Import-B2BGuestsFromCsv {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }

    Write-Host "Reading CSV file: $FilePath" -ForegroundColor Yellow
    
    $guests = Import-Csv -Path $FilePath

    Write-Host "Found $($guests.Count) guests to invite" -ForegroundColor Cyan
    Write-Host ""

    $results = @()

    foreach ($guest in $guests) {
        $email = $guest.Email
        $name = $guest.DisplayName
        $groups = if ($guest.Groups) { $guest.Groups -split ";" } else { @() }
        
        Write-Host "Processing: $email" -ForegroundColor Yellow

        $result = Invite-B2BGuestUser -GuestEmail $email -GuestDisplayName $name -GroupIds $groups
        
        if ($result) {
            $results += @{
                Email = $email
                Status = "Success"
                InvitationId = $result.Id
            }
        }
        else {
            $results += @{
                Email = $email
                Status = "Failed"
                InvitationId = $null
            }
        }

        Write-Host ""
        Start-Sleep -Milliseconds 500  # Rate limiting
    }

    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  Summary" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    
    $success = ($results | Where-Object { $_.Status -eq "Success" }).Count
    $failed = ($results | Where-Object { $_.Status -eq "Failed" }).Count
    
    Write-Host "  Total: $($results.Count)" -ForegroundColor White
    Write-Host "  Success: $success" -ForegroundColor Green
    Write-Host "  Failed: $failed" -ForegroundColor Red

    return $results
}

# Execute based on parameter set
switch ($PSCmdlet.ParameterSetName) {
    "List" {
        Get-B2BGuestUsers
    }
    "Single" {
        Invite-B2BGuestUser -GuestEmail $Email `
            -GuestDisplayName $DisplayName `
            -Redirect $RedirectUrl `
            -GroupIds $Groups `
            -RoleIds $Roles `
            -SendMail $SendInvitation `
            -CustomMessage $InvitedByMessage
    }
    "Bulk" {
        Import-B2BGuestsFromCsv -FilePath $BulkFile
    }
}

<#
.SYNOPSIS
    Lists available directory roles for assignment.
#>
function Get-B2BAvailableRoles {
    try {
        $roles = Get-MgDirectoryRole -All
        Write-Host "Available directory roles:" -ForegroundColor Cyan
        $roles | Format-Table DisplayName, Description, Id -AutoSize
        return $roles
    }
    catch {
        Write-Error "Failed to get roles: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Removes a guest user.
#>
function Remove-B2BGuest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Email
    )

    try {
        $user = Get-MgUser -All -Filter "mail eq '$Email' and userType eq 'Guest'" -ErrorAction SilentlyContinue
        
        if ($user) {
            Write-Host "Removing guest: $($user.DisplayName)" -ForegroundColor Yellow
            Remove-MgUser -UserId $user.Id -ErrorAction Stop
            Write-Host "Guest removed successfully!" -ForegroundColor Green
        }
        else {
            Write-Warning "Guest not found: $Email"
        }
    }
    catch {
        Write-Error "Failed to remove guest: $_"
    }
}

Export-ModuleMember -Function @('Get-B2BAvailableRoles', 'Remove-B2BGuest')
