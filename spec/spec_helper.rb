REDIS_PORT    = 6381
REDIS_OPTIONS = { 
  :port     => REDIS_PORT, 
  :db       => 14,
  :timeout  => Float(ENV["TIMEOUT"] || 0.1),
}
