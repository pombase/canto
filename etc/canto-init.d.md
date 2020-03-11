## Instructions for setting up Canto as an init.d script.

This assumes you have an existing, initialised `canto-space` directory at
`/var/canto-space`.  See the
[main Canto documentation](https://curation.pombase.org/docs/canto_admin/installation)
for details.

On your server you'll need to install this script somewhere:

  https://github.com/pombase/canto/blob/master/etc/canto-docker-initd

An example would be: `/sbin/canto-docker-initd`.

And make it executable with:

```sh
  chmod a+x /sbin/canto-docker-initd
```

And then you'll need a create a file named `/etc/init.d/canto` with
these contents:

  https://github.com/pombase/canto/blob/master/etc/example-canto-docker-init.d

And make it executable with:

```sh
  chmod a+x /etc/init.d/canto
```

If your "canto-docker-initd" is in a different location you'll need to
edit /etc/init.d/canto


After those two files are in place, run:

```sh
  update-rc.d canto defaults
```

Now you can start canto with:

```sh
  /etc/init.d/canto start
```

Restart with

```sh
  /etc/init.d/canto restart
```

And stop with

```sh
  /etc/init.d/canto stop
```

For troubleshooting, a log file is written to `/var/canto-space/canto.log`.

Canto will now start automatically when the machine/VM reboots.
