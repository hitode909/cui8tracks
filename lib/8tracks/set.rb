class EightTracks::Set
  include EightTracks::Thing
  attr_accessor :per_page, :page, :sort, :user, :q, :tag
  def initialize(api)
    @api = api
    @per_page = 2
    @page = 1
    @sort = 'recent'
  end

  def info
    super(self.query)
  end

  def data
    @data ||= @api.get('/sets/new')
  end

  def mixes
    @api.get(path, query)['mixes'].map{|mix_data|
      mix = EightTracks::Mix.new(mix_data)
      mix.api = @api
      mix.set = self
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
