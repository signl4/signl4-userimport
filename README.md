# Repository Description

This repository helps to import users into SIGNL4 using different formats or approaches, providing administrators with tools to streamline user and team onboarding. One primary method involves CSV-based user and team import, detailed in the following chapter. This approach allows administrators to efficiently manage bulk invitations and team assignments based on simple CSV configurations.

## CSV-Based User Import for SIGNL4

The `csv` folder within this repository contains three essential files to facilitate CSV-based user and team onboarding in SIGNL4. This approach allows administrators to manage bulk user invitations and team assignments using simple CSV configurations, streamlining the onboarding process.

### Files in the `csv` Folder

1. **User and Team CSV File**  
   - This file defines the desired users and their team memberships within SIGNL4. Each row should contain a user's email address and the team(s) to which they should belong.
   - **Configuration**: Before proceeding with the import process, open this file and adjust it to reflect the actual users and teams for your SIGNL4 account. Ensure that each user and team entry aligns with your organizational structure.

2. **Script 1 - `1_inviteUsersToTeams_csv.ps1`**  
   - This PowerShell script reads the user and team data from the CSV file and initiates the invitation process by assigning each user to their initial team within SIGNL4. It sends an email invitation link to each user listed.
   - If any users or teams in the CSV already exist in SIGNL4, they will be deleted first, ensuring that the CSV file contents are accurately reflected in SIGNL4.

3. **Script 2 - `2_addUsersToTeams_csv.ps1`**  
   - This PowerShell script completes the onboarding by verifying each user’s team memberships against the CSV file after they have accepted their initial invitation.
   - Users who are missing team assignments as specified in the CSV file are added to the appropriate teams to finalize their onboarding.

### CSV-Based Onboarding Workflow

1. **Step 0: Configure the CSV File**  
   - Begin by customizing the CSV file included in the `csv` folder to reflect your desired user and team configurations. Ensure accurate email addresses for each user and specify the appropriate teams as per your SIGNL4 account’s structure.

2. **Step 1: Run `1_inviteUsersToTeams_csv.ps1`**  
   - This script reads the CSV file and invites each user to a designated team in SIGNL4. An invitation email is sent to each user.
   - If any users or teams listed in the CSV file already exist in SIGNL4, they are deleted first to match the CSV configuration exactly.
   - Users receive an invitation link via email, enabling them to complete their sign-up either by creating a new SIGNL4 identity or by using an existing third-party identity provider such as EntraID, Apple, or Google.

3. **Step 2: Run `2_addUsersToTeams_csv.ps1`**  
   - After users have completed their sign-up, this script verifies that each user is assigned to all teams specified in the CSV.
   - Users missing team memberships are automatically added to the relevant teams, completing the onboarding process.

### User Experience

Each user invited through this process will receive an email invitation to activate their SIGNL4 account. Upon clicking the link, users can sign up by creating a new SIGNL4 account or using a supported third-party identity provider, depending on the options configured by the SIGNL4 administrator.

### Prerequisites

- **SIGNL4 API Key**: An API key with write permissions, not limited to a specific team scope, is required. SIGNL4 account administrators can create this key within the SIGNL4 portal under "Integrations."

By following these steps, SIGNL4 administrators can efficiently onboard users and assign them to teams according to the CSV file configuration. This approach ensures consistency and simplicity in managing bulk user and team onboarding.
