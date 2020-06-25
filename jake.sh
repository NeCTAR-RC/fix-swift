#!/bin/bash
FILE=$1
IPADDRESS=$2
if [[ ! -f ${FILE} ]]; then
  echo "${FILE} is not a file"
  exit 1
fi
if [[ -z ${IPADDRESS} ]]; then
  IPADDRESS=`/opt/puppetlabs/bin/facter ipaddress`
  echo "Guessing ipaddress to be ${IPADDRESS}"
fi
# name of the file
filename=`basename ${FILE}`
# this is where the file location should be
sshloc=`swift-object-info ${FILE} | grep '^ssh' | grep -v 'Handoff' | grep ${IPADDRESS} | cut -f2 -d '"' | cut -f3 -d ' '`
if [[ -z ${sshloc} ]]; then
  echo "Did not find local dir that requires this file"
  exit 3
fi
# TODO remove ${DEVICE:-/srv/node*} and add /srv/node
sshloc=`echo $sshloc | sed  's,\${DEVICE:-/srv/node\*},/srv/node,g'`
# on disk location
diskloc=`echo "${sshloc}/${filename}"`
echo "$FILE should be in ${diskloc}"
if [[ -f ${diskloc} ]]; then
  md1=`md5sum ${FILE} | cut -f1 -d' '`
  md2=`md5sum "${diskloc}" | cut -f1 -d' '`
  echo "md1 ${md1}"
  echo "md2 ${md2}"
  if [ "${md1}" == "${md2}" ]; then
    echo "md5sum matches, do not need to do anything"
    exit 5
  fi
else
  echo "$diskloc does not exist, going to move it"
  dir=`dirname $diskloc`
  if [[ ! -d $dir ]]; then
    mkdir -v -p $dir
    chown -v -R swift:swift $dir/..
  fi
  mv -v ${FILE} ${diskloc}
fi
