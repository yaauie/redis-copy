# encoding: utf-8
require_relative '../../spec_helper.rb'

require 'redis-copy'
require 'redis-copy/key-emitter/interface.spec'

describe RedisCopy::KeyEmitter::Keys do
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
