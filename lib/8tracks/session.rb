class EightTracks::Session
  attr_accessor :api, :config, :set, :current_track, :current_mix

  def logger
    return @logger if @logger
    @logger = Logger.new STDOUT
    @logger.level = self.config[:debug] ? Logger::DEBUG : Logger::INFO
    @logger
  end

  def load_config(argv)
    opt = OptionParser.new
    @config = {:per_page => 2, :page => 1 }

    OptionParser.new {|opt|
      opt.on('-q QUERY', '--query') {|v| @config[:q] = v}
      opt.on('-t TAG', '--tag')   {|v| @config[:tag] = v}
      opt.on('-u USER', '--user')  {|v| @config[:user] = v}
      opt.on('-s SORT', '--sort', '[recent|popular|random]')  {|v| @config[:sort] = v}
      opt.on('--no-play', "don't play tracks")  {|v| @config[:no_play] = true}
      opt.on('--play_from FROM', 'play from [FROM]th mix')  {|v| @config[:play_from] = v.to_i}
      opt.on('--verbose', 'print mplayer output')  {|v| @config[:verbose] = v}
      opt.on('--debug', 'debug-mode')  {|v| @config[:debug] = v}
      opt.parse(argv)
    }
    logger.debug @config

    system 'mplayer >& /dev/null' or raise 'mplayer seems not installed'
  end

  def authorize(username, password)
    raise 'config sesms not loaded.' unless config
    @api = EightTracks::API.new(username, password)
    @api.session = self
    @api.login
  end

  def play
    @set = set = EightTracks::Set.new
    set.session = self
    %w{q tag user sort}.each{ |key|
      set.instance_variable_set('@' + key, config[key.to_sym])
    }
    current = 0
    set.each_mix{ |mix|
      @current_mix = mix
      current += 1
      next if (config[:play_from] || 0) > current
      logger.info "Playing mix #{current} / #{set.total_entries}"
      mix.info
      mix.each_track{ |track|
        @current_track = track
        logger.info "Playing track"
        track.info
        track.play
        while track.playing?
          sleep 1
        end
      }
    }
  end

  def avail_commands
    %w{ pause skip skip_mix toggle_like like unlike toggle_fav fav unfav toggle_follow follow unfollow open help exit}
  end

  def execute(command)
    case command
    when 'p'
      execute 'pause'
    when 'pause'
      logger.info 'pause'
      current_track.pause
    when 'skip'
      logger.info 'skip track'
      current_track.stop
    when 'skip_mix'
      logger.info 'skip mix'
      current_mix.skip
    when 's'
      execute 'skip'
    when 'h'
      execute 'help'
    when '?'
      execute 'help'
    when 'help'
      logger.info "available commands:"
      logger.info avail_commands
    when 'exit'
      current_track.stop
      exit

    when 'toggle_like'
      current_mix.toggle_like
      logger.info "toggled like mix"
    when 'like'
      current_mix.like
      logger.info "liked mix"
    when 'unlike'
      current_mix.unlike
      logger.info "unliked mix"

    when 'toggle_fav'
      current_track.toggle_fav
      logger.info "toggled favorite track"
    when 'fav'
      current_track.fav
      logger.info "favorited track"
    when 'unfav'
      current_track.unfav
      logger.info "unfavorited track"

    when 'toggle_follow'
      current_mix.user.toggle_follow
      logger.info "toggled follow user"
    when 'follow'
      current_mix.user.follow
      logger.info "followed user"
    when 'unfollow'
      current_mix.user.unfollow
      logger.info "unfollowed user"

    when 'open'
      logger.info "open current mix"
      system "open #{current_mix.restful_url}"
    else
      logger.info "unknown command: #{command}"
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
          if line.empty?
            Readline::HISTORY.pop
            next
          end
          execute line
        rescue => e
          logger.error "#{e.class}, #{e.message}"
          puts e.backtrace.join("\n")
        end
      end
    }
  end
end
