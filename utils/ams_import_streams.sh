#!/bin/bash
#
# Import Ant Media Server streams.
#
# Usage:
#   ./import_streams.sh <app_name> <file_name>
# Example:
#   ./import_streams.sh live live_streams.json

APP_NAME=$1
FILE=$2
CONFIG_FILE="/usr/local/antmedia/webapps/$APP_NAME/WEB-INF/red5-web.properties"
BASE_URL="http://localhost:5080"

if [ -z "$APP_NAME" ] || [ -z "$FILE" ]; then
  echo "Usage: $0 <app_name> <file_name>"
  exit 1
fi

jwt_token() {
    iat=$(date +%s)
    header='{"alg":"HS256","typ":"JWT"}'
    payload="{\"iat\":$iat}"

    header_base64=$(echo -n "$header" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    payload_base64=$(echo -n "$payload" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    data="$header_base64.$payload_base64"

    secret=$(grep "^jwtSecretKey=" "$CONFIG_FILE" | cut -d'=' -f2)
    signature=$(echo -n "$data" | openssl dgst -sha256 -hmac "$secret" -binary | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    echo "$data.$signature"
}

JWT_TOKEN=$(jwt_token)
JWT_SECRET=$(grep "^jwtSecretKey=" "$CONFIG_FILE" | cut -d'=' -f2)
jwtControlEnabled=$(grep "^jwtControlEnabled=" "$CONFIG_FILE" | cut -d'=' -f2)

if [ "$jwtControlEnabled" = "true" ] && [ -n "$JWT_SECRET" ]; then
    CURL_CMD=(curl -s -X POST -H "Authorization: Bearer $JWT_TOKEN" -H "accept: application/json" -H "Content-Type: application/json")
else
    CURL_CMD=(curl -s -X POST -H "accept: application/json" -H "Content-Type: application/json")
fi

URL="$BASE_URL/$APP_NAME/rest/v2/broadcasts/create?autoStart=false"

jq -c '.[]' "$FILE" | while read -r stream; do
  "${CURL_CMD[@]}" "$URL" -d "$stream"
  echo "" 
done
