# encoding: utf-8

module RedisCopy
  module Strategy
    class New
      include Strategy

      def copy(key)
        @ui.debug("COPY: #{key.dump}")

        ttl = @src.ttl(key)
        # TTL returns seconds, -1 means none set
        # RESTORE ttl is in miliseconds, 0 means none set
        translated_ttl = (ttl && ttl > 0) ? (ttl * 1000) : 0

        dumped_value = @src.dump(key)
        @dst.restore(key, translated_ttl, dumped_value)

        return true
      rescue Redis::CommandError => error
        @ui.debug("ERROR: #{error}")
        return false
      end

      def self.compatible?(redis)
        maj, min, *_ = redis.info['redis_version'].split('.').map(&:to_i)
        return false unless maj >= 2
        return false unless min >= 6

        return true
      end
    end
  end
end
