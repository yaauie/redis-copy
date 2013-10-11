# encoding: utf-8

require_relative 'strategy/new'
require_relative 'strategy/classic'

module RedisCopy
  module Strategy
    # @param source [Redis]
    # @param destination [Redis]
    def self.load(source, destination, ui, options = {})
      strategy = options.fetch(:strategy, :auto).to_sym
      new_compatible = [source, destination].all?(&New.method(:compatible?))
      copierklass = case strategy
                    when :classic then Classic
                    when :new
                      raise ArgumentError unless new_compatible
                      New
                    when :auto
                      new_compatible ? New : Classic
                    end
      copierklass.new(source, destination, ui, options)
    end

    # @param source [Redis]
    # @param destination [Redis]
    def initialize(source, destination, ui, options = {})
      @src = source
      @dst = destination
      @ui  = ui
      @opt = options.dup
    end

    def to_s
      self.class.name.demodulize.humanize
    end

    # @param key [String]
    # @return [Boolean]
    def copy(key)
      return super if defined? super
      raise NotImplementedError
    end
  end
end
