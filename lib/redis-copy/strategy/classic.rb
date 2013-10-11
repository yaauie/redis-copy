# encoding: utf-8

module RedisCopy
  module Strategy
    class Classic
      include Strategy

      def copy(key)
        vtype = @src.type(key)
        ttl = @src.ttl(key)

        case vtype
        when 'string'
          string = @src.get(key)
          @dst.set(key, string)
        when "list"
          list = @src.lrange(key, 0, -1)
          if list.length == 0
            # Empty list special case
            maybe_pipeline(@dst) do |dst|
              dst.lpush(key, '')
              dst.lpop(key)
            end
          else
            maybe_pipeline(@dst) do |dst|
              list.each do |ele|
                dst.rpush(key, ele)
              end
            end
          end
        when "set"
          set = @src.smembers(key)
          if set.length == 0
            # Empty set special case
            maybe_pipeline(@dst) do |dst|
              dst.sadd(key, '')
              dst.srem(key, '')
            end
          else
            maybe_pipeline(@dst) do |dst|
              set.each do |ele|
                dst.sadd(key,ele)
              end
            end
          end
        when 'hash'
          hash = @src.hgetall(key)
          @dst.mapped_hmset(key, hash)
        when 'zset'
          vs_zset = @src.zrange(key, 0, -1, :with_scores => true)
          sv_zset = vs_zset.map(&:reverse)
          @dst.zadd(key, sv_zset)
        else
          return false
        end

        @dst.expire(key, ttl) unless ttl < 0 || vtype == 'none'

        return true
      end

      def maybe_pipeline(redis, &block)
        if pipeline_enabled? && redis.respond_to?(:pipelined)
          redis.pipelined(&block)
        else
          yield(redis)
        end
      end

      def pipeline_enabled?
        @pipeline_enabled ||= (false | @opt[:pipeline])
      end
    end
  end
end
