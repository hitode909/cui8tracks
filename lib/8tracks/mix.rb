class EightTracks::Mix
  include EightTracks::Thing

  def user
    return @user if @user
    @user = EightTracks::User.new(@data['user'])
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

  %w{ toggle_like like unlike}.each{ |method|
    eval <<-EOS
      def #{method}
        api.post(path('#{method}'))
      end
    EOS
  }
end
