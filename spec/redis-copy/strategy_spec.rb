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

shared_examples_for(:no_ttl) do
  # key, redis,
  subject { redis.ttl(key) }
  it { should be < 0 }
end

shared_examples_for(:ttl_set) do
  # key, redis, ttl
  subject { redis.ttl(key) }
  it { should eq ttl }
end

shared_examples_for '#verify?' do
  before(:each) do
    ui.stub(:debug).and_call_original
    ui.stub(:notify) do |message|
      puts message
    end
  end
  it 'should verify successfully' do
    strategy.verify?(key).should be_true
  end
end

shared_examples_for(RedisCopy::Strategy) do
  let(:key) { rand(16**128).to_s(16) }
  after(:each) { multiplex.both { |redis| redis.del(key) } }
  let(:ttl) { 100 }

  context '#copy' do
    before(:each) { populate.call }
    context 'string' do
      let(:source_string) { rand(16**256).to_s(16) }
      let(:populate) { proc {source.set(key, source_string)} }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, ttl) } if with_expiry
          context 'before' do
            context 'source' do
              let(:redis) { source }
              subject { source.get(key) }
              it { should_not be_nil }
              it { should eq source_string }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.get(key) }
              it { should be_nil }
              it_should_behave_like :no_ttl
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              let(:redis) { source }
              subject { source.get(key) }
              it { should_not be_nil }
              it { should eq source_string }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.get(key) }
              it { should_not be_nil }
              it { should eq source_string }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            it_should_behave_like '#verify?'
          end
        end
      end
    end

    context 'list' do
      let(:source_list) do
        %w(foo bar baz buz bingo jango)
      end
      let(:populate) { proc { source_list.each{|x| source.rpush(key, x)} } }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              let(:redis) { source }
              subject { source.lrange(key, 0, -1) }
              it { should_not be_empty }
              it { should eq source_list }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.lrange(key, 0, -1) }
              it { should be_empty }
              it_should_behave_like :no_ttl
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              let(:redis) { source }
              subject { source.lrange(key, 0, -1) }
              it { should_not be_empty }
              it { should eq source_list }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.lrange(key, 0, -1) }
              it { should_not be_empty }
              it { should eq source_list }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            it_should_behave_like '#verify?'
          end
        end
      end
    end

    context 'set' do
      let(:source_list) do
        %w(foo bar baz buz bingo jango)
      end
      let(:populate) { proc { source_list.each{|x| source.sadd(key, x)} } }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              let(:redis) { source }
              subject { source.smembers(key) }
              it { should_not be_empty }
              it { should =~ source_list }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.smembers(key) }
              it { should be_empty }
              it_should_behave_like :no_ttl
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              let(:redis) { source }
              subject { source.smembers(key) }
              it { should_not be_empty }
              it { should =~ source_list }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.smembers(key) }
              it { should_not be_empty }
              it { should =~ source_list }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
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
      let(:populate) { proc { source.mapped_hmset(key, source_hash) } }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              let(:redis) { source }
              subject { source.hgetall(key) }
              it { should_not be_empty }
              it { should eq source_hash }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.hgetall(key) }
              it { should be_empty }
              it_should_behave_like :no_ttl
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              let(:redis) { source }
              subject { source.hgetall(key) }
              it { should_not be_empty }
              it { should eq source_hash }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.hgetall(key) }
              it { should_not be_empty }
              it { should eq source_hash }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            it_should_behave_like '#verify?'
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
      let(:populate) { proc { source.zadd(key, sv_source_zset) } }
      [true,false].each do |with_expiry|
        context "with_expiry(#{with_expiry})" do
          before(:each) { source.expire(key, 100) } if with_expiry
          context 'before' do
            context 'source' do
              let(:redis) { source }
              subject { source.zrange(key, 0, -1, :with_scores => true) }
              it { should_not be_empty }
              it { should =~ vs_source_zset }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.zrange(key, 0, -1, :with_scores => true) }
              it { should be_empty }
              it_should_behave_like :no_ttl
            end
          end

          context 'after' do
            before(:each) { strategy.copy(key) }
            context 'source' do
              let(:redis) { source }
              subject { source.zrange(key, 0, -1, :with_scores => true) }
              it { should_not be_empty }
              it { should =~ vs_source_zset }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            context 'destination' do
              let(:redis) { destination }
              subject { destination.zrange(key, 0, -1, :with_scores => true) }
              it { should_not be_empty }
              it { should =~ vs_source_zset }
              it_should_behave_like (with_expiry ? :ttl_set : :no_ttl)
            end
            it_should_behave_like '#verify?'
          end
        end
      end
    end
  end
end

describe RedisCopy::Strategy do
  let(:options) { Hash.new } # append using before(:each) { options.update(foo: true) }
  # let(:ui) { double.as_null_object }
  let(:ui) { RedisCopy::UI::CommandLine.new(options) }
  let(:strategy) { strategy_class.new(source, destination, ui, options)}
  let(:multiplex) { RedisMultiplex.new(source, destination) }
  let(:source) { Redis.new(db: 14) }
  let(:destination) { Redis.new(db: 15) }

  describe :New do
    let(:strategy_class) { RedisCopy::Strategy::New }
    it_should_behave_like RedisCopy::Strategy
  end
  describe :Classic do
    let(:strategy_class) { RedisCopy::Strategy::Classic }
    it_should_behave_like RedisCopy::Strategy
    context '#maybe_pipeline' do
      it 'should not pipeline' do
        source.should_not_receive(:pipelined)
        strategy.maybe_pipeline(source) { }
      end
    end

    context 'with pipeline enabled' do
      before(:each) { options.update pipeline: true }
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
