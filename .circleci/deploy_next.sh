#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

for entry in $(ls ./.next/serverless/pages/ | grep -v "^_")
do
    current_function=$(basename $entry .js)
    current_build="${current_function}_${DEPLOY_ENVIRONMENT}"

    zip -r "${current_build}.zip" .
    echo "Checking if function $current_build already exists"
    functionArn=$(aws lambda list-functions | jq -r --arg CURRENTFUNCTION "$current_build" '.Functions[] | select(.FunctionName==$CURRENTFUNCTION) | .FunctionArn')
    if [ -z "$functionArn" ]
    then
        echo "Creating function: $current_build"
        functionArn=$(aws lambda create-function --function-name "$current_build" --runtime nodejs8.10 --role arn:aws:iam::$AWS_ACCOUNT_ID:role/lambda-basic-role --handler index.handler --zip-file fileb://./"${current_build}.zip" | jq -r '.FunctionArn')
        if [ -z "$functionArn" ]
        then
            echo "Failed to get functionArn"
            exit 1
        fi
    fi
    echo "Updating function: $current_build"
    aws lambda update-function-code --function-name "$current_build" --zip-file fileb://./"${current_build}.zip" --no-publish
    echo "Publishing version"
    version=$(aws lambda publish-version --function-name "$current_build" | jq .Version | xargs)
    echo "Check for alias"
    CREATE_ALIAS_EXIT_CODE=0
    aws lambda get-alias --function-name "$current_build" --name $GIT_SHA || CREATE_ALIAS_EXIT_CODE=$?
    if [ $CREATE_ALIAS_EXIT_CODE -ne 0 ]
    then
        echo "Creating alias"
        aws lambda create-alias --function-name "$current_build" --description "alias for $GIT_SHA" --function-version $version --name $GIT_SHA
    fi
    echo "Check for API resource"
    parentID=$(aws apigateway get-resources --rest-api-id $AWS_REST_API_ID | jq -r '.items[] | select(.path=="/") | .id')
    resourceID=$(aws apigateway get-resources --rest-api-id $AWS_REST_API_ID | jq -r --arg CURRENTPATH "/$current_function" '.items[] | select(.path==$CURRENTPATH) | .id')
    echo "parentID: $parentID, resourceID: $resourceID"
    if [ -z "$resourceID" ]
    then
        echo "Creating resource"
        resourceID=$(aws apigateway create-resource --rest-api-id $AWS_REST_API_ID --parent-id $parentID --path-part "$current_function" | jq -r '.id')
        echo "Created resource with id: $resourceID"
    fi
    echo "Check for Resource Method"
    GET_METHOD_EXIT_CODE=0
    aws apigateway get-method --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method POST || GET_METHOD_EXIT_CODE=$?
    if [ $GET_METHOD_EXIT_CODE -ne 0 ]
    then
        echo "Creating Resource Method"
        aws apigateway put-method --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method POST --authorization-type NONE
    fi
    echo "Check for integration"
    GET_INTEGRATION_EXIT_CODE=0
    aws apigateway get-integration --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method POST || GET_INTEGRATION_EXIT_CODE=$?
    if [ $GET_INTEGRATION_EXIT_CODE -ne 0 ]
    then
        echo "Creating Integration"
        aws apigateway put-integration --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method POST --type AWS_PROXY --integration-http-method POST --uri arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$functionArn:$GIT_SHA/invocations
    fi
    aws apigateway update-integration --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method POST --patch-operations "[ {\"op\" : \"replace\",\"path\" : \"/uri\",\"value\" : \"arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$functionArn:$GIT_SHA/invocations\"} ]"
    echo "Delete API Gateway permission if exists"
    REMOVE_PERMISSION_EXIT_CODE=0
    STATEMENT_ID="${GIT_SHA}_${current_build}"
    aws lambda remove-permission --function-name arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$current_build:$GIT_SHA --statement-id $STATEMENT_ID || REMOVE_PERMISSION_EXIT_CODE=$?
    echo "Creating API Gateway permission"
    aws lambda add-permission --function-name arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$current_build:$GIT_SHA --source-arn "arn:aws:execute-api:$AWS_REGION:$AWS_ACCOUNT_ID:$AWS_REST_API_ID/*/*/$current_function" --principal apigateway.amazonaws.com --statement-id $STATEMENT_ID --action lambda:InvokeFunction
    echo "Creating deployment"
    aws apigateway create-deployment --rest-api-id $AWS_REST_API_ID --stage-name default
done
