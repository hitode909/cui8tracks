class EightTracks::Track
  include EightTracks::Thing
  attr_accessor :user
  def initialize(data)
    @data = data
  end

  def user
    return @user if @user
    @user = EightTracks::User.new(@data['user'])
    @user.session = self.session
  end

  def info
    %w{ performer name release_name year url faved_by_current_user}.each{ |key|
      super(key => data[key])
    }
  end

  def escape_for_shell(path)
    escaped = path
    ' ;&()|^<>?*[]$`"\'{}'.split(//).each{|c|
      escaped.gsub!(c){ |c| '\\' + c }
    }
    escaped
  end

  def play
    if self.has_cache?
      logger.info "cache hit" if self.has_cache?
    else
      if session.config[:no_play]
        self.download
      else
        Thread.new {
          self.download
        }
      end
    end
    return true if session.config[:no_play]
    path = self.has_cache? ? self.cache_path : self.url

    cmd = "mplayer #{escape_for_shell(path)} 2> /dev/null"
    logger.debug cmd
    @io = IO.popen(cmd, 'r+')
    Thread.new {
      begin
        loop {
          s = @io.read 1
          print s if s && session.config[:verbose]
          break if s.nil?
          break if @io.closed?
        }
      ensure
        @playing = false
      end
    }
    @playing = true
  end

  def playing?
    @playing ||= false
  end

  def pause
    @io.write 'p'
  end

  def stop
    @io.write 'q'
    @playing = false
  end

  def cache_path
    'cache/' + [self.performer, self.name].join(' - ').map{ |s| s.gsub(/\//, '_')}.join(' - ') + File.extname(url)
  end

  def has_cache?
    File.size? self.cache_path
  end

  def download
    unless File.directory?('cache')
      logger.debug('make cache directory')
      Dir.mkdir('cache')
    end

    logger.info "downloading #{self.url}"
    total = nil
    open(self.cache_path, 'w') {|local|
      got = open(url,
        :content_length_proc => proc{|_total|
          total = _total
        },
        :progress_proc => proc{ |now|
          print "%3d%% #{now}/#{total}\r" % (now/total.to_f*100)
          $stdout.flush
        }
        ) {|remote|
        local.write(remote.read)
      }
    }
  rescue Exception => e
    logger.fatal "failed to download #{self.url}"
    File.unlink(self.cache_path) if File.exist?(self.cache_path)
  end

  # XXX: not working???
  %w{ toggle_fav fav unfav}.each{ |method|
    eval <<-EOS
      def #{method}
        got = api.post(path('#{method}'))
        got['track']['faved_by_current_user']
      end
    EOS
  }

end