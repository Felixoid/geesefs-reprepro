FROM ubuntu:22.04

RUN apt update \
  && apt-get --yes install build-essential:native libgpgme-dev libdb-dev libbz2-dev liblzma-dev libarchive-dev shunit2:native db-util:native devscripts libz-dev debhelper-compat \
    ca-certificates fuse3 \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/* \
  && mkdir /data

WORKDIR /data
