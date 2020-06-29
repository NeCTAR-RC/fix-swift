#!/usr/bin/env python3
import argparse
import logging
import pathlib
import requests
import sys
import time

from swift.common.utils import hash_path
from swift.obj.diskfile import read_metadata
from swift.common.ring import Ring

FORMATTER = logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(message)s")

def get_console_handler():
	console_handler = logging.StreamHandler(sys.stdout)
	console_handler.setFormatter(FORMATTER)
	return console_handler

def get_logger(logger_name):
	logger = logging.getLogger(logger_name)
	logger.setLevel(logging.DEBUG)
	logger.addHandler(get_console_handler())
	logger.propagate = False
	return logger

logger = get_logger('__name__')

def http_request(url, headers=None):

    if not headers:
      headers = {
        'X-Backend-Storage-Policy-Index': '0',
        'User-Agent': 'true',
      }

    response = requests.head(url, headers=headers)

    return response

def check_replica(ip, port, device, part, account, container, obj):
    swift_obj = "/".join([account, container, obj])
    url = "http://%s:%s/%s/%s/%s" % (ip, port, device, part, swift_obj)
    response = http_request(url)
    if response.status_code is 200:
        return True
    return False

def recover_quarantine(datafile, metadata, part, account, container, obj):

    path_hash = hash_path(account, container, obj)
    fname = datafile.name
    base_dir = datafile.parents[3]

    origin_dir = base_dir / 'objects' / str(part) / path_hash[-3:] / path_hash
    origin_file = origin_dir / fname

    if not origin_file.exists():
        logger.debug("move quarantined data %s to %s" % (
                     datafile, original_file))
        mkdir_command = "mkdir -p %s\n" % origin_dir
        mv_command = "mv %s %s\n" % (datafile, origin_file)
        return mkdir_command + mv_command
    else:
        with open(origin_file, 'rb') as fp:
            origin_metadata = read_metadata(fp)
        if metadata['ETag'] == origin_metadata['ETag']:
            logger.debug("%s already exists, don't do anything" % origin_file)
        elif metadata['X-Timestamp'] > origin_metadata['X-Timestamp']:
            logger.debug("quarantined data %s is newer than object data %s, "
                         "overwrite object data" % (datafile, original_file))
            return "mv %s %s\n" % (datafile, origin_file)
        else:
            logger.debug("object data %s is newer than quarantine data %s, "
                         "don't do anything" % (origin_file, datafile))


def get_all_datafiles(path):
    path = pathlib.Path(path)
    return path.glob('**/*.data')

def main():

    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--disk', action='store',
                        required=True,
                        help='The disk to be checked')
    parser.add_argument('-l', '--limit', action='store',
                        default=10, type=int,
                        help='Only process this many objects')

    args = parser.parse_args()

    path = "/srv/node/%s/quarantined/objects/" % args.disk
    if not pathlib.Path(path).exists():
        logger.error("Path %s not exist, exit!" % path)
        sys.exit(1)

    files = get_all_datafiles(path)
    limit = args.limit
    actionfile = 'action_%s.sh' % time.strftime("%Y%m%d-%H%M%S")
    logger.info("action commands will be written into file %s" % actionfile)

    ring = Ring('/etc/swift/', ring_name='object')

    for datafile in files:
        if limit < 1:
            break

        with open(datafile, 'rb') as fp:
            try:
                metadata = read_metadata(fp)
            except EOFError:
                logger.error("%s has invalid metadata" % datafile)
                continue

        name = metadata.get('name')
        account, container, obj = name.split('/', 3)[1:]
        part, nodes = ring.get_nodes(account, container, obj)

        replica_count = 0
        for node in nodes:
            if check_replica(node['ip'], node['port'], node['device'], part,
                             account, container, obj):
                replica_count = replica_count + 1

        if replica_count == len(nodes):
            logger.info("quarantined file %s has %s copies and can be deleted "
                        "safely" % (datafile, replica_count))
            command = "rm -v %s\nrmdir -v %s\n" % (datafile, datafile.parent)
        elif replica_count == 0:
            command = recover_quarantine(datafile, metadata, part,
                                         account, container, obj)

        if command:
            with open(actionfile, 'a') as fp:
                fp.write(command)
        limit = limit - 1

if __name__ == '__main__':
    main()
