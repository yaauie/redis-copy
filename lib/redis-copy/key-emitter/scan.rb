# encoding: utf-8

module RedisCopy
  # Scan uses the SCAN family of commands, which were introduced in
  # the 2.8 branch of Redis, and after 3.0.5 of the redis-rb gem.
  class KeyEmitter::Scan
    implements KeyEmitter do |redis, *_|
      bin_version = Gem::Version.new(redis.info['redis_version'])
      bin_requirement = Gem::Requirement.new('>= 2.7.105')

      next false unless bin_requirement.satisfied_by?(bin_version)

      redis.respond_to?(:scan_each)
    end

    def keys
      @redis.scan_each(count: 1000, match: pattern)
    end
  end
end
