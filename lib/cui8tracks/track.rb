class CUI8Tracks::Track
  include CUI8Tracks::Thing
  attr_accessor :user, :mix

  def user
    return @user if @user
    @user = CUI8Tracks::User.new(@data['user'])
    @user.session = self.session
  end

  def info
    %w{ performer name release_name year url faved_by_current_user}.each{ |key|
      super(key => data[key])
    }
    notify self.name, [self.performer, self.release_name].join("\n")
  end

  def escape_for_shell(path)
    escaped = path
    ' ;&()|^<>?*[]$`"\'{}'.split(//).each{|c|
      escaped.gsub!(c){ |c| '\\' + c }
    }
    escaped
  end

  def play
    @playing = true
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

    cmd = "mplayer #{escape_for_shell(path)} #{session.config[:verbose] ? "" : "-really-quiet"} 2> /dev/null"
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
  end

  def playing?
    @playing
  end

  def pause
    @io.write 'p'
  end

  def stop
    @playing = false
    return if @io.closed?
    @io.write 'q'
  end

  def cache_directory
    File.join Dir.tmpdir, 'cui8tracks-cache',
  end

  def cache_path
    File.join cache_directory, [self.performer, self.name].map{ |s| s.gsub(/\//, '_')}.join(' - ') + File.extname(url)
  end

  def has_cache?
    File.size? self.cache_path
  end

  def download
    unless File.directory?(cache_directory)
      logger.debug('make cache directory')
      Dir.mkdir(cache_directory)
    end

    logger.info "downloading #{self.url}"
    total = nil
    from = Time.now
    open(self.cache_path, 'w') {|local|
      got = open(url,
        :content_length_proc => proc{|_total|
          total = _total
        },
        :progress_proc => proc{ |now|
          if Time.now - from > 0.2
            from = Time.now
            print "%3d%% #{now}/#{total}\r" % (now/total.to_f*100)
            $stdout.flush
          end
        }
        ) {|remote|
        local.write(remote.read)
      }
    }
  rescue Exception => e
    logger.fatal "failed to download #{self.url}"
    File.unlink(self.cache_path) if File.exist?(self.cache_path)
  end

  %w{ toggle_fav fav unfav}.each{ |method|
    eval <<-EOS
      def #{method}
        api.post(path('#{method}'))
      end
    EOS
  }

end
