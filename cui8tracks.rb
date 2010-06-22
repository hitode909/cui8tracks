#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'open-uri'
require 'json'
require 'pp'
require 'logger'
require 'pit'
require 'optparse'
require 'cgi'

# methods
module EightTracks
  def logger
    return @logger if @logger
    @logger = Logger.new STDOUT
    @logger.level = Logger::DEBUG
    @logger
  end

  class API
    include EightTracks
    class LoginError < StandardError
    end

    def initialize(username, password)
      @username = username
      @password = password
      @logged_in = false
      login
    end

    def login
      return if @logged_in
      res = post('/sessions', :login => @username, :password => @password)
      @logged_in = true if res['logged_in']
    end

    def to_param_str(hash)
      raise ArgumentError, 'Argument must be a Hash object' unless hash.is_a?(Hash)
      hash.to_a.map{|i| i[0].to_s + '=' + CGI.escape(i[1].to_s) }.join('&')
    end

    def http_request(klass, path, param = { })
      path += '.json' unless path  =~ /\.json$/
      req = klass.new(path)
      req.basic_auth(@username, @password) if @logged_in
      param_str = to_param_str(param)
      res = Net::HTTP.start('8tracks.com', 80) do |http|
        if param_str
          http.request(req, param_str)
        else
          http.request(req)
        end
      end
      json_data = JSON.parse(res.body)
      case res.code
      when '200'
        json_data
      else
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

end

def queries
  q = []
  %w{q tag sort page per_page}.map(&:to_sym).each{|key|
    q.push("#{key}=#{$opts[key]}") if $opts[key]
  }
  q.empty? ? '' : '?' + q.join('&')
end

def mixes_path
  $logger.warn "Sort should recent, popular or random. " if $opts[:sort] and not %w{recent popular random}.include?($opts[:sort])
  if $opts[:user]
    $logger.warn "Tag will be ignored." if $opts[:tag]
    $logger.warn "Query will be ignored." if $opts[:q]
    $logger.warn "Sort will be ignored." if $opts[:sort]
    "/users/#{$opts[:user]}/mix_feed.json#{queries}"
  else
    $logger.warn "User will be ignored." if $opts[:user]
    $logger.warn "Tag will be ignored." if $opts[:tag] and $opts[:q]
    "/mixes.json#{queries}"
  end
end

def api(path)
  $api.get(path)
end

def download_url_to_path(url, file_path)
  $logger.info "downloading #{url}"
  total = nil
  open(file_path, 'w') {|local|
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
  $logger.fatal "failed to download #{url}"
  File.unlink(file_path) if File.exist?(file_path)
  raise 'failed'
end

def prepare_file(url, as = nil)
  unless File.directory?('cache')
    $logger.debug('make cache directory')
    Dir.mkdir('cache')
  end

  file_path = 'cache/' + (as ? as : url.gsub(File.extname(url), '').gsub(/[^\w]/, '_')) + File.extname(url)
  if File.exist?(file_path)
    $logger.info "has cache: #{file_path}"
    return file_path
  end

  if $opts[:no_play]
    download_url_to_path(url, file_path) rescue return nil
    sleep 5
    return file_path
  end

  Thread.new{
    download_url_to_path(url, file_path) rescue nil
  }
  return url
end

def escape_for_shell(path)
  escaped = path
  ' ;&()|^<>?*[]$`"\'{}'.split(//).each{|c|
    escaped.gsub!(c){ |c| '\\' + c }
  }
  escaped
end

def play(track)
  $logger.info "playing track"
  track.each_key{ |key|
    $logger.info "#{key}: #{track[key]}"
  }
  path = prepare_file(track['url'], [track['performer'], track['name']].map{ |s| s.gsub(/\//, '_')}.join(' - '))
  return if $opts[:no_play]
  cmd = "mplayer #{escape_for_shell(path)}"
  cmd += " >& /dev/null" unless $opts[:verbose]
  $logger.debug cmd
  $logger.info "p to play/pause, q to skip, C-c to exit."
  system(cmd) or return nil
  return true
end

# main

opt = OptionParser.new
$opts = {:per_page => 2, :page => 1 }

OptionParser.new {|opt|
  opt.on('-q QUERY', '--query') {|v| $opts[:q] = v}
  opt.on('-t TAG', '--tag')   {|v| $opts[:tag] = v}
  opt.on('-u USER', '--user')  {|v| $opts[:user] = v}
  opt.on('-s SORT', '--sort', '[recent|popular|random]')  {|v| $opts[:sort] = v}
  opt.on('--no-play', "don't play tracks")  {|v| $opts[:no_play] = true}
  opt.on('--from FROM', 'play from [FROM]th mix')  {|v| $opts[:from] = v.to_i}
  opt.on('--verbose', 'print mplayer output')  {|v| $opts[:verbose] = v}
  opt.on('--debug', 'debug-mode')  {|v| $opts[:debug] = v}
  opt.parse!(ARGV)
}

$logger = Logger.new STDOUT
$logger.level = $opts[:debug] ? Logger::DEBUG : Logger::INFO
$logger.debug $opts

system 'mplayer >& /dev/null' or raise 'mplayer seems not installed'

pit = Pit.get('8tracks_api', :require => {
    'username' => 'username',
    'password' => 'password',
  })
$api = EightTracks::API.new(pit['username'], pit['password'])

set = api("/sets/new.json")

current = 0

loop {
  mixes = api(mixes_path)
  mixes['mixes'].each_with_index{ |mix, index|
    if $opts[:from] && current < $opts[:from]
      current += 1
      next
    end
    index = ($opts[:page] - 1) * $opts[:per_page] + index + 1
    $logger.info "playing mix #{index} / #{mixes['total_entries']}"
    mix.each_key{ |key|
      value = case key
          when 'cover_urls'
            mix[key]['original']
          when 'user'
            mix[key]['slug']
          else
            mix[key]
          end
      $logger.info "#{key}: #{value}"
    }
    play api("/sets/#{set['play_token']}/play.json?mix_id=#{mix['id']}")['set']['track']
    loop {
      got = api("/sets/#{set['play_token']}/next.json?mix_id=#{mix['id']}")
      break if got['set']['at_end']
      play(got['set']['track']) or exit
    }
    if index == mixes['total_entries']
      $opts[:page] = 0
    end
  }
  $opts[:page] += 1
}
