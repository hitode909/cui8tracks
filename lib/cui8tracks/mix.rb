class CUI8Tracks::Mix
  include CUI8Tracks::Thing

  def user
    return @user if @user
    @user = CUI8Tracks::User.new(@data['user'])
    @user.session = self.session
    @user
  end

  def info
    %w{ name description user tag_list_cache restful_url plays_count liked_by_current_user}.each{ |key|
      value = case key
              when 'user'
                data[key]['slug']
              else
                data[key]
              end
      super(key => value)
    }
    notify "Playing mix #{self.name}", self.description
  end

  def id
    @data['id']
  end

  def each_track(&block)
    got = api.get("/sets/#{set.play_token}/play", {:mix_id => self.id})
    track = CUI8Tracks::Track.new(got['set']['track'])
    @track = track
    track.session = self.session
    track.mix = self
    yield track
    return if @skipped
    loop {
      got = api.get("/sets/#{set.play_token}/next", {:mix_id => self.id})
      break if got['set']['at_end']
      track = CUI8Tracks::Track.new(got['set']['track'])
      @track = track
      track.session = self.session
      yield track
      return if @skipped
    }
  end

  def skip
    @skipped = true
    @track.stop
  end

  %w{ toggle_like like unlike}.each{ |method|
    eval <<-EOS
      def #{method}
        api.post(path('#{method}'))
      end
    EOS
  }
end
