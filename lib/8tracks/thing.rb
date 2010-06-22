module EightTracks::Thing
  def logger
    return @logger if @logger
    @logger = Logger.new STDOUT
    @logger.level = Logger::DEBUG
    @logger
  end

  def method_missing(name, *args, &block)
    if data && data.has_key?(name.to_s)
      data[name.to_s]
    else
      super
    end
  end

  def data
    @data
  end

  attr_accessor :api

  def info(data = self.data)
    data.each_key{ |key|
      logger.info "#{self.class.to_s}::#{key} = #{data[key]}"
    }
  end
end
