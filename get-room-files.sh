#!/bin/bash

# Name of the configuration file
FILESJSON=files.json
FILEURLS=file_urls.txt

# Configure AWS
AWS_BUCKET='s3://git-reaper'
AWS_PROFILE='git-reaper'

# Configure AWS
AWS=/usr/local/bin/aws
[[ ! -e "${AWS}" ]] && curl -ksLO https://bootstrap.pypa.io/get-pip.py && python get-pip.py && pip install awscli && rm -f get-pip.py
[[ ! -e "${AWS}" ]] && printf "`date +%H:%M:%S` ==> Missing ${AWS}. Aborting.\n" && exit 1

# Reset the repo list
: > ${FILESJSON}

for directory in rooms/*; do
    if [[ -d $directory ]]; then
        echo "  - Parsing files from ${directory}"

        for filename in ${directory}/*.json; do
            #echo "Parsing ${filename}"
            # Grab all urls from this json
            jq -s --raw-output '.[] .items | .[] | select(.file).file | .url' ${filename} >> ${FILEURLS}
        done
        
        # Grab the config file contents into file descriptor 4
        exec 4< $FILEURLS
        # Read each line of the file as CONFIG_FH
        while read <&4 FH; do

            if [[ ${FH:0:1} = '#' ]]; then
                # skip comments
                continue;
            fi;

            # strip leading and trailing spaces.
            URL=${FH//[[:blank:]]}
            FILE=$(basename $URL)

            # Download file
            curl -sS -o ${FILE} $URL

            # Push to s3 bucket
            echo "   - Sending ${FILE} to S3"
            #$AWS s3 sync . "${AWS_BUCKET}/$directory/files/" --exclude '*' --include '${FILE}' --profile ${AWS_PROFILE}
            $AWS s3 cp "${FILE}" "${AWS_BUCKET}/$directory/files/${FILE}" --profile ${AWS_PROFILE}

            # Delete temp file
            rm -f ${FILE}
            
        done; #end while

        # reset the urls list
        : > ${FILEURLS}
    fi
done

