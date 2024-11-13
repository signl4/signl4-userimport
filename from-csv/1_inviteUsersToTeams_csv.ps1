# Author: René Bormann
# THIS script (1_inviteUsersToTeams_csv.ps1) is 1 of 2 scripts which can be used for CSV based user and group (SIGNL4: teams) onboarding in SIGNL4.

# Desired user and team memberships are defined in a simple CSV file.
# If any users in the file are supposed to become member in multiple SIGNL4 teams, onboarding is 2 step process:

# STEP 1 is done with THIS SCRIPT, which invites the users into the SIGNL4 account to a first team.
# This results in an invitation link being sent to the user per email.
# IF ANY TEAMS OR USERS IN THE CSV FILE ALREADY EXIST, THEY ARE DELETED FIRST.
# This is to ensure that at the end the definition in the CSV file is applied 1:1 in the SIGNL4 account.
# After the user has clicked that invitation link and completed sign-up with either his new SIGNL4 identity (password selection) or simply by (re)using an existing 3rd party identity
# such as EntraID, Apple or Google, the second step is then to add the user to the remaining teams

# STEP 2 is done with the second script (2_addUsersToTeams_csv.ps1).
# It checks if each user was invited to the account and has completed his sign-up.
# If that is the case it is checked if the user is member in all teams as outlined in the CSV file.
# If not, the user is added to missing teams.
 
# [End User Experience]
# All invited users will get an invitation email with an access link that they need to click in order to activate their SIGNL4 account.
# When invited users click the invitation link, they can complete their sign-up by either creating a new SIGNL4 identity (selecting a password) or by (re)using an existing
# 3rd party identity such as EntraID, Apple or Google. NOTE that the number of options here depends on which identity providers are allowed by the SIGNL4 administrator.

# [Prerequisites]
# A SIGNL4 API key with write permission, not limited to a specific team scope.
# As SIGNL4 account administrator, you can create one in the SIGNL4 portal under Integrations. 


# Base URL for SIGNL4 API (don't change)
$baseUrl = "https://connect.signl4.com/api/v2"


################################
### Configure these settings ###
################################

# TODO: Configure path to CSV File containg users and teams to be added
$csvFilePath = "C:\users_teams.csv"

# TODO: Set your SIGNL4 API Key
$apiKey = "yourAPIKey"

# TODO: Set the email address of the inviter. This user must be an administrator and is typically the person who created the account or is administrating it.
$emailAddress = "signl4.admin@domain.com"

# To get the CSV applied 1:1 in the SIGNL4 account, all users and teams in the CSV file are first of all deleted from the account should they already exist
$deleteUsersAndTeams = $true

# You may adjust this depending on your SIGNL4 plan. If it is too low, you'll see 429 errors..
$apiThrottlingPreventionSleepMillis = 1000

################################
################################


# Function to retrieve a user by email address
function Get-UserIdByEmail {
    param (
        [string]$email,
        [bool]$isAdmin = $false  # Specifies if the role "00000000-0000-0000-0000-000000000000" should be checked
    )

    # Endpoint to retrieve the user overview
    $uri = "$baseUrl/users/overview"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    # JSON object for the request body with email filter
    $body = @{
        "contains" = $email
    } | ConvertTo-Json

    # POST request to retrieve the user overview
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"

    # Check if results are available
    if ($response.results) {
        foreach ($user in $response.results) {
            # If $isAdmin is true, check for the admin role
            if ($isAdmin) {
                if ($user.roleIds -contains "00000000-0000-0000-0000-000000000000") {
                    return $user.userId  # Return userId
                }
            } else {
                # If $isAdmin is not set, take the first result
                return $user.userId
            }
        }
    }

    # No matching user ID found
    return $null
}

# Retrieve inviter's user ID by email address and admin role
$inviterId = Get-UserIdByEmail -email $emailAddress -isAdmin $true

# Function to delete a user by user ID
function Delete-User {
    param (
        [string]$userId
    )

    # Endpoint to delete a user
    $uri = "$baseUrl/users/$userId"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    # DELETE request to delete the user
    Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers -ContentType "application/json"
}

# Function to retrieve all existing teams
function Get-ExistingTeams {
    # Endpoint to retrieve all existing teams
    $uri = "$baseUrl/teams"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    # GET request to retrieve the list of teams
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json"
    return $response
}

# Function to delete a team by team ID
function Delete-Team {
    param (
        [string]$teamId
    )

    # Endpoint to delete a team
    $uri = "$baseUrl/teams/$teamId"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    # DELETE request to delete the team
    Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers -ContentType "application/json"
}

# Function to create a team
function New-Signl4Team {
    param (
        [string]$teamName,
        [string]$timezone = "Europe/Berlin",
        [string]$language = "de"
    )

    # Endpoint to create a team
    $uri = "$baseUrl/teams/"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    # JSON object for the request body with required properties
    $body = @{
        "name" = $teamName
        "language" = $language
        "timezone" = $timezone
        "createWebhookEndpoint" = $false
        "createEmailEndpoint" = $false
    } | ConvertTo-Json

    # POST request to create the team and return the team ID
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"
    return $response.id
}

# Function to add users to a team
function Add-Signl4TeamMembers {
    param (
        [string]$teamId,
        [array]$members
    )

    # Endpoint to add users to a team
    $uri = "$baseUrl/teams/memberships?language=1"
    $headers = @{
        "X-S4-Api-Key" = $apiKey
    }

    # JSON object for the request body with required properties
    $body = @{
        "inviterId" = $inviterId
        "invites" = $members
        "teamId" = $teamId
    } | ConvertTo-Json

    # POST request to add users to the team
    Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"
}

# Role ID map
$roles = @{
    "GlobalAdmin" = "11111111-1111-1111-1111-111111111111"
    "Scheduler" = "22222222-2222-2222-2222-222222222222"
    "TeamAdmin" = "33333333-3333-3333-3333-333333333333"
    "User" = "44444444-4444-4444-4444-444444444444"
}

# Read CSV file
$userData = Import-Csv -Path $csvFilePath -Delimiter ";"


# Retrieve and log total number of distinct users
$distinctUserEmails = $userData | Select-Object -Unique user_email
$totalDistinctUsers = $distinctUserEmails.Count + 1 #Counts inviter as well
Write-Output ""
Write-Output "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
Write-Output "+++++ Confirm you have enough licenses in the SIGNL4 account. You need at least $totalDistinctUsers licenses, otherwise you'll see errors !!! +++++"
Write-Output "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
Write-Output ""
Read-Host -Prompt "Press Enter to continue"



# Check existing users and delete if necessary
foreach ($user in $userData) {
    $userEmail = $user.user_email    
    Write-Output "Checking user '$userEmail'.."
    Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis
    $existingUserId = Get-UserIdByEmail -email $userEmail -isAdmin $false
    if ($existingUserId) {

        $user | Add-Member -MemberType NoteProperty -Name id -Value $existingUserId

        if ($deleteUsersAndTeams -eq $true)
        {
            Write-Output "User with email $userEmail already exists. Deleting the user."
            Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis
            Delete-User -userId $existingUserId
        }
    }
}



# Retrieve existing teams and delete if necessary
$existingTeams = Get-ExistingTeams
if ($deleteUsersAndTeams -eq $true)
{
    foreach ($team in ($userData | Select-Object -Unique team_name)) {
        $teamName = $team.team_name
        $existingTeam = $existingTeams | Where-Object { $_.name -eq $teamName }
        if ($existingTeam) {
            Write-Output "Team '$teamName' already exists. Deleting the team."
            Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis
            Delete-Team -teamId $existingTeam.id
        }
    }

    Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis
    $existingTeams = Get-ExistingTeams
}


#exit


# Create teams and add users
$invitedUsers = @()
foreach ($team in ($userData | Select-Object -Unique team_name)) 
{
    $teamName = $team.team_name

    Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis

    $existingTeam = $existingTeams | Where-Object { $_.name -eq $teamName } | Select-Object -First 1
    $teamId = $existingTeam.id

    if ($teamId)
    {
        Write-Output "Team '$teamName' already exists in the account.."
    }
    else
    {
        Write-Output "Creating team '$teamName'.."
        # Create a new team
        $teamId = New-Signl4Team -teamName $teamName
    }


    # Assemble users for this team
    $members = @()
    foreach ($user in $userData | Where-Object { $_.team_name -eq $teamName }) 
    {
        $roleId = $roles[$user.user_role]
        $userEmail = $user.user_email

        # Check if the email is already in $invitedUsers
        if ($invitedUsers | Where-Object { $_.email -eq $user.user_email }) {
            continue
        }

        if ($user.id -and $existingTeam.memberIds -contains $user.id)
        {
            Write-Output "User '$userEmail' already exists in team '$teamName' and will be skipped.."
            continue
        }
    
        $members += [PSCustomObject]@{
            "email" = $user.user_email
            "roleId" = $roleId
        }
    
        $invitedUsers += [PSCustomObject]@{
            "email" = $user.user_email
            "roleId" = $roleId
        }
    }

    Start-Sleep -Milliseconds $apiThrottlingPreventionSleepMillis

    Write-Output "Adding users to team '$teamName'.."

    # Add members to the team
    Add-Signl4TeamMembers -teamId $teamId -members $members

    Write-Output "Team '$teamName' has been created and users have been added."
}
