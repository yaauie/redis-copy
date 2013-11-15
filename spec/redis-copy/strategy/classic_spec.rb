# encoding: utf-8
require_relative '../../spec_helper'

require 'redis-copy'
require 'redis-copy/strategy/interface.spec'

describe RedisCopy::Strategy::Classic do
  it_should_behave_like RedisCopy::Strategy do
    context '#maybe_pipeline' do
      it 'should not pipeline' do
        source.should_not_receive(:pipelined)
        strategy.maybe_pipeline(source) { }
      end
    end

    context 'with pipeline enabled' do
      let(:options) { Hash.new(pipeline: true) }
      it_should_behave_like RedisCopy::Strategy
      context '#maybe_pipeline' do
        it 'should pipeline' do
          source.should_receive(:pipelined)
          strategy.maybe_pipeline(source) { }
        end
      end
    end
  end
end
