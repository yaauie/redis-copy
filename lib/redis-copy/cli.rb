# encoding: utf-8

require 'redis-copy'
require 'optparse'

module RedisCopy
  class CLI
    REDIS_URI = (/\A(?:redis:\/\/)?([a-z0-9\-.]+)(:[0-9]{1,5})?(\/(?:(?:1[0-5])|[0-9]))?\z/i).freeze
    DEFAULTS = {
      ui:             :command_line,
      key_emitter:    :auto,
      strategy:       :auto,
      verify:         0,
      pipeline:       :true,
      fail_fast:      false,
      prompt:         true,
      trace:          false,
      debug:          false,
      allow_nonempty: false,
    }.freeze unless defined?(DEFAULTS)

    def initialize(argv = ARGV)
      argv = argv.dup
      options = {}

      OptionParser.new do |opts|
        opts.version = RedisCopy::VERSION
        opts.banner = "#{opts.program_name} v#{opts.version} (with redis-rb #{Redis::VERSION})\n" +
                      "Usage: #{opts.program_name} [options] <source> <destination>"

        indent_desc = proc do |desc|
          desc.split("\n").join("\n#{opts.summary_indent}#{' '*opts.summary_width} ")
        end

        opts.separator "    <source> and <destination> must be redis connection uris"
        opts.separator "    like [redis://]<hostname>[:<port>][/<db>]"
        opts.separator ''
        opts.separator "Specific options:"

        opts.on('--strategy STRATEGY', [:auto, :new, :classic],
          indent_desc.(
            "Select strategy (auto, new, classic) (default #{DEFAULTS[:strategy]})\n" +
            "  auto:    uses new if available, otherwise fallback\n" +
            "  new:     use redis DUMP and RESTORE commands (faster)\n" +
            "  classic: migrates via multiple type-specific commands"
          )
        ) do |strategy|
          options[:strategy] = strategy
        end

        opts.on('--emitter EMITTER', [:auto, :scan, :keys],
          indent_desc.(
            "Select key emitter (auto, keys, scan) (default #{DEFAULTS[:strategy]})\n" +
            "  auto:    uses scan if available, otherwise fallback\n" +
            "  scan:    use redis SCAN command (faster, less blocking)\n" +
            "  keys:    uses redis KEYS command (dangerous, esp. on large datasets)"
          )
        ) do |emitter|
          options[:key_emitter] = emitter
        end

        opts.on('--[no-]pipeline',
          "Use redis pipeline where available (default #{DEFAULTS[:pipeline]})"
        ) do |pipeline|
          options[:pipeline] = pipeline
        end

        opts.on('-d', '--[no-]debug', "Write debug output (default #{DEFAULTS[:debug]})") do |debug|
          options[:debug] = debug
        end

        opts.on('-t', '--[no-]trace', "Enable backtrace on failure (default #{DEFAULTS[:trace]})") do |trace|
          options[:trace] = trace
        end

        opts.on('-f', '--[no-]fail-fast', "Abort on first failure (default #{DEFAULTS[:fail_fast]})") do |ff|
          options[:fail_fast] = ff
        end

        opts.on('--[no-]verify [PERCENT]',
          "Verify percentage of transfers -- VERY SLOW (default #{DEFAULTS[:verify]})"
        ) do |verify|
          options[:verify] = case verify
                             when /\A1?[0-9]{2}\z/
                               verify.to_i
                             when false, 'false', 'none'
                               0
                             else
                               100
                             end
        end

        opts.on('--[no-]prompt', "Prompt for confirmation (default #{DEFAULTS[:prompt]})") do |prompt|
          options[:prompt] = prompt
        end

        opts.on('--[no-]allow-nonempty', "Allow non-empty destination (default #{DEFAULTS[:allow_nonempty]})") do |allow_nonempty|
          options[:allow_nonempty] = allow_nonempty
        end

        opts.on('--[no-]dry-run', 'Output configuration and exit') do |d|
          options[:dry_run] = true
        end

        opts.parse!(argv)
        unless argv.size == 2
          opts.abort "Source and Destination must be specified\n\n" +
                            opts.help
        end
        @source = argv.shift
        @destination = argv.shift

        opts.abort "source is not valid URI" unless @source =~ REDIS_URI
        opts.abort "destination is not valid URI" unless @destination =~ REDIS_URI
      end

      @config = DEFAULTS.merge(options)
    end

    def run!
      (puts self.inspect; exit 1) if @config.delete(:dry_run)

      RedisCopy::copy(@source, @destination, @config)
    rescue => exception
      $stderr.puts exception.message
      $stderr.puts exception.backtrace if @config[:trace]
      exit 1
    end
  end
end
