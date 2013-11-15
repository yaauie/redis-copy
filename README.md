# Redis::Copy

This utility provides a way to move the contents of one redis DB to another
redis DB. It is inspired by the [redis-copy.rb script][original] included in
the redis source, but supports the following additional features:

 - all known data types (original supported `set`, `list`, and `string`,
   dropping the others without warning)
 - if available on both dbs, will use `DUMP`/`RESTORE` commands (redis v2.6+)
 - support for more than just db0

[original]: https://github.com/antirez/redis/commits/unstable/utils/redis-copy.rb

## Installation

    $ gem install redis-copy

## Usage

The current options can be grabbed using the `--help` flag.

```
$ redis-copy --help
redis-copy v0.1.0 (with redis-rb 3.0.6)
Usage: redis-copy [options] <source> <destination>
    <source> and <destination> must be redis connection uris
    like [redis://][<username>:<password>@]<hostname>[:<port>][/<db>]

Specific options:
        --[no-]pipeline              Use redis pipeline where available (default true)
    -r, --require FILENAME           Require a script; useful for loading third-party
                                     implementations of key-emitter or copy strategies.
                                     Relative paths *must* begin with `../' or `./'.
    -d, --[no-]debug                 Write debug output (default false)
    -t, --[no-]trace                 Enable backtrace on failure (default false)
    -f, --[no-]fail-fast             Abort on first failure (default false)
        --[no-]verify [PERCENT]      Verify percentage of transfers -- VERY SLOW (default 0)
        --[no-]prompt                Prompt for confirmation (default true)
        --[no-]allow-nonempty        Allow non-empty destination (default false)
        --[no-]dry-run               Output configuration and exit
```

## Example:

```
$ redis-copy --fail-fast --yes old.redis.host/9 new.redis.host:6380/3
Source:      redis://old.redis.host:6379/9
Destination: redis://new.redis.host:6380/3 (empty)
Key Emitter: Default
Strategy:    New
PROGRESS {:success=>1000, :attempt=>1000}
PROGRESS {:success=>2000, :attempt=>2000}
PROGRESS {:success=>3000, :attempt=>3000}
PROGRESS {:success=>4000, :attempt=>4000}
DONE: {:success=>4246, :attempt=>4246}
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
