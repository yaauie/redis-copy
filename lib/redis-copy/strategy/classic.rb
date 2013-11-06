# encoding: utf-8

# The Classic strategy borrows *heavily* from the utils/redis-copy.rb found
# in Redis source, which is also the inspiration for this gem.
#
# #{REDIS}/utils/redis-copy.rb - Copyright © 2009-2010 Salvatore Sanfilippo.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
#  * Neither the name of Redis nor the names of its contributors may
#    be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
module RedisCopy
  module Strategy
    class Classic
      include Strategy

      def copy(key)
        @ui.debug("COPY: #{key.dump}")
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
        when 'none'
          @ui.warn("GONE: #{key.dump}")
          return false
        else
          @ui.warn("UNKNOWN(#{vtype}): #{key.dump}")
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
