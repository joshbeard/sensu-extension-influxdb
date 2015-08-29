# InfluxDB Handler Extension

Sensu extension to write metric data to InfluxDB.

Two methods of doing this are supported:

* InfluxDB Rubygem libraries
* EventMachine

I put both methods in here to test them out.

This is probably a bit dirty.

## Write Methods

### InfluxDB Rubygem

This uses the Rubygem called 'influxdb' to handle writing the data.  It may
not be as performant as EventMachine, but it might offer some benefits.

#### Requirements

The 'influxdb' rubygem needs to be install in Sensu's Ruby environment.
Note that Sensu vendors their own embedded ruby, so having it availble in the
system Ruby won't work.

E.g. `/opt/sensu/embedded/bin/gem install influxdb`

### EventMachine

EventMachine is a high-performance library for handling HTTP stuff.  Sensu
itself uses it.

Some very quick and naive tests showed that server load was considerably lower
when using EventMachine to write the data.

#### Requirements

The 'em-http-request' rubygem needs to be install in Sensu's Ruby environment.
Note that Sensu vendors their own embedded ruby, so having it availble in the
system Ruby won't work.

E.g. `/opt/sensu/embedded/bin/gem install em-http-request`

## Usage

Example of using this with Puppet

```puppet
sensu::extension { 'influxdb':
  source  => 'puppet:///modules/profile/sensu/extensions/influxdb.rb',
  config  => {
    'server'     => 'localhost',
    'port'       => '8086',
    'database'   => 'sensu',
    'username'   => 'sensu',
    'password'   => 'sensu',
    'method'     => 'em',
    'use_ssl'    => false,
    'strip_host' => true,
  },
}
```

The `config` parameter maps to the handler's configuration options.

You can use the `sensu_gem` package provider to manage the required Rubygems.

Example:

```puppet
package { 'influxdb':
  ensure   => 'installed',
  provider => 'sensu_gem',
}
```

Note, however, that the package provider has a quirk where a package can only
be defined *once* in the Puppet catalog, even if you use a different provider.

So, if you have a package called "influxdb" from Yum and then try to define
a package called "influxdb" from Rubygems, Puppet will complain.

Example hack to get around that:

```puppet
exec { 'sensu_gem_influxdb':
  path    => '/opt/sensu/embedded/bin',
  command => 'gem install influxdb --no-ri --no-rdoc',
  unless  => 'gem list influxdb | /bin/grep -q influxdb',
}
```

Without Puppet, you'd probably end up with something like this:

Stick `influxdb.rb` in `/etc/sensu/extensions/`

__/etc/sensu/conf.d/extensions/influxdb.json:__

```json
{
  "influxdb": {
    "server": "localhost",
    "port": "8086",
    "database": "sensu",
    "username": "sensu",
    "password": "sensu",
    "method": "em",
    "use_ssl": false,
    "strip_host": true
  }
}
```

And configure checks with the 'influxdb' handler.

## Options

__server__

The address to the InfluxDB server.

__port__

The port for the InfluxDB server.

__database__

The database on the InfluxDB server to write to.

__username__

The username (if any) to use

__password__

The password (if any) to use

__method__

The method to use for writing.  Refer to the information above.

Use 'em' for EventMachine and 'influxdb' for the influxdb Rubygem

__use_ssl__

Whether to use SSL or not.

__strip_host__

Boolean. Optional. Will strip the client's hostname/fqdn from the metric before
sending.

Example:

`stats.FOO.BAR.COM.uptime` becomes `stats.uptime`

__strip_metric__

Optional. A pattern to strip.

Example:

`strip_metric => 'something'`

`stats.something.really.long` becomes `stats.really.long`

__debug_log__

Optional.  If set, it should be set to an absolute path to spew write data
to so that you can observe what's getting sent to InfluxDB.

This file will grow rapidly!  This is just a way to write human-readable
output to a separate logfile than Sensu's.
