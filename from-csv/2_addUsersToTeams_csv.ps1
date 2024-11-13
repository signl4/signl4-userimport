# Author: René Bormann
# THIS script (2_addUsersToTeams_csv.ps1) is 2 of 2 scripts which can be used for CSV based user and group (SIGNL4: teams) onboarding in SIGNL4.

# Desired user and team memberships are defined in a simple CSV file.
# If any users in the file are supposed to become member in multiple SIGNL4 teams, onboarding is 2 step process:

# STEP 1 is done with the first script (1_inviteUsersToTeams_csv.ps1) which invites the users into the SIGNL4 account to a first team.
# This results in an invitation link being sent to the user per email.
# IF ANY TEAMS OR USERS IN THE CSV FILE ALREADY EXIST, THEY ARE DELETED FIRST.
# This is to ensure that at the end the definition in the CSV file is applied 1:1 in the SIGNL4 account.
# After the user has clicked that invitation link and completed sign-up with either his new SIGNL4 identity (password selection) or simply by (re)using an existing 3rd party identity
# such as EntraID, Apple or Google, the second step is then to add the user to the remaining teams

# STEP 2 is done with THIS SCRIPT.
# It checks if each user was invited to the account and has completed his sign-up.
# If that is the case it is checked if the user is member in all teams as outlined in the CSV file.
# If not, the user is added to missing teams.
 
# [End User Experience]
# All invited users will get an invitation email with an access link that they need to click to activate their SIGNL4 account.
# When invited users click the invitation link, they can complete their sign-up by either creating a new SIGNL4 identity (selecting a password) or by (re)using an existing
# 3rd party identity such as EntraID, Apple or Google. NOTE that the number of options here depends on which identity providers are allowed by the SIGNL4 administrator.

# [Prerequisites]
# A SIGNL4 API key with write permission, not limited to a specific team scope.
# As SIGNL4 account administrator, you can create one in the SIGNL4 portal under Integrations. 

# Base URL for SIGNL4 API (do not change)
$baseUrl = "https://connect.signl4.com/api/v2"



################################
### Configure these settings ###
################################

# TODO: Configure path to CSV File containg users and teams to be added
$csvFilePath = "C:\users_teams.csv"

# TODO: Set your SIGNL4 API Key
$apiKey = "yourAPIKey"

# You may adjust this depending on your SIGNL4 plan. If it is too low, you'll see 429 errors..
$apiThrottlingPreventionSleepMillis = 1000

################################
################################


# Function to retrieve a user by email address
function Get-UserIdByEmail {
    param (
        [string]$email,
        [bool]$isAdmin = $false
    )

    $uri = "$baseUrl/users/overview"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    $body = @{
        "contains" = $email
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"

    if ($response.results) {
        foreach ($user in $response.results) {
            if ($isAdmin) {
                if ($user.roleIds -contains "00000000-0000-0000-0000-000000000000") {
                    return $user
                }
            } else {
                return $user
            }
        }
    }
    return $null
}

# Function to delete a user by user ID
function Delete-User {
    param (
        [string]$userId
    )

    $uri = "$baseUrl/users/$userId"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers -ContentType "application/json"
}

# Function to retrieve all existing teams
function Get-ExistingTeams {
    $uri = "$baseUrl/teams"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json"
    return $response
}

# Function to delete a team by team ID
function Delete-Team {
    param (
        [string]$teamId
    )

    $uri = "$baseUrl/teams/$teamId"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers -ContentType "application/json"
}



# Function to check if a user is already a member of a team
function Is-UserInTeam {
    param (
        [string]$userId,
        [string]$teamId
    )

    $userDetails = Get-UserDetailsById -userId $userId
    return $userDetails.teamIds -contains $teamId
}

# Function to retrieve user details by user ID (includes team membership information)
function Get-UserDetailsById {
    param (
        [string]$userId
    )

    $uri = "$baseUrl/users/overview/$userId"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    return $response
}

# Function to add a user to a team by team ID
function Add-UserToTeam {
    param (
        [string]$teamId,
        [string]$userId,
        [string]$roleId
    )

    $uri = "$baseUrl/teams/$teamId/memberships/$userId"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    $body = @{
        "roleId" = $roleId
        "setUserOnDuty" = $true
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"
}

# Read CSV file
$userData = Import-Csv -Path $csvFilePath -Delimiter ";"

Write-Output "Loading all existing Tteams.."
Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis

# Retrieve all existing teams to get their IDs
$existingTeams = Get-ExistingTeams



$usersNotInvited = @()
$usersNotActivated = @()

# Loop through each user in the CSV
foreach ($user in $userData) {
    $userEmail = $user.user_email
    $teamName = $user.team_name
    $roleId = $roles[$user.user_role]

    Write-Output "Loading user '$userEmail'.."
    Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis


    if ($usersNotInvited -contains $userEmail)
    {
        Write-Output "User '$userEmail' does not exist. Please ensure the user has been invited."
        continue
    }
    if ($usersNotActivated -contains $userEmail)
    {
        Write-Output "User '$userEmail' has not yet clicked the invitation link and completed his sign-up."
        continue
    }


    # Retrieve or create the user ID    
    $user = Get-UserIdByEmail -email $userEmail
    if (-not $user) {
        Write-Output "User '$userEmail' does not exist. Please ensure the user has been invited."
        $usersNotInvited += $userEmail
        continue
    }
    if ($user.provStatus -eq 1) {
        Write-Output "User '$userEmail' has not yet clicked the invitation link and completed his sign-up."
        $usersNotActivated += $userEmail
        continue
    }
    
    $userId = $user.userId

    # Retrieve the team ID for the specified team name
    $teamId = ($existingTeams | Where-Object { $_.name -eq $teamName }).id
    if (-not $teamId)
    {
        Write-Output "Team '$teamName' does not exist. Please ensure the team is created first."
        continue
    }

    # Check if the user is already in the team; if not, add them
    if (-not (Is-UserInTeam -userId $userId -teamId $teamId)) 
    {
        Write-Output "Adding user '$userEmail' to team '$teamName'.."
        Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis
        Add-UserToTeam -teamId $teamId -userId $userId -roleId $roleId
        Write-Output "User '$userEmail' has been added to team '$teamName'."
    } 
    else 
    {
        Write-Output "User '$userEmail' is already a member of team '$teamName'."
    }
}

if ($usersNotInvited.Count -gt 0)
{
    Write-Output ""
    Write-Output ""
    Write-Output "Users who have not been invited so far:"
    Write-Output $usersNotInvited
    Write-Output ""
    Write-Output ""
}

if ($usersNotActivated.Count -gt 0)
{
    Write-Output ""
    Write-Output ""
    Write-Output "Following users have still not yet accepted the invitation sent per email:"
    Write-Output $usersNotActivated
    Write-Output ""
    Write-Output ""
}