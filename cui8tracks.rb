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

pit = Pit.get('8tracks_api_v2', :require => {
    'username' => 'username',
    'password' => 'password',
  })


session = EightTracks::Session.new
session.load_config(ARGV)
session.authorize(pit['username'], pit['password'])
session.start_input_thread
session.play
