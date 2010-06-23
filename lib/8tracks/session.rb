class EightTracks::Session
  attr_accessor :api, :config, :set, :current_track, :current_mix

  def logger
    return @logger if @logger
    @logger = Logger.new STDOUT
    @logger.level = Logger::DEBUG if self.config[:debug]
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

  def execute(command)
    case command
    when 'p'
      execute 'pause'
    when 'pause'
      puts 'pause'
      current_track.pause
    when 'skip'
      current_track.stop
    when 's'
      execute 'skip'
    when 'toggle_like'
      p current_mix.toggle_like
    when 'like'
      p current_mix.like
    when 'unlike'
      p current_mix.unlike
    when 'toggle_fav'
      p current_track.toggle_fav
    when 'fav'
      p current_track.fav
    when 'unfav'
      p current_track.unfav
    when 'toggle_follow'
      p current_mix.user.toggle_follow
    when 'follow'
      p current_mix.user.follow
    when 'unfollow'
      p current_mix.user.unfollow
    when 'h'
      execute 'help'
    when '?'
      execute 'help'
    when 'help'
      p %w{ pause skip toggle_like like unlike toggle_fav fav unfav toggle_follow follow unfollow help exit}
    when 'exit'
      exit
    else
      puts "unknown command: #{command}"
    end
  end

  def start_input_thread
    # XXX: very poor
    Thread.new {
      begin
        print '> '
        STDOUT.flush
        while line = STDIN.gets
          execute line.chomp
          print '> '
          STDOUT.flush
        end
      rescue => e
        p e
        puts e.backtrace.join("\n")
      end
    }
  end
end