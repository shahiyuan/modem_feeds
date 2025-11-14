#!/bin/sh

# Webhook SMS Forward Script
# Environment variables available:
# SMS_SENDER - sender phone number
# SMS_TIME - timestamp string
# SMS_CONTENT - SMS content

# Parse API config from environment or config file
API_CONFIG="$1"

if [ -z "$API_CONFIG" ]; then
    echo "Error: API config not provided"
    exit 1
fi

# Extract configuration using jq or manual parsing
WEBHOOK_URL=$(echo "$API_CONFIG" | jq -r '.webhook_url' 2>/dev/null)
HEADERS=$(echo "$API_CONFIG" | jq -r '.headers' 2>/dev/null)
FORMAT=$(echo "$API_CONFIG" | jq -r '.format' 2>/dev/null)
REQUEST_METHOD=$(echo "$API_CONFIG" | jq -r '.request_method' 2>/dev/null)

# Fallback to manual parsing if jq fails
if [ -z "$WEBHOOK_URL" ] || [ "$WEBHOOK_URL" = "null" ]; then
    WEBHOOK_URL=$(echo "$API_CONFIG" | grep -o '"webhook_url":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$HEADERS" ] || [ "$HEADERS" = "null" ]; then
    HEADERS=$(echo "$API_CONFIG" | grep -o '"headers":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$WEBHOOK_URL" ]; then
    echo "Error: Missing required webhook URL"
    exit 1
fi

# Prepare payload based on format
if [ -z "$FORMAT" ] || [ "$FORMAT" = "null" ];then
    payload="$SMS_SENDER/$SMS_CONTENT($SMS_TIME)"
else
    payload=$(echo "$FORMAT" | sed "s/{SENDER}/$SMS_SENDER/g; s/{TIME}/$SMS_TIME/g; s/{CONTENT}/$SMS_CONTENT/g")
fi
# Prepare curl command
if [ -z "$REQUEST_METHOD" ] || [ "$REQUEST_METHOD" = "null" ]; then
    REQUEST_METHOD="GET"
fi
CURL_CMD="curl -s -X $REQUEST_METHOD"
[ -n "$HEADERS" ] && CURL_CMD="$CURL_CMD -H \"$HEADERS\""
if [ "$REQUEST_METHOD" = "POST" ]; then
    CURL_CMD="$CURL_CMD -d \"$payload\""
else
    # replay space and special characters in payload for URL
    payload=$(echo "$payload" | sed 's/ /%20/g;s/!/%21/g;s/"/%22/g;s/#/%23/g;s/\$/%24/g;s/&/%26/g;s/'\''/%27/g;s/(/%28/g;s/)/%29/g;s/*/%2A/g;s/+/%2B/g;s/,/%2C/g;s/;/%3B/g;s/=/%3D/g;s/?/%3F/g;s/@/%40/g;s/\[/%5B/g;s/\\/%5C/g;s/\]/%5D/g;s/\^/%5E/g;s/_/%5F/g;s/`/%60/g;s/{/%7B/g;s/|/%7C/g;s/}/%7D/g;s/~/%7E/g')
    WEBHOOK_URL="$WEBHOOK_URL/$payload"
fi
CURL_CMD="$CURL_CMD \"$WEBHOOK_URL\""
# Execute curl command
echo "Executing curl command: $CURL_CMD"
eval $CURL_CMD

exit $?
