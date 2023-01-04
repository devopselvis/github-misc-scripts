#!/bin/bash

################################################################################
################################################################################
####### Migrate Teams, Users and Permissions ###################################
################################################################################
################################################################################
#
# TODO: Fill Out This Section
# TODO: Add user mapping portion
# TODO: What if the team already exists in the destination org?
#
# This script will borrow code from:
#
# https://github.com/mona-actions/gh-migrate-team-permission/blob/master/gh-migrate-team-permission
#
# PREREQS:
# You need to have the following to run this script successfully:
# - You have ownership/admin permissions in the destination GitHub GHES/GHEC where you want to migrate to
# - You have ownership/admin permission in the source GitHub GHEC/EMU where you can migrate from
# - You need to create a GitHub Personal Access Token with all repo permission admin:org permission in your source URL and authenticate for the source organization if the org is behind SAML/SSO
# - You need to create a GitHub Personal Access Token with all repo permission admin:org permission in your destination URL and authenticate for the destionation organization if the org is behind SAML/SSO
# - Repos in the source and destination orgs have the same name
#
# General Psuedo Code:
#
# 1. Read in the list of repos from the source org that have been migrated. This is info
#    in a CSV File, because we will be rate limited if we do ALL repos at once.
# 2. For each repo in the list of migrated repos:
#   2.1. Get the list of teams that have access to the repo
#   2.2. Get the permissions for each team
# 3. Create the new teams in the destination org
# 4. Assign permissions to the new teams to the appropriate repo

set -e

# TODO: Change this to variables that are passed in
REPOS_FILE="repos.txt"
SOURCE_ORG="mickey-migration-from"
DEST_ORG="mickey-migration-to"
SOURCE_PAT=""
DEST_PAT=""
SOURCE_HEADERS=(-H "Accept: application/vnd.github.v3+json" -H "Authorization: token $SOURCE_PAT")
DEST_HEADERS=(-H "Accept: application/vnd.github.v3+json" -H "Authorization: token $DEST_PAT")

# 1. Read in the list of repos from the source org that have been migrated.

sed -i 's/\r//' $REPOS_FILE
mapfile REPOS < $REPOS_FILE
echo "Loaded ${#REPOS[@]} Repos"
echo "${REPOS[@]}"
