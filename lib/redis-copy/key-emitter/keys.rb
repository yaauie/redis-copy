# encoding: utf-8

module RedisCopy
  # Keys uses the KEYS command, which has always been available in Redis,
  # but comes with a rather staunch warning to *never* use it in production.
  # This is the first-required implementation of KeyEmitter, and is thus the
  # fallback for no other emitters are available. A Warning Prompt will appear
  # if your dbsize is greater than 10,000 keys.
  class KeyEmitter::Keys
    implements KeyEmitter

    def keys
      dbsize = self.dbsize

      # HT: http://stackoverflow.com/a/11466770
      dbsize_str = dbsize.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse

      @ui.abort unless (dbsize < 10_000) || (@ui.confirm? <<-EOWARNING.strip_heredoc)
        WARNING: #{self} key emitter uses redis.keys('*') to
        get its list of keys, and you have #{dbsize_str} keys in
        your source DB.

        The redis keys command [reference](http://redis.io/commands/keys)
        says this:

        > Warning: consider KEYS as a command that should only be used
        > in production environments with extreme care. It may ruin
        > performance when it is executed against large databases.
        > This command is intended for debugging and special operations,
        > such as changing your keyspace layout. Don't use KEYS in your
        > regular application code. If you're looking for a way to find
        > keys in a subset of your keyspace, consider using sets.
      EOWARNING

      @ui.debug "REDIS: #{@redis.client.id} KEYS *"
      @redis.keys('*').to_enum
    end
  end
end
