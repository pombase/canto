#!/bin/sh -

docker run --rm -ti --net="host" --mount type=bind,source=$(pwd)/,target=/canto -w=/canto \
    pombase/canto-base:v6 cd /canto \&& perl Makefile.PL \&& make test