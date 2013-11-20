# RedisCopy

This utility provides a way to move the contents of one redis DB to another
redis DB. It is inspired by the [redis-copy.rb script][original] included in
the redis source, but aims to always support all object types and to use the
most-efficient methods and commands available to your redis versions:

 - if available on both dbs, will use `DUMP`/`RESTORE` commands (redis v2.6+)
 - if available on source db, will use `SCAN` instead of `KEYS` (redis v2.8+)

[original]: https://github.com/antirez/redis/commits/unstable/utils/redis-copy.rb

## Installation

    $ gem install redis-copy

## Usage

The current options can be grabbed using the `--help` flag.

```
$ redis-copy --help
redis-copy v1.0.0 (with redis-rb 3.0.6)
Usage: redis-copy [options] <source> <destination>
    <source> and <destination> must be redis connection uris
    like [redis://][<username>:<password>@]<hostname>[:<port>][/<db>]

Specific options:
    -p, --pattern PATTERN            Only transfer matching keys (default *)
                                     See http://redis.io/commands/keys for more info.
    -v, --[no-]verify [PERCENT]      Verify percentage of transfers -- VERY SLOW (default 0)
    -n, --[no-]allow-nonempty        Allow non-empty destination (default false)
    -f, --[no-]fail-fast             Abort on first failure (default false)
        --[no-]pipeline              Pipeline redis commands where available (default true)
    -r, --require FILENAME           Require a script; useful for loading third-party
                                     implementations of key-emitter or copy strategies.
                                     Relative paths *must* begin with `../' or `./'.
    -d, --[no-]debug                 Write debug output (default false)
    -t, --[no-]trace                 Enable backtrace on failure (default false)
        --[no-]prompt                Prompt for confirmation (default true)
        --[no-]dry-run               Output configuration and exit
```

## Example:

```
$ redis-copy --no-prompt old.redis.host/9 new.redis.host:6380/3
Source:      redis://old.redis.host:6379/9
Destination: redis://new.redis.host:6380/3 (empty)
Key Emitter: Scan
Strategy:    DumpRestore
PROGRESS {:success=>1000, :attempt=>1000}
PROGRESS {:success=>2000, :attempt=>2000}
PROGRESS {:success=>3000, :attempt=>3000}
PROGRESS {:success=>4000, :attempt=>4000}
DONE: {:success=>4246, :attempt=>4246}
```

## Extensibility:

`RedisCopy` uses the [implements][] gem to define interfaces for key-emitter
and copy strategies, so implementations can be supplied by third-parties,
secondary gems, or even a local script; the interface shared examples are even
available on your load-path so you can ensure your implementation adheres to
the interface.

See the existing implementations and their specs for examples, and use the
`--require` command-line flag to load up your own. Since `implements` treats
last-loaded implementations as inherently better, `RedisCopy` will automatically
pick up your implementation and attempt to use it before the bundled
implementations.

[implements]: https://rubygems.org/gems/implements

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
