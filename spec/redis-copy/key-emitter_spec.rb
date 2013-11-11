# encoding: utf-8
require 'redis-copy'
require_relative '../spec_helper.rb'

shared_examples_for RedisCopy::KeyEmitter do
  let(:resolved_implementation) do
    begin
      instance
      true
    rescue Implements::Implementation::NotFound
      false
    end
  end
  let(:emitter_klass) { described_class }
  let(:redis) { Redis.new(REDIS_OPTIONS) }
  let(:ui) { double.as_null_object }
  let(:instance) { RedisCopy::KeyEmitter.implementation(selector).new(redis, ui) }
  let(:key_count) { 1 }
  let(:keys) { key_count.times.map{|i| i.to_s(16) } }

  before(:each) do
    unless resolved_implementation
      pending "#{emitter_klass} not supported in your environment"
    end
    key_count.times.each_slice(50) do |keys|
      kv = keys.map{|x| x.to_s(16)}.zip(keys)
      redis.mset(*kv.flatten)
    end
    ui.stub(:debug).with(anything)
  end
  after(:each) { redis.flushdb }

  context '#keys' do
    let(:key_count) { 64 }
    context 'the result' do
      subject { instance.keys }
      its(:to_a) { should =~ keys }
    end
  end

  context 'implementation resolution' do
    subject { instance }
    its(:class) { should eq described_class }
  end
end

describe RedisCopy::KeyEmitter::Keys do
  let(:selector) { :keys }
  it_should_behave_like RedisCopy::KeyEmitter do
    context '#keys' do
      context 'the supplied ui' do
        it 'should get a debug message' do
          ui.should_receive(:debug).
            with(/#{redis.client.id} KEYS \*/).
            exactly(:once)
          instance.keys
        end
        context 'when source has > 10,000 keys' do
          let(:key_count) { 10_001 }
          it 'should ask for confirmation' do
            ui.should_receive(:confirm?) do |confirmation|
              confirmation.should match /\b10,001/
            end
            instance.keys
          end
        end
        context 'when source has <= 10,000 keys' do
          let(:key_count) { 1_000 }
          it 'should not ask for confirmation' do
            ui.should_not_receive(:confirm?)
            instance.keys
          end
        end
      end
    end
  end
end

describe RedisCopy::KeyEmitter::Scan do
  let(:selector) { :scan }
  it_should_behave_like RedisCopy::KeyEmitter
end
