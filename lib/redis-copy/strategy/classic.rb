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
            @dst.lpush(key, '')
            @dst.lpop(key)
          else
            list.each do |ele|
              @dst.rpush(key, ele)
            end
          end
        when "set"
          set = @src.smembers(key)
          if set.length == 0
            # Empty set special case
            @dst.sadd(key, '')
            @dst.srem(key, '')
          else
            set.each do |ele|
              @dst.sadd(key,ele)
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
    end
  end
end
