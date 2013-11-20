# encoding: utf-8

# The shared examples for RedisCopy::KeyEmitter are available to require
# into consuming libraries so they can verify their implementation of the
# RedisCopy::KeyEmitter interface. See the bundled specs for the bundled
# key-emitters for example usage.
if defined?(::RSpec)
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
    let(:redis) { Redis.new(REDIS_OPTIONS).tap(&:ping) }
    let(:ui) { double.as_null_object }
    let(:selector) { emitter_klass.name.underscore.dasherize } # see implements gem
    let(:instance) { RedisCopy::KeyEmitter.implementation(selector).new(redis, ui, options) }
    let(:options) { Hash.new }
    let(:key_count) { 1 }
    let(:keys) { key_count.times.map{|i| i.to_s(16) } }
    let(:glob_matcher) do
      lambda do |rglob|
        fglob = rglob.gsub('*','**')
        lambda do |key|
          File::fnmatch(fglob,key)
        end
      end
    end

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
      context 'with pattern "[139]*"' do
        let(:options) { {pattern: '[139]*'} }
        context 'the result' do
          let(:key_count) { 256 }
          subject { instance.keys }
          its(:to_a) { should =~ keys.select(&glob_matcher['[139]*']) }
        end
      end
      context 'with pattern "?[2468ace]"' do
        let(:options) { {pattern: '?[2468ace]'} }
        context 'the result' do
          let(:key_count) { 256 }
          subject { instance.keys }
          its(:to_a) { should =~ keys.select(&glob_matcher['?[2468ace]']) }
        end
      end
    end

    context 'implementation resolution' do
      subject { instance }
      its(:class) { should eq described_class }
    end
  end
else
  fail(LoadError,
       "#{__FILE__} contains shared examples for RedisCopy::KeyEmitter. " +
       "Require it in your specs, not your code.")
end
