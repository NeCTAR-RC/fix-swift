#!/bin/bash
IFS=$'\t\n'

DISK=$1
[ -z $DISK ] && exit 1

echo "Using disk $DISK"

OBJECTS=/root/swift-objects-$DISK.txt
QUARANTINE=/root/swift-quarantine-$DISK.txt

if [ -f $QUARANTINE ]; then
    echo "Using existing $QUARANTINE"
else
    echo "Generating quarantine list $QUARANTINE..."
    find /srv/node/$DISK/quarantined/objects/ -name '*.data' > $QUARANTINE
fi

if [ -f $OBJECTS ]; then
    echo "Using existing $OBJECTS"
else
    echo "Generating objects list $OBJECTS..."
    find /srv/node/$DISK/objects/ -name '*.data' > $OBJECTS
fi

echo "Testing quarantine files..."
for FILE in $(cat $QUARANTINE); do
    FPATH=$(echo $FILE | awk -F'/' '{print $(NF-1)"/"$NF}')
    for F in $(grep $FPATH $OBJECTS); do
        echo "Checking $FPATH"
        curls=$(swift-object-info $F | grep '^curl' | grep -v Handoff)
        found="no"
        for curlcmd in $curls; do
            http_code=$(eval "$curlcmd --path-as-is -s -o /dev/null -w '%{http_code}'")
            if [[ $http_code -eq 404 ]]; then
                 found="yes"
                 break
            fi
        done
        if [[ "$found" == "no" ]]; then
            echo "No copies found for $FPATH, running jake.sh"
            ./jake.sh $FILE
        fi
    done
done
