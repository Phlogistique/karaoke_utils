#!/usr/bin/env ruby1.9
# coding: utf-8
# vim: shiftwidth=2:expandtab
#
# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.

require 'shellwords'
require File.dirname(__FILE__) + "/utils.rb"

class VideoProperties
  attr_reader :fps, :w, :h, :fps_s, :ok
  def initialize video
    if File.exists? video
      io = IO.popen %(mplayer -slave -quiet -vo null -ao null #{video.shellescape}), "r+", :encoding => "BINARY"
      io.puts "get_property fps"
      io.puts "get_video_resolution"
      io.puts "quit"
      while io.gets
        if $_ =~ /^ANS_fps=\d+\.\d+/
          @fps_s = $_[/\d+\.\d+/]
        elsif $_ =~ /^ANS_VIDEO_RESOLUTION='\d+ x \d+'/
          @w, @h = $_.scan(/(\d+) x (\d+)/)[0]
        end
      end
    else
      $stderr.puts "FILE NOT FOUND: #{video}"
      exit 1
    end
    
    if @fps_s
      @fps = @fps_s.to_f
      @ok = true
    else
      $stderr.puts "WARNING: Framerate not found, set to 25fps for file #{video}"
      @fps = 25.0
      @ok = false
    end

    if @w and @h
      @w = @w.to_f
      @h = @h.to_f
    else
      $stderr.puts "WARNING: Resolution not found, set to 800x600 for file #{video}"
      @w = 800
      @h = 600
    end
  end
end

if $PROGRAM_NAME == __FILE__
  properties = VideoProperties.new(ARGV[0])
  puts properties.fps_s
  exit 1 if not properties.ok
end

