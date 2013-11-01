# encoding: utf-8
require 'redis-copy'

describe RedisCopy::KeyEmitter::Default do
  let(:redis) { double }
  let(:ui) { double.as_null_object }
  let(:instance) { RedisCopy::KeyEmitter::Default.new(redis, ui)}
  let(:connection_uri) { 'redis://12.34.56.78:9000/15' }
  let(:key_count) { 100_000 }

  before(:each) do
    redis.stub_chain('client.id').and_return(connection_uri)
    redis.stub(:dbsize) { key_count }
    ui.stub(:debug).with(anything)
  end

  context '#keys' do
    let(:mock_return) { ['foo:bar', 'asdf:qwer'] }
    before(:each) do
      redis.should_receive(:keys).with('*').exactly(:once).and_return(mock_return)
    end
    context 'the result' do
      subject { instance.keys }
      its(:to_a) { should eq mock_return }
    end
    context 'the supplied ui' do
      it 'should get a debug message' do
        ui.should_receive(:debug).
          with(/#{Regexp.escape(connection_uri)} KEYS \*/).
          exactly(:once)
        instance.keys
      end
      context 'when source has > 10,000 keys' do
        let(:key_count) { 100_000 }
        it 'should ask for confirmation' do
          ui.should_receive(:confirm?) do |confirmation|
            confirmation.should match /\b100,000\b/
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
