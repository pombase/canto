#!/bin/sh -

docker run --rm --net="host" --mount type=bind,source=$(pwd)/,target=/canto -w=/canto \
    pombase/canto-base:v13 /bin/bash -c "cd /canto && perl Makefile.PL && make test"
