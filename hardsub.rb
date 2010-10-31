#!/usr/bin/env ruby1.9
# Well this would indeed be  Makefile's work but make screws filenames with
# spaces and I don't want to learn rake.

require 'shellwords'
require 'pp'
require File.dirname(__FILE__) + "/utils.rb"
require File.dirname(__FILE__) + "/video_properties.rb"

vids = Dir["#{ARGV[0] + '/' if ARGV[0]}**/*.{avi,mkv,mp4}"]
subs = Dir["#{ARGV[0] + '/' if ARGV[0]}**/*.{ssa,ass}"]
vidsub = []
#vids.reject! {|v| v =~ /imi_shinchou/} #XXX
vids.each do |v| 
  s = subs.find { |s| v.cut_ext == s.cut_ext }
  vidsub << [v, s] if s
end

vidsub.each do |vs| v,s = vs
  t = "hardsub/" + File.basename(v).cut_ext + ".avi"
  next if File.exist? t and File.ctime(t) > File.ctime(v) and File.ctime(t) > File.ctime(s)
  fps = VideoProperties.new(v).fps_s
  v = v.shellescape
  s = s.shellescape.gsub(',', '\,')
  t = t.shellescape

  command = "mencoder #{v} -sub #{s} -ass -fontconfig -vf fixpts=fps=#{fps},ass,fixpts -ovc x264 -x264encopts frameref=8:bframes=2:8x8dct:me=umh:subq=7:nodct_decimate:trellis=2:weight_b:direct_pred=auto:crf=20 -oac mp3lame -lameopts q=1 -o #{t}"
  puts command

  unless system command
    puts "FAILED conversion for file #{name}"
    exit 1
  end

end
__END__
# vim: shiftwidth=2:expandtab
