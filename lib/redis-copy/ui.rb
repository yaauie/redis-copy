# encoding: utf-8

module RedisCopy
  module UI
    extend Implements::Interface

    def initialize(options)
      @options = options
    end

    def confirm?(prompt)
      return super if defined?(super)
      raise NotImplementedError
    end

    def abort(message = nil)
      return super if defined?(super)
      raise NotImplementedError
    end

    def notify(message)
      return super if defined?(super)
      raise NotImplementedError
    end

    def debug(message)
      notify(message) if @options[:debug]
    end
  end
end

# load the bundled uis:
require_relative 'ui/auto_run'
require_relative 'ui/command_line'
