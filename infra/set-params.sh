#!/bin/bash

# get the current release commit id
commit_id=$(git rev-parse --short $GITHUB_SHA)
echo "Commit ID: $commit_id"

# set the commit id as a task variable
echo "commit_id=$commit_id" >> $GITHUB_OUTPUT

# get the current tags
tags=$(az containerapp show -g $RESOURCE_GROUP -n $APP_NAME --query tags -o json | tr -d '\r\n')

# get the current production label
cur_prod_label=$(echo $tags | jq -r '.productionLabel')
echo "Current Production Label: $cur_prod_label"
echo "cur_prod_label=$cur_prod_label" >> $GITHUB_OUTPUT

# get the current blue commit id
cur_blue_commit_id=$(echo $tags | jq -r '.blueCommitId')
echo "Current Blue Commit ID: $cur_blue_commit_id"

# get the current green commit id
cur_green_commit_id=$(echo $tags | jq -r '.greenCommitId')
echo "Current Green Commit ID: $cur_green_commit_id"

# Handle the case when the workflow is re-run for the same commit id that is already in production
# We do not want to deploy the same commit id again into another label
if [ $cur_prod_label = 'blue' ] && [ $cur_blue_commit_id = $commit_id ];
then
    echo "Blue is a production label and the current commit id is the same as the blue commit id"
    echo "cur_prod_label=blue" >> $GITHUB_OUTPUT
    echo "new_prod_label=blue" >> $GITHUB_OUTPUT
    echo "blue_commit_id=$cur_blue_commit_id" >> $GITHUB_OUTPUT
    echo "green_commit_id=$cur_green_commit_id" >> $GITHUB_OUTPUT
    echo "revision_to_deactivate=NONE" >> $GITHUB_OUTPUT
    exit 0
fi

if [ $cur_prod_label = 'green' ] && [ $cur_green_commit_id = $commit_id ];
then
    echo "Green is a production label and the current commit id is the same as the green commit id"
    echo "cur_prod_label=green" >> $GITHUB_OUTPUT
    echo "new_prod_label=green" >> $GITHUB_OUTPUT
    echo "blue_commit_id=$cur_blue_commit_id" >> $GITHUB_OUTPUT
    echo "green_commit_id=$cur_green_commit_id" >> $GITHUB_OUTPUT
    echo "revision_to_deactivate=NONE" >> $GITHUB_OUTPUT
    exit 0
fi

# set blue commit id and green commit id based on the current production label
blue_commit_id=$([[ $cur_prod_label = 'blue' ]] && echo $cur_blue_commit_id || echo $commit_id)
echo "New blue Commit ID: $blue_commit_id"
echo "blue_commit_id=$blue_commit_id" >> $GITHUB_OUTPUT

green_commit_id=$([[ $cur_prod_label = 'green' ]] && echo $cur_green_commit_id || echo $commit_id)
echo "New green Commit ID: $green_commit_id"
echo "green_commit_id=$green_commit_id" >> $GITHUB_OUTPUT

# determine the name of the revision to deactivate after successful deployment
revision_to_deactivate=$([[ $cur_prod_label = 'blue' ]] && echo $APP_NAME--$cur_green_commit_id || echo $APP_NAME--$cur_blue_commit_id)
revision_to_deactivate=$([[ $revision_to_deactivate = $APP_NAME-- ]] && echo 'NONE' || echo $revision_to_deactivate)
echo "Revision to deactivate: $revision_to_deactivate"
echo "revision_to_deactivate=$revision_to_deactivate" >> $GITHUB_OUTPUT

# set the new production label
new_prod_label=$([[ $cur_prod_label = 'blue' ]] && echo 'green' || echo 'blue')
echo "New Production Label: $new_prod_label"
echo "new_prod_label=$new_prod_label" >> $GITHUB_OUTPUT