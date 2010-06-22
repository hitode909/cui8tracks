#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

self_file =
  if File.symlink?(__FILE__)
    require 'pathname'
    Pathname.new(__FILE__).realpath
  else
    __FILE__
  end
$:.unshift(File.dirname(self_file) + "/lib")

require '8tracks'
require 'pp'

pit = Pit.get('8tracks_api', :require => {
    'username' => 'username',
    'password' => 'password',
  })
api = EightTracks::API.new(pit['username'], pit['password'])

set = EightTracks::Set.new(api)

set.tag = 'house'               # should parse argv.

set.info
set.each_mix{ |mix|
  mix.info
  mix.each_track{ |track|
    track.info
    track.play
  }
}
