#!/bin/bash

function check_rate_limit {
    # 1 Token
    # 2 URL

    HIPCHAT_TOKEN=${1}
    API_URL=${2}

    # Check rate limiting
    shopt -s extglob # Required to trim whitespace; see below
    while IFS=':' read key value; do
        # trim whitespace in "value"
        value=${value##+([[:space:]])}; value=${value%%+([[:space:]])}
        case "$key" in
            X-Ratelimit-Limit) LIMIT="$value"
                    ;;
            X-Ratelimit-Remaining) REMAINING="$value"
                    ;;
            X-Ratelimit-Reset) RESET="$value"
                    ;;
         esac
    done < <(curl -sI -H "Authorization: Bearer ${HIPCHAT_TOKEN}" ${API_URL} )

    if (( 5 > $REMAINING )); then 
        sleep_seconds=$(( $RESET - $(date +%s) ))
        while [ $sleep_seconds -gt 0 ]; do
           echo -ne "RATE LIMITED, WAITING $sleep_seconds\033[0K SECONDS\r"
           sleep 1
           : $((sleep_seconds--))
        done
    fi
}