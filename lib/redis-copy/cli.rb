# encoding: utf-8

require 'redis-copy'
require 'optparse'

module RedisCopy
  class CLI
    REDIS_URI = (/\A(?:redis:\/\/)?(\w*:\w+@)?([a-z0-9\-.]+)(:[0-9]{1,5})?(\/(?:(?:1[0-5])|[0-9]))?\z/i).freeze
    DEFAULTS = {
      ui:             :command_line,
      verify:         0,
      pipeline:       :true,
      fail_fast:      false,
      prompt:         true,
      trace:          false,
      debug:          false,
      allow_nonempty: false,
      pattern:        '*',
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
        opts.separator "    like [redis://][<username>:<password>@]<hostname>[:<port>][/<db>]"
        opts.separator ''
        opts.separator "Specific options:"

        opts.on('-p', '--pattern PATTERN', indent_desc[
          "Only transfer matching keys (default #{DEFAULTS[:pattern]})\n" +
          "See http://redis.io/commands/keys for more info."
        ]) do |pattern|
          options[:pattern] = pattern
        end

        opts.on('-v', '--[no-]verify [PERCENT]',
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

        opts.on('-n', '--[no-]allow-nonempty', "Allow non-empty destination (default #{DEFAULTS[:allow_nonempty]})") do |allow_nonempty|
          options[:allow_nonempty] = allow_nonempty
        end

        opts.on('-f', '--[no-]fail-fast', "Abort on first failure (default #{DEFAULTS[:fail_fast]})") do |ff|
          options[:fail_fast] = ff
        end

        opts.on('--[no-]pipeline',
          "Pipeline redis commands where available (default #{DEFAULTS[:pipeline]})"
        ) do |pipeline|
          options[:pipeline] = pipeline
        end

        opts.on('-r', '--require FILENAME', indent_desc.(
          "Require a script; useful for loading third-party\n" +
          "implementations of key-emitter or copy strategies.\n" +
          "Relative paths *must* begin with `../' or `./'.")
        ) do |script|
          begin
            script = File.expand_path(script) if script[/\A..?\//]
            require script
          rescue LoadError => e
            $stderr.puts e.message
            exit 1
          end
        end

        opts.on('-d', '--[no-]debug', "Write debug output (default #{DEFAULTS[:debug]})") do |debug|
          options[:debug] = debug
        end

        opts.on('-t', '--[no-]trace', "Enable backtrace on failure (default #{DEFAULTS[:trace]})") do |trace|
          options[:trace] = trace
        end

        opts.on('--[no-]prompt', "Prompt for confirmation (default #{DEFAULTS[:prompt]})") do |prompt|
          options[:prompt] = prompt
        end

        opts.on('--[no-]dry-run', 'Output configuration and exit') do |d|
          options[:dry_run] = true
        end

        begin
          opts.parse!(argv)
          unless argv.size == 2
            opts.abort "Source and Destination must be specified\n\n" +
                              opts.help
          end
          @source = argv.shift
          @destination = argv.shift

          opts.abort "source is not valid URI" unless @source =~ REDIS_URI
          opts.abort "destination is not valid URI" unless @destination =~ REDIS_URI
        rescue OptionParser::ParseError => error
          $stderr.puts error
          exit 1
        end
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

    def inspect
      "<#{self.class}\n" +
      "  source: #{@source}\n" +
      "  destination: #{@destination}\n" +
      "  #{@config.map{|k,v| [k,v.inspect].join(': ')}.join("\n  ")}\n/>"
    end
  end
end
