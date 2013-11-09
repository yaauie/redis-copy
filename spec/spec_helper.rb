REDIS_PORT    = 6381
REDIS_OPTIONS = { 
  :port     => REDIS_PORT, 
  :db       => 14,
  :timeout  => Float(ENV["TIMEOUT"] || 0.1),
}

class RedisMultiplex < Struct.new(:source, :destination)
  ResponseError = Class.new(RuntimeError)

  def ensure_same!(&blk)
    responses = {
      source:      capture_result(source, &blk),
      destination: capture_result(destination, &blk)
    }
    unless responses[:source] == responses[:destination]
      raise ResponseError.new(responses.to_s)
    end
    case responses[:destination].first
    when :raised then raise responses[:destination].last
    when :returned then return responses[:destination].last
    end
  end
  alias_method :both!, :ensure_same!

  def both(&blk)
    both!(&blk)
    true
  rescue ResponseError
    false
  end

  def capture_result(redis, &block)
    return [:returned, block.call(redis)]
  rescue Object => exception
    return [:raised, exception]
  end
end
