#!/bin/bash

# Identify the repository that triggered the build
TRIGGERED_REPO=${bamboo.repository.triggered}

# Retrieve the branch for the triggered repository
TRIGGERED_BRANCH_VAR="bamboo.repository.${TRIGGERED_REPO}.branch"
TRIGGERED_BRANCH=$(eval echo \$$TRIGGERED_BRANCH_VAR)

# Debugging output
echo "Triggered repository: $TRIGGERED_REPO"
echo "Triggered branch: $TRIGGERED_BRANCH"

# Set Bamboo plan-level variables
echo "##teamcity[setParameter name='bamboo.triggered.repo' value='$TRIGGERED_REPO']"
echo "##teamcity[setParameter name='bamboo.triggered.branch' value='$TRIGGERED_BRANCH']"
