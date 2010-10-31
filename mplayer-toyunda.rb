#!/usr/bin/env ruby
# coding: utf-8
#
# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.

require 'shellwords'

$stderr.puts "THIS FILE IS OUT OF DATE, I doubt it does anything useful but you can always try."

ARGV.each{|arg|
  if File.exists?(arg) && File.exists?(txt_filename = arg.sub(/\.(avi|flv|mkv|mp4)$/, ".txt"))
    puts "TOYUNDA->ASS for file #{arg}"
    io = IO.popen %(mplayer -slave -quiet -vo null -ao null #{arg.shellescape}), "r+"
    io.puts "get_property fps"
    io.puts "get_video_resolution"
    io.puts "quit"
    while io.gets
      if $_ =~ /^ANS_fps=\d+\.\d+/
        fps = $_[/\d+\.\d+/]
      elsif $_ =~ /^ANS_VIDEO_RESOLUTION='\d+ x \d+'/
        w, h = $_.scan(/(\d+) x (\d+)/)[0]
      end
    end

    f = File.open(arg.sub(/\.(avi|mkv|flv|mp4)$/, ".ass"), "w")
    io = IO.popen("ruby #{File.dirname $0}/toyunda2ass.rb #{txt_filename.shellescape} #{fps} #{w} #{h}")
    f.puts io.read
    f.close
  end
}

exec("mplayer", *(["-ao", "null", "-ass"] + ARGV))
