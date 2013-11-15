# encoding: utf-8
require_relative '../../spec_helper.rb'

require 'redis-copy'
require 'redis-copy/key-emitter/interface.spec'

describe RedisCopy::KeyEmitter::Scan do
  it_should_behave_like RedisCopy::KeyEmitter
end
