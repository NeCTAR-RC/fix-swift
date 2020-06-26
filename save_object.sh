#!/bin/bash
# save_object.sh

URL="https://swift.rc.nectar.org.au/v1/AUTH_1/swift-audit/audit.log"

for hash in $(curl -s $URL); do
  echo "Looking for ${hash}"

  for qfile in $(ls /root/swift-quarantine-*.txt); do
    qloc=`grep ${hash} ${qfile}`
  
    if [[ ! -z ${qloc} ]]; then
      echo "Found object ${hash} in ${qloc}. Attempting to save..."
      ./jake.sh ${qloc}
    fi
  done
done
