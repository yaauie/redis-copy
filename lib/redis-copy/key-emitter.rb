# encoding: utf-8

module RedisCopy
  # A Key emitter emits keys.
  # This is built to be an abstraction on top of
  # redis.keys('*') (implemented by RedisCopy::KeyEmitter::Default),
  # but should allow smarter implementations to be built that can handle
  # billion-key dbs without blocking on IO.
  module KeyEmitter
    extend Implements::Interface

    # @param redis [Redis]
    # @param options [Hash<Symbol:String>]
    # @option options [String] :pattern ('*')
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

    def pattern
      @pattern ||= @options.fetch(:pattern) { '*' }
    end

    def dbsize
      @redis.dbsize
    end

    def to_s
      self.class.name.demodulize
    end
  end
end

# Load the bundled key-emitters:
require_relative 'key-emitter/keys'
require_relative 'key-emitter/scan'
