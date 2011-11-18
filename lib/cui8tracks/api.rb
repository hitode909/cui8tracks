class CUI8Tracks::API
  include CUI8Tracks::Thing

  API_KEY = '3bed6bc564136c299324e205ffaf3fa1b44f094e'

  def initialize(username, password)
    @username = username
    @password = password
    @logged_in = false
  end

  def login
    return if @logged_in
    res = post('/sessions', :login => @username, :password => @password, :https => true)
    @logged_in = true if res['logged_in']
  end

  def to_param_str(hash = { })
    raise ArgumentError, 'Argument must be a Hash object' unless hash.is_a?(Hash)
    hash.to_a.map{|i| i[0].to_s + '=' + CGI.escape(i[1].to_s) }.join('&')
  end

  def http_request(klass, path, param = { })
    path += '.json' unless path  =~ /\.json$/
    logger.debug "#{klass.to_s.split(/::/).last} #{path} #{param.inspect}"
    param[:api_key] = API_KEY
    port = param.delete(:https) ? 443 : 80 # XXX
    param_str = to_param_str(param)
    req = klass == Net::HTTP::Post ? klass.new(path) : klass.new(path + '?' + param_str)
    req.basic_auth(@username, @password) if @logged_in
    proxy_host, proxy_port = (ENV["http_proxy"] || ENV["HTTP_PROXY"] || '').sub(/http:\/\//, '').split(':')
    connection = Net::HTTP::Proxy(proxy_host, proxy_port).new('8tracks.com', port)
    connection.use_ssl = true if port == 443
    res = connection.start do |http|
      if req.kind_of? Net::HTTP::Post
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
