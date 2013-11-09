# encoding: utf-8

module RedisCopy
  # A Key emitter emits keys.
  # This is built to be an abstraction on top of
  # redis.keys('*') (implemented by RedisCopy::KeyEmitter::Default),
  # but should allow smarter implementations to be built that can handle
  # billion-key dbs without blocking on IO.
  module KeyEmitter
    def self.load(redis, ui, options = {})
      key_emitter = options.fetch(:key_emitter, :default)
      scan_compatible = Scan::compatible?(redis)
      emitklass = case key_emitter
                  when :keys then Keys
                  when :scan
                    raise ArgumentError unless scan_compatible
                    Scan
                  when :auto then scan_compatible ? Scan : Keys
                  end
      emitklass.new(redis, ui, options)
    end

    # @param redis [Redis]
    # @param options [Hash<Symbol:String>]
    def initialize(redis, ui, options = {})
      @redis    = redis
      @ui       = ui
      @options  = options
    end

    # @return [Enumerable<String>]
    def keys
      return super if defined?(super)
      raise NotImplementedError
    end

    def dbsize
      @redis.dbsize
    end

    def to_s
      self.class.name.demodulize.humanize
    end

    # The default strategy blindly uses `redis.keys('*')`
    class Keys
      include KeyEmitter

      def keys
        dbsize = self.dbsize

        # HT: http://stackoverflow.com/a/11466770
        dbsize_str = dbsize.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse

        @ui.abort unless (dbsize < 10_000) || (@ui.confirm? <<-EOWARNING.strip_heredoc)
          WARNING: #{self} key emitter uses redis.keys('*') to
          get its list of keys, and you have #{dbsize_str} keys in
          your source DB.

          The redis keys command [reference](http://redis.io/commands/keys)
          says this:

          > Warning: consider KEYS as a command that should only be used
          > in production environments with extreme care. It may ruin
          > performance when it is executed against large databases.
          > This command is intended for debugging and special operations,
          > such as changing your keyspace layout. Don't use KEYS in your
          > regular application code. If you're looking for a way to find
          > keys in a subset of your keyspace, consider using sets.
        EOWARNING

        @ui.debug "REDIS: #{@redis.client.id} KEYS *"
        @redis.keys('*').to_enum
      end

      def self.compatible?(redis)
        true
      end
    end

    class Scan
      include KeyEmitter

      def keys
        @redis.scan_each(count: 1000)
      end

      def self.compatible?(redis)
        bin_version = Gem::Version.new(redis.info['redis_version'])
        bin_requirement = Gem::Requirement.new('>= 2.7.105')

        return false unless bin_requirement.satisfied_by?(bin_version)

        redis.respond_to(:scan_each)
      end
    end
  end
end
