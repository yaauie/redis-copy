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
      const_name = key_emitter.to_s.camelize
      require "redis-copy/key-emitter/#{key_emitter}" unless const_defined?(const_name)
      const_get(const_name).new(redis, ui, options)
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

    def to_s
      self.class.name.demodulize.humanize
    end

    # The default strategy blindly uses `redis.keys('*')`
    class Default
      include KeyEmitter

      def initialize(redis, ui, options = {})
        ui.abort unless ui.confirm? <<-EOWARNING.strip_heredoc
          WARNING: #{self} key emitter uses redis.keys('*') to
          get its list of keys.

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
        super
      end

      def keys
        @ui.debug "REDIS: #{@redis.client.id} KEYS *"
        @redis.keys('*').to_enum
      end
    end
  end
end
