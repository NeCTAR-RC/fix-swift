#!/bin/bash
# save_object.sh

URL="https://swift.rc.nectar.org.au/v1/AUTH_f42f9588576c43969760d81384b83b1f/public/missing_object_hash"

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
