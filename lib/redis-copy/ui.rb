# encoding: utf-8

module RedisCopy
  module UI
    def self.load(options = {})
      ui = options.fetch(:ui, :auto_run)
      const_name = ui.to_s.camelize
      require "redis-copy/ui/#{ui}" unless const_defined?(const_name)
      const_get(const_name).new(options)
    end

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
