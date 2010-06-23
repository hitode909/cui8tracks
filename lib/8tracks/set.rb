class EightTracks::Set
  include EightTracks::Thing
  attr_accessor :per_page, :page, :sort, :user, :q, :tag
  def initialize
    # default config
    @per_page = 2
    @page = 1
    @sort = 'recent'
  end

  def info
    super(self.query)
  end

  # to access session.set.play_token
  def data
    @data ||= api.get('/sets/new')
  end

  attr_reader :total_entries
  def mixes
    got = api.get(path, query)
    @total_entries = got['total_entries']
    got['mixes'].map{|mix_data|
      mix = EightTracks::Mix.new(mix_data)
      mix.session = self.session
      mix
    }
  end

  def each_mix(&block)
    loop {
      mixes.each{ |mix|
        yield mix
      }
      @page += 1
    }
  end

  def path
    @user ? "/users/#{@user}/mix_feed" : "/mixes"
  end

  def query
    {
      :q => @q,
      :tag => @tag,
      :sort => @sort,
      :page => @page,
      :per_page => @per_page
    }.each_pair.inject({}){|a, pair|
      key, value = *pair
      a.update({key => value}) if value
      a
    }
  end
end
