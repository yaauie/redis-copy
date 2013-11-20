# encoding: utf-8

module RedisCopy
  module Strategy
    extend Implements::Interface

    # @param source [Redis]
    # @param destination [Redis]
    def initialize(source, destination, ui, options = {})
      @src = source
      @dst = destination
      @ui  = ui
      @opt = options.dup
    end

    def to_s
      self.class.name.demodulize
    end

    # @param key [String]
    # @return [Boolean]
    def copy(key)
      return super if defined? super
      raise NotImplementedError
    end

    def verify?(key)
      @ui.debug("VERIFY: #{key.dump}")
      type = @src.type(key)

      template = { args: [key],
                   proc: ->(x){ x },
                   test: ->(a, b) { a == b } }

      export_command = case type
                       when 'string'
                         { command: :get }
                       when 'hash'
                         { command: :hgetall }
                       when 'zset'
                         { command: :zrange,
                           args: [key, 0, -1, {with_scores: true}] }
                       when 'set'
                         { command: :smembers,
                           proc: ->(x){ x.to_set} }
                       when 'list'
                         { command: :lrange,
                           args: [key, 0, -1] }
                       else
                         @ui.debug("BORK: #{key.dump} has unknown type #{type.dump}!")
                         return false
                       end

      # account for drift, ensure within 1 of each other.
      ttl_command = {command: :ttl, test: ->(a,b){ (a - b).abs <= 1 } }

      return false unless same_response?(template.merge export_command)
      return false unless same_response?(template.merge ttl_command)

      true
    end

    private

    def same_response?(hsh)
      responses = {
        source:      capture_result(@src, hsh),
        destination: capture_result(@dst, hsh)
      }
      if (hsh[:test].call(responses[:source], responses[:destination]))
        return true
      else
        @ui.debug("MISMATCH: #{hsh.inspect} => #{responses.inspect}")
        return false
      end
    end

    def capture_result(redis, hsh)
      result = redis.send(hsh[:command], *hsh[:args])
      return hsh[:proc].call(result)
    rescue Object => exception
      return [:raised, exception]
    end
  end
end

require_relative 'strategy/classic'
require_relative 'strategy/dump-restore'
