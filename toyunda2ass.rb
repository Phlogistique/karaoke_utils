#!/usr/bin/env ruby
# coding: utf-8
# vim: shiftwidth=2:expandtab
#
# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details. */


module Conversion # from toyunda-tools/toyunda-lib.rb, I don't understand half of it but w/e
  private # y'a des constantes qui servent à rien la-dedans, non ?
  ToyundaZoomfactor = 0.64
  ToyundaLineHeightMul = 1.25
  ToyundaImageZoom = ToyundaZoomfactor * 30.85
  ToyundaAffineBase = 0
  ToyundaScreenWidth = 800
  ToyundaScreenWeight = 600
  DefaultSubSize = 30
  public
  def Conversion.str_to_x(string, subsize = 30)
    Conversion.length_to_x(string.gsub(/\{.*\}/, '').length, subsize)
  end
  def Conversion.length_to_x(length, subsize = 30)
    ((ToyundaScreenWidth / 2) - ((((ToyundaImageZoom * subsize) / 30) * length) /2) - ToyundaAffineBase).to_i
  end
  def Conversion.char_width(subsize = 30)
    (ToyundaImageZoom * subsize) / 30
  end
end

class String
  def escape_shell # there must be a less stupid way to do this
    "'" + gsub("'", "'\"'\"'") + "'"
  end
end

class VideoProperties
  attr_reader :fps, :w, :h
  def initialize video
    if File.exists? video
      io = IO.popen %(mplayer -slave -quiet -vo null -ao null #{video.escape_shell}), "r+"
      io.puts "get_property fps"
      io.puts "get_video_resolution"
      io.puts "quit"
      while io.gets
        $stderr.puts $_
        if $_ =~ /^ANS_fps=\d+\.\d+/
          @fps = $_[/\d+\.\d+/]
        elsif $_ =~ /^ANS_VIDEO_RESOLUTION='\d+ x \d+'/
          @w, @h = $_.scan(/(\d+) x (\d+)/)[0]
        end
      end
    else
      $stderr.puts "FILE NOT FOUND: #{video}"
      exit 1
    end
    
    if @fps
      @fps = @fps.to_f
    else
      $stderr.puts "WARNING: Framerate not found, set to 25fps for file #{video}"
      @fps = 25.0
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


class ToyundaToAss

  def self.convert_file filename, fps, w, h, out
    converter = self.new fps, w, h, out
    f = File.new(filename, "r:ISO-8859-1:UTF-8")
      toyunda_subs = f.read.lines
    f.close

    toyunda_subs.each {|sub| converter.convert sub}
  end

  Rx_line = /^\{(\d+)\}\{(\d+)\}(.+)/ # begin, end, text
  Rx_option = /\{(c|s|o):([^:}]+)(?::([^}]+))?\}/ # letter, begin_value, end_value # end_value is nil if there is no transition
  Rx_color = /\$?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i # a, r, g, b
  Rx_position = /(\d+),(\d+)/ # x, y

  attr_accessor :out
  def initialize fps, w, h, out
    @w = w
    @h = h
    @out = out or $stdout
    @i = 0 # layer. Putting each sub on a different layer for them to be able to overlap
    @fps = fps

    factor = (Rational(w,h) / Rational(4,3) * 100).to_i
    out.puts <<END
[Script Info]
Title: Default Aegisub file
ScriptType: v4.00+
WrapStyle: 2
ScaledBorderAndShadow: yes
Last Style Storage: Default
Collisions: Normal
!PlayResY: #{h}
!PlayResX: #{w}
PlayResY: 480
PlayResX: 640
Video Aspect Ratio: 0
!Video Zoom: 8
Video Position: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,DejaVu Sans Mono,30,&H00FFFFFF,&H0000FEEF,&H00000000,&H00666666,-1,0,0,0,#{factor},#{factor*1.00},0,0,1,0,1,8,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
END
  end

  def convert line
    out.puts "!" + line
    out.puts line_toyunda_to_ass(line)
  end

  private
  def seconds_to_time n
      line = ""
      line << (n.to_i / 3600).to_s 
      line << ":"
      line << ((n.to_i % 3600) / 60).to_s
      line << ":"
      line << sprintf("%.2f", (n % 60))
      line
  end

  def line_toyunda_to_ass line
      return "!ERROR" if not line =~ Rx_line
      t1, t2, text = line.scan(Rx_line).flatten
      marginL = "0000"
      marginV = "0000"
      type = "Dialogue"

      text = text_toyunda_to_ass text

      type + ": "                           +
        (@i += 1).to_s                      +
        ","                                 +
        seconds_to_time(t1.to_i / @fps).to_s +
        ","                                 +
        seconds_to_time(t2.to_i / @fps).to_s +
        ",Default,,"                        +
        marginL.to_s                        +
        ",0000,"                            +
        marginV.to_s                        +
        #",,{\\pos(0,0)}"                     +
        ",,"                                +
        text
  end

  def text_toyunda_to_ass text
    # replacing every space with an insecable space in order for it to be 
    # treated as a normal character
    scale_long_line(text).
      gsub(" "," ").
      gsub("|"," \\n").
      gsub(Rx_option) { |option| option_toyunda_to_ass option }.
      gsub("ÿ", '{\c&H0000FFH\3c&H000000H\shad0\bord2\p1}' +
           'm 20.0 10.0 b 20.0 15.5 15.5 20.0 10.0 20.0 b 4.5 20.0 0.0 15.5 ' +
           '0.0 10.0 b 0.0 4.5 4.5 0.0 10.0 0.0 b 15.5 0.0 20.0 4.5 20.0 10.0' +
           '{\p0}')
  end

  def option_toyunda_to_ass option
    letter, begin_value, end_value = option.scan(Rx_option)[0]
    case letter
    when "o"
      return move_toyunda_to_ass(begin_value, end_value) if end_value
      begin_value = position_toyunda_to_ass begin_value
    when "c"
      begin_value = color_toyunda_to_ass begin_value
      end_value = color_toyunda_to_ass end_value if end_value
    when "s"
      begin_value = size_toyunda_to_ass begin_value
      end_value = size_toyunda_to_ass end_value if end_value
    end
    end_value ? "{#{begin_value}\\t(#{end_value})}" : "{#{begin_value}}"
  end

  def color_toyunda_to_ass color
    a,r,g,b = color.scan(Rx_color)[0]
    a = (0xFF - a.to_i(16)).to_s(16)
    "\\c&H#{r+g+b}&\\alpha&H#{a}&" 
  end

  def size_toyunda_to_ass size
    '\fs' + size
  end

  def position_toyunda_to_ass position
    x, y = position.scan(Rx_position)[0]
    "\\pos(#{x},#{y})"
  end

  def move_toyunda_to_ass(begin_value, end_value)
    x1, y1 = begin_value.scan(Rx_position)[0]
    x2, y2 = end_value.scan(Rx_position)[0]
    "{\\move(#{x1},#{y1},#{x2},#{y2})}"
  end


  def scale_long_line long_line, max = 40
    long_line.split("|").map{|line|
      len = line.gsub(/\{[^\}]+\}/,"").length
      if len > 40
        size = (30.0 / len * 40).floor
        $stderr.puts "WARNING: Long line \"#{line}\", scaling it down to size #{size}"
        '{\fs' + size.to_s + '}' + line
      else
        line
      end
    }.join("|")
  end

end

if $PROGRAM_NAME == __FILE__
  if ARGV.length != 2 && ARGV.length != 4
    $stderr.puts <<END
Usage : 
    #{$PROGRAM_NAME} <toyunda file> <framerate> <x resolution> <y resolution> > <ass file>
    #{$PROGRAM_NAME} <toyunda file> <video file> > <ass file>
END
    exit
  end

  filename = ARGV[0]
  if ARGV.length == 2
    p = VideoProperties.new ARGV[1]
    fps = p.fps
    w = p.w
    h = p.h
  else
    fps = ARGV[1].to_f
    w = ARGV[2].to_i
    h = ARGV[3].to_i
  end

  ToyundaToAss::convert_file(filename, fps, w, h, $stdout)
end

 
