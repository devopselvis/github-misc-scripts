# written in .net core powershell, so should run anywhere
param ([Parameter(Mandatory=$true)] $GitHubToken, [Parameter(Mandatory=$true)] $GitHubUserName, [Parameter(Mandatory=$true)] $BBToken, [Parameter(Mandatory=$true)] $BBUrl, [Parameter(Mandatory=$true)] $CSVFile )

# The following is an example command line
# pwsh bbs-to-github-basic-file-input.ps1 -GitHubToken TOKENHERE -GitHubUserName mickeygousset -BBToken TOKENHERE -BBUrl BBS-URL-HERE --CSVFile test.csv

###########
# Globals #
###########

$GITHUB_TOKEN="$GitHubToken"     # Github Personal Access token passed from user
$GITHUB_USERNAME = "$GitHubUserName"
$GITHUB_ORG=''
$GITHUB_REPO=''
$BITBUCKET_TOKEN="$BBToken"
$BITBUCKET_ORG=''
$BITBUCKET_REPO=''
$BITBUCKET_URL="$BBUrl"  # Name of BitBucket Url | Example: https://some-url.com
$BB_FULL_URL=''      # Full Url to BBS
$GITHUB_API='https://api.github.com' # API endpoint for GitHub
$CLONE_LOCATION=(New-Guid).Guid   # Need CLONE_LOCATION for random unique string
$CSV_FILE_TO_MIGRATE="$CSVFile"


################################################################################
#### Function CreateGitHubRequestHeaders ########################################
function CreateGitHubRequestHeaders([string]$username, [string]$token){
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$token)))
  $headers = @{Authorization="Basic $base64AuthInfo"}
  return $headers
}

################################################################################
#### Function GetRestfulErrorResponse ##########################################
function GetRestfulErrorResponse($exception) {
  $ret = ""
  if($exception.Exception -and $exception.Exception.Response){
      $result = $exception.Exception.Response.GetResponseStream()
      $reader = New-Object System.IO.StreamReader($result)
      $reader.BaseStream.Position = 0
      $reader.DiscardBufferedData()
      $ret = $reader.ReadToEnd()
      $reader.Close()
  }
  if($ret -eq $null -or $ret.Trim() -eq ""){
      $ret = $exception.ToString()
  }
  return $ret
}

################################################################################
#### Function Header ###########################################################
Function Header() {
  Write-Output "-------------------------------------------------------------------"
  Write-Output "----- Migrate mirror repository from BitBucket to GitHub.com ------"
  Write-Output "-------------------------------------------------------------------"
}

#### Function CloneRepo ########################################################
Function CloneRepo() {
  $Error.Clear()

  ####################
  # Set the full URL #
  ####################
  $BB_FULL_URL="$BITBUCKET_URL/$BITBUCKET_ORG/$BITBUCKET_REPO"

  ###################
  # Print the goods #
  ###################
  Write-Output "-------------------------------------------------------"
  Write-Output "Clone of repository:[$BB_FULL_URL] to local machine..."

  ###################
  # Make a temp dir #
  ###################
  $folderName = "/tmp/$CLONE_LOCATION"
  
  if (!(Test-Path $folderName))
  {
    New-Item -ItemType Directory -Path $folderName
  }
  else
  {
    Write-Output "ERROR! Failed to create temp dir:[$folderName] for clone!"
    Write-Output "The folder either already exists, or location is not accessible"
    exit 1
  }

  #############################################
  # Clone the repository to the local machine #
  #############################################
  Set-Location "$folderName"; 
  git -c "http.extraHeader=Authorization: Bearer $BITBUCKET_TOKEN" clone --mirror "$BITBUCKET_URL/scm/$BITBUCKET_ORG/$BITBUCKET_REPO.git" 
  
  ##########################
  # Check for errors #
  ##########################
  if ( $LASTEXITCODE -ne 0 ) 
  {
    # Error
    Write-Output "ERROR! Failed to Clone repository:[/$BITBUCKET_URL/scm/$BITBUCKET_ORG/$BITBUCKET_REPO.git]!"
    Write-Output "Please verify the URL is reachable, and update variables as needed..."
    CleanUp
    exit 1
  else
    # Success
    Write-Output "Successfuly cloned repository:[$BITBUCKET_ORG/$BITBUCKET_REPO]"
  }
}
  
################################################################################
#### Function CreateEmptyRepo ##################################################
Function CreateEmptyRepo() {
  Write-Output "-------------------------------------------------------"
  Write-Output "Creating Repository:[$GITHUB_ORG/$GITHUB_REPO] on GitHub..."
  $Error.Clear()

  #########################
  # Create the repository #
  #########################
  $headers = CreateGitHubRequestHeaders -username $GITHUB_USERNAME -token $GITHUB_TOKEN

  $url = "$GITHUB_API/orgs/$GITHUB_ORG/repos"

  $body = @{
        # whatever required by the endpoint
        name = "$GITHUB_REPO"
        visibility = "private"        
    } | ConvertTo-Json
  Try{
    $cmd = Invoke-RestMethod -Method Post `
            -Uri $url `
            -Headers $headers `
            -Body $body # for POST and PUT 
    Write-Output "Successfully created repository:[$GITHUB_ORG/$GITHUB_REPO]"
  } Catch {
    #$resp = (GetRestfulErrorResponse $_)
    $resp = $_
    Write-Error $resp
    Write-Output "ERROR! Failed to create repository:[$GITHUB_ORG/$GITHUB_REPO]"
    CleanUp
    exit 1
  }  

}

################################################################################
#### Function PushRepo #########################################################
Function PushRepo() {
  Write-Output "-------------------------------------------------------"
  Write-Output "Pushing mirror to GitHub..."
  $Error.Clear()
  ############################
  # Set the mirror to GitHub #
  ############################q
  Set-Location "/tmp/$CLONE_LOCATION/$BITBUCKET_REPO.git"
  git remote set-url origin "https://$GITHUB_TOKEN@github.com/$GITHUB_ORG/$GITHUB_REPO.git"

  ##########################
  # Check shell for errors #
  ##########################
  if ( $LASTEXITCODE -ne 0 ) 
  {
    # ERROR
    Write-Output "ERROR! Failed to set remote for repository:[$GITHUB_ORG/$GITHUB_REPO]"
    CleanUp
    exit 1
  }

  #############################
  # Push the mirror to GitHub #
  #############################
  Set-Location "/tmp/$CLONE_LOCATION/$BITBUCKET_REPO.git"
  git push --mirror

  ##########################
  # Check shell for errors #
  ##########################
  if ( $LASTEXITCODE -ne 0 )
  {
    # ERROR
    Write-Output "ERROR! Failed to push mirror to repository:[$GITHUB_ORG/$GITHUB_REPO]"
    exit 1
  else
    # Success
    Write-Output ""
    Write-Output "-------------------------------------------------------"
    Write-Output "Successfully Pushed mirror to:[https://github.com/$GITHUB_ORG/$GITHUB_REPO]"
  }
}

################################################################################
#### Function CleanUp ##########################################################
Function CleanUp() {
  Write-Output "-------------------------------------------------------"
  Write-Output "Clean up of local env..."

  Set-Location "/tmp"

  ##################
  # Remove tmp dir #
  ##################
  Remove-Item -Path "/tmp/$CLONE_LOCATION" -Force -Recurse
  
}

################################################################################
#### Function Footer ###########################################################
Function Footer() {
  Write-Output "-------------------------------------------------------"
  Write-Output "Migration complete"
  Write-Output "-------------------------------------------------------"
}

Import-CSV $CSV_FILE_TO_MIGRATE -Header GitHubOrg,GitHubRepo,BBOrg,BBRepo | Foreach-Object{

  $GITHUB_ORG=$_.GitHubOrg
  $GITHUB_REPO=$_.GitHubRepo
  $BITBUCKET_ORG=$_.BBOrg
  $BITBUCKET_REPO=$_.BBRepo



  ##########
  # Header #
  ##########
  Header

  #############################
  # Clone Repo from BitBucket #
  #############################
  CloneRepo

  ############################
  # Create Empty GitHub repo #
  ############################
  CreateEmptyRepo

  #######################
  # Push Repo to GitHub #
  #######################
  PushRepo

  ############
  # Clean up #
  ############
  CleanUp

  ##########
  # Footer #
  ##########
  Footer

}
