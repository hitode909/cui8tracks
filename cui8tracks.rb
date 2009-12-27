# -*- coding: utf-8 -*-
require 'open-uri'
require 'json'
require 'pp'
require 'logger'
require 'pit'
require 'optparse'

opt = OptionParser.new
$opts = { }

OptionParser.new {|opt|
  opt.on('-q QUERY', '--query') {|v| $opts[:q] = v}
  opt.on('-t TAG', '--tag')   {|v| $opts[:tag] = v}
  opt.on('-u USER', '--user')  {|v| $opts[:user] = v}
  opt.on('-s SORT', '--sort', '[recent|popular|random]')  {|v| $opts[:sort] = v}
  opt.on('--quiet')  {|v| $opts[:quiet] = v}
  opt.parse!(ARGV)
}

$logger = Logger.new STDOUT
$config = Pit.get('8tracks_api', :require => {
    'accesskey' => 'your accesskey in 8tracks api(http://developer.8tracks.com/)',
    'secretkey' => 'your secretkey in 8tracks api(http://developer.8tracks.com/)',
  })

def queries
  q = []
  %w{q tag sort}.map(&:to_sym).each{|key|
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
    "http://api.8tracks.com/users/#{$opts[:user]}/mix_feed.json"
  else
    $logger.warn "User will be ignored." if $opts[:user]
    $logger.warn "Tag will be ignored." if $opts[:tag] and $opts[:q]
    "http://api.8tracks.com/mixes.json#{queries}"
  end
end

def json(path)
  $logger.debug "get #{path}"
  JSON.parse(open(path, :http_basic_authentication => [$config['accesskey'], $config['secretkey']]).read)
end

def play(track)
  return nil if track['trackId'] == 0
  $logger.info "track: #{track['title']}"
  $logger.info "album: #{track['album']}"
  $logger.info "contributor: #{track['contributor']}"
  $logger.info "url: #{track['referenceUrl']}"
  cmd = "mplayer #{track['item']}"
  cmd += " >& /dev/null" if $opts[:quiet]
  $logger.debug cmd
  $logger.debug "p to play/pause, q to skip, C-c to exit."
  system(cmd) or return nil
  return true
end

mixes = json(mixes_path)['mixes']
set   = json("http://api.8tracks.com/sets/new.json")

mixes.each{|mix|
  $logger.info "mix: #{mix['name']}"
  $logger.info "user: #{mix['user']['slug']}"
  $logger.info "description: #{mix['description']}"
  $logger.info "url: #{mix['restful_url']}"
  play json("http://api.8tracks.com/sets/#{set['play_token']}/play.json?mix_id=#{mix['id']}")['track']
  loop {
    play(json("http://api.8tracks.com/sets/#{set['play_token']}/next.json?mix_id=#{mix['id']}")['track']) or exit
  }
}
