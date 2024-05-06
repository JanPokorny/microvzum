#!/bin/bash

FILE_URL=$1
NUM_PARTS=$2

echo "Downloading $FILE_URL in $NUM_PARTS parts..."

# construct request URL
REQUEST_URL=${FILE_URL/datoid.cz/datoid.cz/f}?request=1

# for file name, use last segment of url, but replace last - with .
FILE_NAME=$(echo $FILE_URL | sed 's/.*\///' | sed 's/-\([^-]*\)$/\.\1/')
AUX_DIR_NAME=.microvzum-$FILE_NAME-$NUM_PARTS
mkdir -p $AUX_DIR_NAME

# learn file size
SIZE_HUMAN_READABLE=$(curl --silent $FILE_URL | sed -n 's/Velikost: //p')
SIZE_BYTES=$(echo $SIZE_HUMAN_READABLE | tr -d ' ' | tr B i | numfmt --from=auto)
PART_SIZE=$((SIZE_BYTES / NUM_PARTS))

# start downloading parts
for PART_INDEX in $(seq 0 $((NUM_PARTS - 1))); do
    # register a new account
    COOKIE_JAR=$(mktemp)
    curl 'https://datoid.cz/registrace' \
        --silent \
        --cookie-jar $COOKIE_JAR \
        -X POST \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-raw "emaill=$RANDOM$RANDOM$RANDOM%40gmail.com&password=aaaaa&passwordVerify=aaaaa&agree=on&send=Registrovat+se&email=&redirect=&noRedirectMode=0&_do=signUpForm-submit" \
        > /dev/null

    # get a new download URL
    DOWNLOAD_URL=$(curl $REQUEST_URL --silent --cookie $COOKIE_JAR | sed -n 's/.*"download_link":"\([^"]*\)".*/\1/p')

    # compute part range
    PART_START=$((PART_INDEX * PART_SIZE))
    PART_END=$((PART_START + PART_SIZE - 1))
    if (( PART_INDEX == NUM_PARTS - 1 )); then PART_END=; fi

    # start background download
    curl --silent --range "$PART_START-$PART_END" --output "$AUX_DIR_NAME/part$PART_INDEX" "$DOWNLOAD_URL" &

    echo "part $((PART_INDEX + 1))/$NUM_PARTS: started"
done

# wait for all downloads to finish, echo progress
PREVIOUS_SLOWEST_PART_SIZE_BYTES=0
while jobs %% >/dev/null 2>/dev/null; do
    tput cuu $NUM_PARTS # move cursor up
    for PART_INDEX in $(seq 0 $((NUM_PARTS - 1))); do
        PART_SIZE_BYTES=$(stat --format=%s $AUX_DIR_NAME/part$PART_INDEX 2>/dev/null || echo 0)
        PART_PERCENT=$((PART_SIZE_BYTES * 100 / PART_SIZE))
        echo -e "\033[2Kpart $((PART_INDEX + 1))/$NUM_PARTS: $PART_PERCENT %"
    done
    sleep 1
done

# concatenate parts
echo "Concatenating parts..."
cat $AUX_DIR_NAME/part* > $FILE_NAME
rm -rf $AUX_DIR_NAME

echo "Done!"
