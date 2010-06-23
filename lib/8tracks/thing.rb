module EightTracks::Thing
  attr_accessor :session

  def logger
    session.logger
  end

  def api
    session.api
  end

  def set
    session.set
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

  def info(data = self.data)
    data.each_key{ |key|
      logger.info "#{self.class.to_s}::#{key} = #{data[key]}"
    }
  end

  def id
    @data['id']
  end

  def path(method = '')
    classname = self.class.to_s.split(/::/).last.downcase
    classname += 'e' if classname =~ /x$/
    classname += 's'
    "/#{classname}/#{self.id}/" + method
  end

end
