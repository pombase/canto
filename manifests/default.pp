class canto {
  exec { "apt-update":
    command => "/usr/bin/apt-get update"
  }

  Exec["apt-update"] -> Package <| |>

  package { "libmodule-install-perl":
    ensure => present,
  }

  package { "libemail-sender-perl":
    ensure => present,
  }

  package { "libtest-output-perl":
    ensure => present,
  }

  package { "libcatalyst-devel-perl":
    ensure => present,
  }

  package { "ntpdate":
    ensure => present,
  }

  package { "sqlite3":
    ensure => present,
  }

  package { "make":
    ensure => present,
  }

  package { "git-core":
    ensure => present,
  }

  package { "libhash-merge-perl":
    ensure => present,
  }

  package { "libplack-perl":
    ensure => present,
  }

  package { "libdbix-class-perl":
    ensure => present,
  }

  package { "libdbix-class-schema-loader-perl":
    ensure => present,
  }

  package { "libio-all-lwp-perl":
    ensure => present,
  }

  package { "libwww-perl":
    ensure => present,
  }

  package { "perl":
    ensure => present,
  }

  package { "gcc":
    ensure => present,
  }

  package { "g++":
    ensure => present,
  }

  package { "tar":
    ensure => present,
  }

  package { "gzip":
    ensure => present,
  }

  package { "bzip2":
    ensure => present,
  }

  package { "libclucene-dev":
    ensure => present,
  }

  package { "libclucene0ldbl":
    ensure => present,
  }

  package { "libjson-xs-perl":
    ensure => present,
  }

  package { "libio-all-perl":
    ensure => present,
  }

  package { "libio-string-perl":
    ensure => present,
  }

  package { "libmemoize-expirelru-perl":
    ensure => present,
  }

  package { "libtry-tiny-perl":
    ensure => present,
  }

  package { "libarchive-zip-perl":
    ensure => present,
  }

  package { "libtext-csv-xs-perl":
    ensure => present,
  }

  package { "liblingua-en-inflect-number-perl":
    ensure => present,
  }

  package { "libcatalyst-modules-perl":
    ensure => present,
  }

  package { "libmoose-perl":
    ensure => present,
  }

  package { "libdata-compare-perl":
    ensure => present,
  }

  package { "libmoosex-role-parameterized-perl":
    ensure => present,
  }

  package { "libfile-copy-recursive-perl":
    ensure => present,
  }

  package { "libfile-touch-perl":
    ensure => present,
  }

  package { "libxml-simple-perl":
    ensure => present,
  }

  package { "libtext-csv-perl":
    ensure => present,
  }

  package { "libtest-deep-perl":
    ensure => present,
  }

  package { "libextutils-depends-perl":
    ensure => present,
  }

  package { "libchi-perl":
    ensure => present,
  }

  package { "libweb-scraper-perl":
    ensure => present,
  }

  package { "liblwp-protocol-psgi-perl":
    ensure => present,
  }

  package { "libdata-javascript-anon-perl":
    ensure => present,
  }

  package { "libcatalyst-engine-psgi-perl":
    ensure => present,
  }

  package { "libcache-perl":
    ensure => present,
  }

  package { "libcache-memcached-perl":
    ensure => present,
  }

  package { "libchi-driver-memcached-perl":
    ensure => present,
  }

  package { "libpq5":
    ensure => present,
  }

  package { "libdbd-pg-perl":
    ensure => present,
  }

  package { "libtext-microtemplate-perl":
    ensure => present,
  }

  package { "libdata-dump-streamer-perl":
    ensure => present,
  }

  package { "liblist-moreutils-perl":
    ensure => present,
  }
}

include canto
