#!/bin/bash
source get-rate-limit.sh

HIPCHAT_TOKEN=`cat .hipchat_token`

# Name of the configuration file
USERJSON=users.json
USERIDS=user_ids.txt

# Reset the repo list
: > ${USERJSON}

next_url='next'
index=0

while [ ! "$next_url" == "null" ]; 
do
    index=$((index+1))

    if [ "$next_url" == "next" ]; then
        # All active users
        this_url="http://api.hipchat.com/v2/user?start-index=0&max-results=100"
    else
        this_url=$next_url
    fi

    if [ ! "$next_url" == "next" ]; then
        # Check rate limiting
        check_rate_limit "${HIPCHAT_TOKEN}" "http://api.hipchat.com/v2/user/"
    fi

    echo "Fetching ${this_url}"

    # Fetch results from the link
    curl -sS -H "Authorization: Bearer ${HIPCHAT_TOKEN}" -H "Content-Type: application/json" ${this_url} > users_tmp${index}.json

    # Grab the next url
    next_url=$(jq --raw-output '.links .next' users_tmp${index}.json)
        
    # Merge into one large json as we go
    jq -s '[.[] | to_entries] | flatten | reduce .[] as $dot ({}; .[$dot.key] += $dot.value)' ${USERJSON} users_tmp${index}.json > tmp.json
    cat tmp.json > ${USERJSON}
    rm -f tmp.json

    # Discard the individual files
    rm -f users_tmp${index}.json
done

# Get just the IDs
jq --raw-output '.items | .[] | .id' ${USERJSON} > ${USERIDS}
