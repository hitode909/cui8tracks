class CUI8Tracks::Session
  attr_accessor :api, :config, :set, :current_track, :current_mix

  def logger
    return @logger if @logger
    @logger = Logger.new(".cui8tracks.log", File::WRONLY | File::APPEND | File::CREAT)
    @logger.level = self.config[:debug] ? Logger::DEBUG : Logger::INFO
    @logger
  end

  def load_config(argv)
    opt = OptionParser.new
    @config = {:per_page => 1, :page => 1 }

    OptionParser.new {|opt|
      opt.on('-q QUERY', '--query') {|v| @config[:q] = v}
      opt.on('-t TAG', '--tag')   {|v| @config[:tag] = v}
      opt.on('-u USER', '--user')  {|v| @config[:user] = v}
      opt.on('-s SORT', '--sort', '[recent|hot|popular|random]')  {|v| @config[:sort] = v}
      opt.on('--no-play', "don't play tracks")  {|v| @config[:no_play] = true}
      opt.on('--play_from FROM', 'play from [FROM]th mix')  {|v| @config[:play_from] = v.to_i}
      opt.on('--verbose', 'print mplayer output')  {|v| @config[:verbose] = v}
      opt.on('--debug', 'debug-mode')  {|v| @config[:debug] = v}
      opt.parse(argv)
    }
    logger.debug @config

    system 'mplayer > /dev/null' or raise 'mplayer seems not installed'
  end

  def authorize(username, password)
    raise 'config sesms not loaded.' unless config
    @api = CUI8Tracks::API.new(username, password)
    @api.session = self
    @api.login
  end

  def play
    @set = set = CUI8Tracks::Set.new
    set.session = self
    %w{q tag user sort}.each{ |key|
      set.instance_variable_set('@' + key, config[key.to_sym])
    }
    if config[:play_from]
      set.page = config[:play_from]
    end
    set.each_mix{ |mix|
      @current_mix = mix
      mix.info
      mix.each_track{ |track|
        @current_track = track
        logger.debug "Playing track"
        track.info
        track.play
        while track.playing?
          sleep 1
        end
      }
    }
  end
  def avail_commands
    %w{ pause skip skip_mix toggle_like like unlike toggle_fav fav unfav toggle_follow follow unfollow open info help exit}
  end

  def execute(command)
    case command
    when 'p'
      execute 'pause'
    when 'pause'
      logger.debug 'pause'
      current_track.pause
    when 'skip'
      logger.debug 'skip track'
      current_track.stop
    when 'skip_mix'
      logger.debug 'skip mix'
      current_mix.skip
    when 's'
      execute 'skip'
    when 'h'
      execute 'help'
    when '?'
      execute 'help'
    when 'help'
      logger.debug "available commands:"
      logger.debug avail_commands
    when 'exit'
      current_track.stop
      exit

    when 'toggle_like'
      current_mix.toggle_like
      logger.debug "toggled like mix"
    when 'like'
      current_mix.like
      logger.debug "liked mix"
    when 'unlike'
      current_mix.unlike
      logger.debug "unliked mix"

    when 'toggle_fav'
      current_track.toggle_fav
      logger.debug "toggled favorite track"
    when 'fav'
      current_track.fav
      logger.debug "favorited track"
    when 'unfav'
      current_track.unfav
      logger.debug "unfavorited track"

    when 'toggle_follow'
      current_mix.user.toggle_follow
      logger.debug "toggled follow user"
    when 'follow'
      current_mix.user.follow
      logger.debug "followed user"
    when 'unfollow'
      current_mix.user.unfollow
      logger.debug "unfollowed user"

    when 'open'
      logger.debug "open current mix"
      system "open #{current_mix.restful_url}"
    when 'info'
      print "Playing track >#{@current_track.name}< in mix >#{@current_mix.name}<"
    else
      logger.debug "unknown command: #{command}"
      execute 'help'
    end
  end

  def start_input_thread
    Thread.new {
      Readline.completion_proc = lambda {|input|
        avail_commands.grep(/\A#{Regexp.quote input}/)
      }
      while line = Readline.readline('> ')
        begin
          line = line.chomp.strip rescue ''
          execute line unless line.empty?
        rescue => e
          logger.error "#{e.class}, #{e.message}"
          puts e.backtrace.join("\n")
        end
      end
    }
  end
end
