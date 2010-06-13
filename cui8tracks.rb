#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'open-uri'
require 'json'
require 'pp'
require 'logger'
require 'pit'
require 'optparse'

opt = OptionParser.new
$opts = {:per_page => 10, :page => 1 }

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

$config = Pit.get('8tracks_api', :require => {
    'accesskey' => 'your accesskey in 8tracks api(http://developer.8tracks.com/)',
    'secretkey' => 'your secretkey in 8tracks api(http://developer.8tracks.com/)',
  })

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
    "http://api.8tracks.com/users/#{$opts[:user]}/mix_feed.json#{queries}"
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
    return 5
    return file_path
  end

  Thread.new{
    download_url_to_path(url, file_path) rescue nil
  }
  return url
end

def play(track)
  $logger.info "track: #{track['title']}"
  $logger.info "album: #{track['album']}"
  $logger.info "contributor: #{track['contributor']}"
  $logger.info "url: #{track['referenceUrl']}"
  path = prepare_file(track['item'], [track['contributor'], track['title']].map{ |s| s.gsub(/\//, '_')}.join(' - '))
  return if $opts[:no_play]
  cmd = "mplayer #{path}"
  cmd += " >& /dev/null" unless $opts[:verbose]
  $logger.debug cmd
  $logger.info "p to play/pause, q to skip, C-c to exit."
  system(cmd) or return nil
  return true
end

set   = json("http://api.8tracks.com/sets/new.json")

current = 0

loop {
  mixes = json(mixes_path)
  mixes['mixes'].each_with_index{ |mix, index|
    if $opts[:from] && current < $opts[:from]
      current += 1
      next
    end
    index = ($opts[:page] - 1) * $opts[:per_page] + index + 1
    $logger.info "index: #{index} / #{mixes['total_entries']}"
    $logger.info "mix: #{mix['name']}"
    $logger.info "user: #{mix['user']['slug']}"
    $logger.info "description: #{mix['description']}"
    $logger.info "url: #{mix['restful_url']}"
    play json("http://api.8tracks.com/sets/#{set['play_token']}/play.json?mix_id=#{mix['id']}")['track']
    loop {
      got = json("http://api.8tracks.com/sets/#{set['play_token']}/next.json?mix_id=#{mix['id']}")
      break if got['track']['trackId'] == 0
      play(got['track']) or exit
    }
    if index == mixes['total_entries']
      $opts[:page] = 0
    end
  }
  $opts[:page] += 1
}
