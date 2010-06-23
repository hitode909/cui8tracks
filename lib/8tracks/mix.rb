class EightTracks::Mix
  include EightTracks::Thing
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
    got = api.get("/sets/#{set.play_token}/play", {:mix_id => self.id})
    track = EightTracks::Track.new(got['set']['track'])
    track.session = self.session
    yield track
    loop {
      got = api.get("/sets/#{set.play_token}/next", {:mix_id => self.id})
      break if got['set']['at_end']
      track = EightTracks::Track.new(got['set']['track'])
      track.session = self.session
      yield track
    }
  end
end
