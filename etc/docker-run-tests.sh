#!/bin/sh -

docker run --rm --net="host" --mount type=bind,source=$(pwd)/,target=/canto -w=/canto \
    docker.pkg.github.com/pombase/canto/canto-base:v12 /bin/bash -c "cd /canto && perl Makefile.PL && make test"
