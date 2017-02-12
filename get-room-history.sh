#!/bin/bash
source get-rate-limit.sh

HIPCHAT_TOKEN=`cat .hipchat_token2`

# Name of the configuration file
ROOMJSON=rooms.json
ROOMIDS=room_ids.txt

mkdir -p rooms

next_url='next'

# Grab the config file contents into file descriptor 4
exec 4< $ROOMIDS
# Read each line of the file as CONFIG_FH
while read <&4 ROOM_FH;
do
    if [[ ${ROOM_FH:0:1} = '#' ]]; then
        # skip comments
        continue;
    fi;

    # strip leading and trailing spaces.
    ROOMID=${ROOM_FH//[[:blank:]]}

    next_url='next'
    TIMESTAMP=$(date +%s)

    # Get the user name without spaces
    ROOMNAME=$(jq --raw-output ".items | .[] | select(.id == ${ROOMID}) | .name" ${ROOMJSON} | tr -d '[:space:]')
    
    # Did we process this user already?
    if [ -d "rooms/${ROOMNAME}" ]; then
        echo "Skipping $ROOMNAME ($ROOMID), already archived"
        next_url='null'    
    else
        if grep -Fxq "$ROOMNAME ($ROOMID)" room_skip.txt; then
            echo "Skipping $ROOMNAME ($ROOMID), found in skip file"
            next_url='null'    
        else
            # User not found in skip file
            echo "Fetching $ROOMNAME ($ROOMID)"
            mkdir -p rooms/${ROOMNAME}
            next_url='next'
        fi
    fi

    if [ ! "$next_url" == "null" ]; then
        # Check rate limiting
        check_rate_limit "${HIPCHAT_TOKEN}" "http://api.hipchat.com/v2/room/"
    fi

    while [ ! "$next_url" == "null" ]; 
    do
        if [ "$next_url" == "next" ]; then
            this_url="http://api.hipchat.com/v2/room/${ROOMID}/history?date=${TIMESTAMP}&reverse=false&max-results=1000"
            index=1
        else
            this_url=$next_url
            index=$((index+1))
        fi

        echo "   Fetching ${this_url}"

        # Check rate limiting
        check_rate_limit "${HIPCHAT_TOKEN}" "http://api.hipchat.com/v2/room/"

        # Fetch results from the link
        curl -sS -H "Authorization: Bearer ${HIPCHAT_TOKEN}" -H "Content-Type: application/json" ${this_url} > chat_tmp.json

        result_count=$(jq '.items | . | length' chat_tmp.json)
        #echo $result_count

        # If we got back max_results, grab the next timestamp
        if (( $result_count == 1000 )); then
            # Get the timestamp from the last item
            TIMESTAMP=$(jq --raw-output '.items | .[-1].date' chat_tmp.json)
            #echo $TIMESTAMP
            next_url="http://api.hipchat.com/v2/room/${ROOMID}/history?date=${TIMESTAMP}&reverse=false&max-results=1000"
            #echo $next_url
        else
            next_url='null'
        fi

        # Make json files
        CHATFILE="rooms/${ROOMNAME}/room_${ROOMID}_${index}.json"
        touch ${CHATFILE}

        cat chat_tmp.json > ${CHATFILE}

        # Discard the temp file
        rm -f chat_tmp.json
    done
done
