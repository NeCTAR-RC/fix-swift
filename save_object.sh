#!/bin/bash
# save_object.sh

URL="https://swift.rc.nectar.org.au/v1/AUTH_1/swift-audit/audit.log"

for hash in $(curl -s $URL); do

  for qfile in /root/swift-quarantine-*.txt; do
    if [[ ! -f ${qfile} ]]; then
      break
    fi
    echo "Looking for ${hash}"
    qloc=`grep ${hash} ${qfile}`
  
    if [[ ! -z "${qloc}" ]]; then
      echo "Found object ${hash} in ${qloc}. Attempting to save..."
      ./jake.sh ${qloc}
    fi
  done
done
