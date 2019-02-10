#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

current_function="$1"
current_build="${current_function}_${DEPLOY_ENVIRONMENT}"
cd $current_function

if [ -f package-lock.json ]; then
    npm ci
fi
zip -r "${current_build}.zip" .
echo "Checking if function $current_build already exists"
functionArn=$(aws lambda get-function --function-name "$current_build"| jq -r '.Configuration.FunctionArn')
if [ -z "$functionArn" ]
then
    echo "Creating function: $current_build"
    functionArn=$(aws lambda create-function --function-name "$current_build" --runtime nodejs8.10 --role arn:aws:iam::$AWS_ACCOUNT_ID:role/service-role/$current_build --handler lambdaCtx.handler --zip-file fileb://./"${current_build}.zip" | jq -r '.FunctionArn')
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
echo "Creating alias"
aws lambda create-alias --function-name "$current_build" --description "alias for $GIT_SHA" --function-version $version --name $GIT_SHA
echo "Check for API resource"
parentID=$(aws apigateway get-resources --rest-api-id $AWS_REST_API_ID | jq -r '.items[] | select(.path=="/") | .id')
resourceID=$(aws apigateway get-resources --rest-api-id $AWS_REST_API_ID | jq -r '.items[] | select(.path=="/${current_function}") | .id')
if [ -z "$resourceID" ]
then
    echo "Creating resource"
    resourceID=$(aws apigateway create-resource --rest-api-id AWS_REST_API_ID --parent-id $parentID --path-part "$current_function" | jq -r '.id')
fi
echo "Check for Resource Method"
aws apigateway get-method --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method ANY
if [ $? -ne 0 ]
then
    echo "Creating Resource Method"
    aws apigateway put-method --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method ANY --authorization-type NONE
fi
echo "Check for integration"
aws apigateway get-integration --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method ANY
if [ $? -ne 0 ]
then
    echo "Creating Integration"
    aws apigateway put-integration --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method ANY --type AWS_PROXY --integration-http-method ANY --uri arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$functionArn:$GIT_SHA/invocations
fi
aws apigateway update-integration --rest-api-id $AWS_REST_API_ID --resource-id $resourceID --http-method ANY --patch-operations "[ {\"op\" : \"replace\",\"path\" : \"/uri\",\"value\" : \"arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$functionArn:$GIT_SHA/invocations\"} ]"
echo "Creating deployment"
aws apigateway create-deployment --rest-api-id $AWS_REST_API_ID --stage-name default
