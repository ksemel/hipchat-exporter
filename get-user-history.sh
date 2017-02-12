#!/bin/bash
source get-rate-limit.sh

HIPCHAT_TOKEN=`cat .hipchat_token`

# Name of the configuration file
USERJSON=users.json
USERIDS=user_ids.txt

mkdir -p users

next_url='next'

# Grab the config file contents into file descriptor 4
exec 4< $USERIDS
# Read each line of the file as CONFIG_FH
while read <&4 USER_FH;
do
    if [[ ${USER_FH:0:1} = '#' ]]; then
        # skip comments
        continue;
    fi;

    # strip leading and trailing spaces.
    USERID=${USER_FH//[[:blank:]]}

    TIMESTAMP=$(date +%s)

    # Get the user name without spaces
    USERNAME=$(jq --raw-output ".items | .[] | select(.id == ${USERID}) | .name" ${USERJSON} | tr -d '[:space:]')
    
    # Did we process this user already?
    if [ -d "users/${USERNAME}" ]; then
        echo "Skipping $USERNAME ($USERID), already archived"
        next_url='null'    
    else
        if grep -Fxq "$USERNAME ($USERID)" user_skip.txt; then
            echo "Skipping $USERNAME ($USERID), found in skip file"
            next_url='null'    
        else
            # User not found in skip file
            echo "Fetching $USERNAME ($USERID)"
            mkdir -p users/${USERNAME}
            next_url='next'
        fi
    fi

    if [ ! "$next_url" == "null" ]; then
        # Check rate limiting
        check_rate_limit "${HIPCHAT_TOKEN}" "http://api.hipchat.com/v2/user/"
    fi

    while [ ! "$next_url" == "null" ]; 
    do
        if [ "$next_url" == "next" ]; then
            this_url="http://api.hipchat.com/v2/user/${USERID}/history?date=${TIMESTAMP}&reverse=false&start-index=0&max-results=1000"
            index=1
        else
            this_url=$next_url
            index=$((index+1))
        fi

        #echo "Fetching ${this_url}"
        check_rate_limit "${HIPCHAT_TOKEN}" "http://api.hipchat.com/v2/user/"

        # Fetch results from the link
        curl -sS -H "Authorization: Bearer ${HIPCHAT_TOKEN}" -H "Content-Type: application/json" ${this_url} > chat_tmp.json

        result_count=$(jq '.items | . | length' chat_tmp.json)
        #echo $result_count 
        #echo $index
        
        # If we got back nothing on the first pass
        # don't write anything and remove the user folder
        if (( $result_count == 0 )); then 
            if (( $index == 1 )); then
                rm -rf users/${USERNAME}
                echo '    - No chats'
                # Add to skip file for next run
                echo "$USERNAME ($USERID)" >> user_skip.txt
                next_url='null'
            fi
        else
            echo "    - ${result_count} chats"

            # Grab the next url
            next_url=$(jq --raw-output '.links .next' chat_tmp.json)
            
            CHATFILE="users/${USERNAME}/user_${USERID}_${index}.json"
            cat chat_tmp.json > ${CHATFILE}
        fi

        # Discard the individual files
        rm -f chat_tmp.json
    done
done
