FROM ubuntu:14.04
MAINTAINER Kim Rutherford <kim@pombase.org>
RUN apt-get update
RUN apt-get install -y libmodule-install-perl libemail-sender-perl \
  libtest-output-perl libcatalyst-devel-perl ntpdate sqlite3 make \
  git-core libhash-merge-perl libplack-perl libdbix-class-perl \
  libdbix-class-schema-loader-perl libio-all-lwp-perl libwww-perl \
  perl wget gcc g++ tar gzip bzip2 libclucene-dev libjson-xs-perl \
  libio-all-perl libio-string-perl libmemoize-expirelru-perl \
  libtry-tiny-perl libarchive-zip-perl libtext-csv-xs-perl \
  liblingua-en-inflect-number-perl libcatalyst-modules-perl libmoose-perl \
  libdata-compare-perl libmoosex-role-parameterized-perl \
  libfile-copy-recursive-perl libfile-touch-perl libxml-simple-perl \
  libtext-csv-perl libtest-deep-perl libextutils-depends-perl libchi-perl \
  libweb-scraper-perl liblwp-protocol-psgi-perl libdata-javascript-anon-perl \
  libcatalyst-engine-psgi-perl libcache-perl libcache-memcached-perl \
  libchi-driver-memcached-perl libpq5 libdbd-pg-perl \
  libtext-microtemplate-perl libdata-dump-streamer-perl liblist-moreutils-perl

RUN cd /tmp/ && wget http://archive.ubuntu.com/ubuntu/pool/main/c/clucene-core/libclucene0ldbl_0.9.21b-2_amd64.deb && wget http://archive.ubuntu.com/ubuntu/pool/main/c/clucene-core/libclucene-dev_0.9.21b-2_amd64.deb && dpkg -i libclucene0ldbl_0.9.21b-2_amd64.deb libclucene-dev_0.9.21b-2_amd64.deb

RUN (echo o conf prerequisites_policy follow; echo o conf build_requires_install_policy no; echo o conf commit) | cpan && cpan -i Module::Install Module::Install::Catalyst

RUN git clone https://github.com/pombase/canto.git && (cd canto; perl Makefile.PL; make installdeps; make; make test)

EXPOSE 7000
