# Instructions for running Canto as an init script

This assumes you have an existing, initialised `canto-space` directory (at
`/var/canto-space` by default). See the
[main Canto documentation](https://curation.pombase.org/docs/canto_admin/installation)
for details.

First, you will need the Canto init script from the Canto repository:

<https://github.com/pombase/canto/blob/master/etc/canto-docker-initd>

Copy this script to `/etc/init.d/canto` on your server, and make it executable
with the following command:

```sh
chmod a+x /etc/init.d/canto
```

You may also need to change the owner of the script to the `root` user:

```sh
chown root:root /etc/init.d/canto
```

## Installing the service
Instructions are shown below for installing Canto as a service using various
service managers. Once installed with either system, Canto should start
automatically whenever the machine (or virtual machine) boots.
### update-rc.d

If your server uses the `update-rc.d` command, run the following command to
install the `canto` service:

```sh
update-rc.d canto defaults
```

Now you can start Canto with the following command:

```sh
/etc/init.d/canto start
```

restart with:

```sh
/etc/init.d/canto restart
```

and stop with:

```sh
/etc/init.d/canto stop
```

### systemd

If your server uses `systemd`, run the following command to
install the `canto` service:

```sh
systemctl enable canto
```
(The Canto init script is not a native systemd service, but systemd should
still be able to install the script.)

Now you can use the `service` command to manage Canto like any other systemd
service. You can start Canto with:

```sh
service canto start
```

restart with:

```sh
service canto restart
```

and stop with:

```sh
service canto stop
```

## Configuring the service

The Canto repository provides a file called `canto.defaults` that can be used
to configure parts of the service. This file is completely optional.

The configuration file can be found here:

<https://github.com/pombase/canto/blob/master/etc/canto.defaults>

Copy this script to `/etc/default/canto` on your server.

To configure the service, simply uncomment the line in `/etc/default/canto` 
that has the variable you want to change, and set a value for the variable.
For example, to change the port number to 7000, the file would be changed 
as follows:

```sh
# Port number for Canto's web server.
PORT=7000
```

The `canto.defaults` file allows the following variables to be configured:

* `PORT`: the port number for Canto's web server. Defaults to port
  number 5000.

* `WORKERS`: the number of worker processes used by the
  [Starman](https://metacpan.org/pod/Starman) web server. Defaults to 
  5 workers. You may want to adjust this to suit the memory requirements
  of your server.

* `CANTO_SPACE`: the path to the base directory of the Canto application.
  Defaults to `/var/canto-space`. Note that this is the path to the 
  containing directory for the `canto`, `data` and `import_export`
  directories; it is _not_ the path to the `canto` directory itself.

* `PID_PATH`: the path to the process ID file for the Server::Starter process.
  Defaults to `import_export/canto.pid`. Note that this path is relative to 
  the root of the Docker container's filesystem, and cannot be set to any 
  path that does not exist in both the host filesystem and the container.
  You should not normally need to configure this value.
  
## Logging and troubleshooting

The service file writes output from Canto to a log file at
`/var/canto-space/canto.log`. If you are using systemd, you can also use
the following command to check the service status:

```sh
service canto status
```
