#!/bin/bash
source get-rate-limit.sh

HIPCHAT_TOKEN=`cat .hipchat_token2`

# Name of the configuration file
ROOMJSON=rooms.json
ROOMIDS=room_ids.txt

# Reset the repo list
: > ${ROOMJSON}

next_url='next'
index=0

while [ ! "$next_url" == "null" ]; 
do
    index=$((index+1))

    if [ "$next_url" == "next" ]; then
        # All rooms this user has access to
        this_url="http://api.hipchat.com/v2/room?start-index=0&max-results=200&include-private=true&include-archived=true"
    else
        this_url=$next_url
    fi

    if [ ! "$next_url" == "next" ]; then
        # Check rate limiting
        check_rate_limit "${HIPCHAT_TOKEN}" "http://api.hipchat.com/v2/room/"
    fi

    echo "Fetching ${this_url}"

    # Fetch results from the link
    curl -sS -H "Authorization: Bearer ${HIPCHAT_TOKEN}" -H "Content-Type: application/json" ${this_url} > rooms_tmp${index}.json

    # Grab the next url
    next_url=$(jq --raw-output '.links .next' rooms_tmp${index}.json)

    # Merge into one large json as we go
    jq -s '[.[] | to_entries] | flatten | reduce .[] as $dot ({}; .[$dot.key] += $dot.value)' ${ROOMJSON} rooms_tmp${index}.json > tmp.json
    cat tmp.json > ${ROOMJSON}
    rm -f tmp.json
    
    # Discard the individual files
    rm -f rooms_tmp${index}.json
done

# Get just the IDs
jq --raw-output '.items | .[] | .id' ${ROOMJSON} > ${ROOMIDS}
