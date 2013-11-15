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
      self.class.name.demodulize.humanize
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
      proc = case type
             when 'string' then proc { |r| r.get key }
             when 'hash'   then proc { |r| r.hgetall key }
             when 'zset'   then proc { |r| r.zrange(key, 0, -1, :with_scores => true) }
             when 'set'    then proc { |r| r.smembers(key).sort }
             when 'list'   then proc { |r| r.lrange(key, 0, -1) }
             else
               @ui.debug("BORK: #{key.dump} has unknown type #{type.dump}!")
               return false
             end

      return false unless same_response?(&proc)
      return false unless same_response? { |r| r.ttl key }

      true
    end

    private

    def same_response?(&blk)
      responses = {
        source:      capture_result(@src, &blk),
        destination: capture_result(@dst, &blk)
      }
      if (responses[:source] == responses[:destination])
        return true
      else
        @ui.debug("MISMATCH: #{keys.dump} #{responses.inspect}")
        return false
      end
    end

    def capture_result(redis, &block)
      return [:returned, block.call(redis)]
      rescue Object => exception
      return [:raised, exception]
    end
  end
end

require_relative 'strategy/classic'
require_relative 'strategy/dump-restore'
