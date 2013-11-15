# encoding: utf-8

require 'redis'
require 'active_support/inflector'
require 'active_support/core_ext/string/strip' # String#strip_heredoc
require 'implements/global'

require 'redis-copy/version'
require 'redis-copy/ui'
require 'redis-copy/strategy'
require 'redis-copy/key-emitter'

module RedisCopy
  class << self
    # @param source [String]
    # @param destination [String]
    # @options options [Hash<Symbol,Object>]
    def copy(source, destination, options = {})
      ui = UI.load(options)

      source = redis_from(source)
      destination = redis_from(destination)

      ui.abort('source cannot equal destination!') if same_redis?(source, destination)

      key_emitter = KeyEmitter.new(source, ui, options)
      strategem = Strategy.new(source, destination, ui, options)

      dest_empty = !(destination.randomkey) # randomkey returns string unless db empty.

      return false unless ui.confirm? <<-EODESC.strip_heredoc
        Source:      #{source.client.id}
        Destination: #{destination.client.id} (#{dest_empty ? '' : 'NOT '}empty)
        Key Emitter: #{key_emitter}
        Strategy:    #{strategem}
      EODESC

      ui.abort('Destination not empty!') unless dest_empty or options[:allow_nonempty]

      key_emitter.keys.each_with_object(Hash.new {0}) do |key, stats|
        success = strategem.copy(key)
        stats[success ? :success : :failure] += 1
        stats[:attempt] += 1

        unless success
          ui.notify("FAIL: #{key.dump}")
          ui.abort if options[:fail_fast]
        end

        probably(options[:verify]) do
          if strategem.verify?(key)
            stats[:verified] += 1
          else
            stats[:borked] += 1
            ui.notify("BORK: #{key.dump}")
            ui.abort if options[:fail_fast]
          end
        end

        ui.notify("PROGRESS: #{stats.inspect}") if (stats[:attempt] % 1000).zero?
      end.tap do |stats|
        ui.notify("DONE: #{stats.inspect}")
      end
    rescue Implements::Implementation::NotFound => e
      ui.notify(e.to_s)
      ui.abort
    end

    private

    # yields the block, probably.
    # @param probability [Integer] 0-100
    # @return [void]
    # used by ::copy in determining whether to verify.
    def probably(probability)
      return if probability.zero?
      if probability >= 100 || (Random::rand(100) % 100) < probability
        yield
      end
    end

    def same_redis?(redis_a, redis_b)
      # Redis::Client#id returns the connection uri
      # e.g. 'redis://localhost:6379/0'
      redis_a.client.id == redis_b.client.id
    end

    def redis_from(connection_string)
      require 'uri'
      connection_string = "redis://#{connection_string}" unless connection_string.start_with?("redis://")
      uri = URI(connection_string)
      ret = {uri: uri}

      # Require the URL to have at least a host
      raise ArgumentError, "invalid url: #{connection_string}" unless uri.host

      host = uri.host
      port = uri.port if uri.port
      db = uri.path ? uri.path[1..-1].to_i : 0

      Redis.new(host: host, port: port, db: db)
    end
  end
end
