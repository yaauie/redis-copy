# encoding: utf-8

module RedisCopy
  module Strategy
    class DumpRestore
      implements Strategy do |source, destination, *_|
        [source, destination].all? do |redis|
          bin_version = Gem::Version.new(redis.info['redis_version'])
          bin_requirement = Gem::Requirement.new('>= 2.6.0')

          next false unless bin_requirement.satisfied_by?(bin_version)

          true
        end
      end

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
    end
  end
end
