require 'logger'
require 'open-uri'
require 'pp'
require 'pit'
require 'optparse'
require 'cgi'
require 'net/http'
require 'pp'
require 'json'
require 'cgi'

module EightTracks
  require '8tracks/thing'
  require '8tracks/api'
  require '8tracks/mix'
  require '8tracks/set'
  require '8tracks/track'

  def self.setup(argv)
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
      opt.parse!(argv)
    }
    logger.debug $opts

    system 'mplayer >& /dev/null' or raise 'mplayer seems not installed'
  end
end
