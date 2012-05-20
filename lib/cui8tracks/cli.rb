module CUI8Tracks
  class CLI
    def self.execute(stdout, arguments=[])

      puts CUI8Tracks::BANNER

      pit = Pit.get('8tracks_login', :require => {
          'username' => 'username',
          'password' => 'password',
        })

      session = CUI8Tracks::Session.new
      session.load_config(ARGV)
      session.authorize(pit['username'], pit['password'])
      session.start_input_thread
      session.play
    end
  end
end
