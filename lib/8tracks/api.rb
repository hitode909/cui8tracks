class EightTracks::API
  include EightTracks::Thing

  def initialize(username, password)
    @username = username
    @password = password
    @logged_in = false
  end

  def login
    return if @logged_in
    res = post('/sessions', :login => @username, :password => @password)
    @logged_in = true if res['logged_in']
  end

  def to_param_str(hash = { })
    raise ArgumentError, 'Argument must be a Hash object' unless hash.is_a?(Hash)
    hash.to_a.map{|i| i[0].to_s + '=' + CGI.escape(i[1].to_s) }.join('&')
  end

  def http_request(klass, path, param = { })
    path += '.json' unless path  =~ /\.json$/
    logger.debug "#{klass.to_s.split(/::/).last} #{path} #{param.inspect}"
    req = klass.new(path)
    req.basic_auth(@username, @password) if @logged_in
    param_str = to_param_str(param)
    proxy_host, proxy_port = (ENV["http_proxy"] || ENV["HTTP_PROXY"] || '').sub(/http:\/\//, '').split(':')
    res = Net::HTTP::Proxy(proxy_host, proxy_port).start('8tracks.com', 80) do |http|
      if param_str
        http.request(req, param_str)
      else
        http.request(req)
      end
    end
    json_data = JSON.parse(res.body)
    logger.debug json_data.inspect
    case res.code
    when '200'
      json_data
    else
      # XXX
      pp res
      raise 'api'
    end
  end

  def get(path, param = { })
    http_request(Net::HTTP::Get, path, param)
  end

  def post(path, param = { })
    http_request(Net::HTTP::Post, path, param)
  end

end
