class EightTracks::Mix
  include EightTracks::Thing
  attr_accessor :set
  def initialize(data)
    @data = data
  end

  def info
    to_print = { }
    self.data.each_key{ |key|
      value = case key
              when 'cover_urls'
                self.data[key]['original']
              when 'user'
                self.data[key]['slug']
              else
                self.data[key]
              end
      to_print[key] = value
    }
    super(to_print)
  end

  def id
    @data['id']
  end

  def each_track(&block)
    got = @api.get("/sets/#{set.play_token}/play", {:mix_id => self.id})
    yield EightTracks::Track.new(got['set']['track'])
    loop {
      got = @api.get("/sets/#{set.play_token}/next", {:mix_id => self.id})
      break if got['set']['at_end']
      yield EightTracks::Track.new(got['set']['track'])
    }
  end
end
