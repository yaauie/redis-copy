# encoding: utf-8
class RedisMultiplex < Struct.new(:source, :destination)
  ResponseError = Class.new(RuntimeError)

  def ensure_same!(&blk)
    responses = {
      source:      capture_result(source, &blk),
      destination: capture_result(destination, &blk)
    }
    unless responses[:source] == responses[:destination]
      raise ResponseError.new(responses.to_s)
    end
    case responses[:destination].first
    when :raised then raise responses[:destination].last
    when :returned then return responses[:destination].last
    end
  end
  alias_method :both!, :ensure_same!

  def both(&blk)
    both!(&blk)
    true
  rescue ResponseError
    false
  end

  def capture_result(redis, &block)
    return [:returned, block.call(redis)]
  rescue Object => exception
    return [:raised, exception]
  end
end

shared_examples_for(RedisCopy::Strategy) do
  let(:ui) { double.as_null_object }
  let(:strategy) { strategy_class.new(source, destination, ui)}
  let(:source) { Redis.new(db: 14) }
  let(:destination) { Redis.new(db: 15) }
  let(:multiplex) { RedisMultiplex.new(source, destination) }
  let(:key) { rand(16**128).to_s(16) }
  after(:each) { multiplex.both { |redis| redis.del(key) } }

  context '#copy' do
    context 'string' do
      let(:source_string) { rand(16**256).to_s(16) }
      before(:each) { source.set(key, source_string) }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              subject { source.get(key) }
              it { should_not be_nil }
              it { should eq source_string }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.get(key) }
              it { should be_nil }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq -1 }
              end
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              subject { source.get(key) }
              it { should_not be_nil }
              it { should eq source_string }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.get(key) }
              it { should_not be_nil }
              it { should eq source_string }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
          end
        end
      end
    end

    context 'list' do
      let(:source_list) do
        %w(foo bar baz buz bingo jango)
      end
      before(:each) { source_list.each{|x| source.rpush(key, x)} }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              subject { source.lrange(key, 0, -1) }
              it { should_not be_empty }
              it { should eq source_list }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.lrange(key, 0, -1) }
              it { should be_empty }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq -1 }
              end
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              subject { source.lrange(key, 0, -1) }
              it { should_not be_empty }
              it { should eq source_list }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.lrange(key, 0, -1) }
              it { should_not be_empty }
              it { should eq source_list }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
          end
        end
      end
    end

    context 'set' do
      let(:source_list) do
        %w(foo bar baz buz bingo jango)
      end
      before(:each) { source_list.each{|x| source.sadd(key, x)} }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              subject { source.smembers(key) }
              it { should_not be_empty }
              it { should =~ source_list }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.smembers(key) }
              it { should be_empty }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq -1 }
              end
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              subject { source.smembers(key) }
              it { should_not be_empty }
              it { should =~ source_list }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.smembers(key) }
              it { should_not be_empty }
              it { should =~ source_list }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
          end
        end
      end
    end

    context 'hash' do
      let(:source_hash) do
        {
          'foo' => 'bar',
          'baz' => 'buz'
        }
      end
      before(:each) { source.mapped_hmset(key, source_hash) }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              subject { source.hgetall(key) }
              it { should_not be_empty }
              it { should eq source_hash }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.hgetall(key) }
              it { should be_empty }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq -1 }
              end
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              subject { source.hgetall(key) }
              it { should_not be_empty }
              it { should eq source_hash }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.hgetall(key) }
              it { should_not be_empty }
              it { should eq source_hash }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
          end
        end
      end
    end

    context 'zset' do
      let(:source_zset) do
        {
          'foo' => 1.0,
          'baz' => 2.5,
          'bar' => 1.1,
          'buz' => 2.7
        }
      end
      let(:vs_source_zset) { source_zset.to_a }
      let(:sv_source_zset) { vs_source_zset.map(&:reverse) }
      before(:each) { source.zadd(key, sv_source_zset) }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              subject { source.zrange(key, 0, -1, :with_scores => true) }
              it { should_not be_empty }
              it { should =~ vs_source_zset }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.zrange(key, 0, -1, :with_scores => true) }
              it { should be_empty }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq -1 }
              end
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              subject { source.zrange(key, 0, -1, :with_scores => true) }
              it { should_not be_empty }
              it { should =~ vs_source_zset }
              context 'ttl' do
                subject { source.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
            context 'destination' do
              subject { destination.zrange(key, 0, -1, :with_scores => true) }
              it { should_not be_empty }
              it { should =~ vs_source_zset }
              context 'ttl' do
                subject { destination.ttl(key) }
                it { should eq 100 } if with_expiry
                it { should eq -1 } unless with_expiry
              end
            end
          end
        end
      end
    end
  end
end

describe RedisCopy::Strategy do
  describe :New do
    let(:strategy_class) { RedisCopy::Strategy::New }
    it_should_behave_like RedisCopy::Strategy
  end
  describe :Classic do
    let(:strategy_class) { RedisCopy::Strategy::Classic }
    it_should_behave_like RedisCopy::Strategy
  end
end
