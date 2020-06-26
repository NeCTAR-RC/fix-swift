#!/bin/bash
# save_object.sh
URL="https://swift.rc.nectar.org.au/v1/AUTH_1/swift-audit/audit.log"
for hash in $(curl -s $URL); do
  for qfile in /root/swift-quarantine-*.txt; do
    qloc=`grep ${hash} ${qfile}`
    if [[ $? != 0 && ! -f "${qloc}" ]]; then
      continue
    fi
    echo "Looking for ${hash}"
    echo "Found object ${hash} in ${qloc}. Attempting to save..."
    echo ./jake.sh ${qloc}
  done
done
