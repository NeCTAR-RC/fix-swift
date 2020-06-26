#!/bin/bash
# save_object.sh

hash=$1

qloc=`grep ${hash} /root/swift-quarantine-*.txt`

if [[ ! -z ${qloc} ]]; then
  echo "jake is attempting to save object ${hash}"
  ./jake.sh ${qloc}
fi
