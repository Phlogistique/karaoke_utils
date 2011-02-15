#!/usr/bin/env ruby
# coding: utf8

require File.dirname(__FILE__) + '/video_properties.rb'

class Gen2ASS

  StyleLine = /^%/
  GenSyllab = /&([^&\r\n]+)/
  FrmSyllab = /(\d+)\s+(\d+)/
  Header = <<END
[Script Info]
Title: karaoke
ScriptType: v4.00+
WrapStyle: 2
ScaledBorderAndShadow: yes
Collisions: Normal

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,DejaVu Sans Mono,30,&H00FFFFFF,&H0000FEEF,&H00000000,&H00666666,-1,0,0,0,100,100,0,0,1,0,1,8,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

END

  @@err = $stderr
  def seconds_to_time n
    line = ""
    line << (n.to_i / 3600).to_s 
    line << ":"
    line << ((n.to_i % 3600) / 60).to_s
    line << ":"
    line << sprintf("%.2f", (n % 60))
    line
  end

  def initialize lyr, frm, fps, out
    @out = out
    @lyr = lyr
    @frm = frm
    @fps = fps.to_f
    parse
  end

  def parse
    @out << Header
    while (@syls = nextLine)
      lineStart = nil
      sylStop = nil
      assSyls = []

      while (syl = @syls.shift)
        prevStop = sylStop
        sylStart, sylStop = nextSyllabeFrm

        unless sylStart and sylStop
          @@err << "Not enough timed syllabs???"
          return nil
        end

        lineStart ||= sylStart

        if prevStop
          i = sylStart - prevStop
          assSyls << ["", i] if 0 != i
        end
        assSyls << [syl, sylStop - sylStart]
      end
      lineStop = sylStop

      @out << formatLine(lineStart, lineStop, assSyls)
    end
  end

  def formatLine start, stop, syls
    type = "Dialogue"
    layer = 1
    start = seconds_to_time(start / @fps)
    stop = seconds_to_time(stop / @fps)
    style = "Default"
    name = ""
    marginl = marginr = marginv = "0000"
    effect = ""
    text = syls.map{|i| "{\\k#{(i[1]/@fps*100).round}}#{i[0]}"}.join

    type + ": " + [layer, start, stop, style, name, marginl, marginr, marginv,
      effect, text].join(',') + "\n"
  end

  def nextLine
    line = @lyr.gets
    if not line
      @@err << "End of lyr file at line #{@lyr.lineno}; exiting\n"
      return nil
    end

    syls = line.scan(GenSyllab)
    if syls.empty?
      @@err << "No valid syllabs in this line: \"#{line.chomp}\"\n"
      return nextLine
    end

    syls.flatten
  end

  # returns [begin, end] for the next syllab as integers
  def nextSyllabeFrm
    while true
      line = @frm.gets
      if not line
        @@err << "End of frm file at line #{@frm.lineno}; exiting\n"
        return nil
      end

      times = line.scan(FrmSyllab)[0]
      if not times
        @@err << "Invalid line in frm: \"#{line.chomp}\"\n"
        retry
      end
      break
    end
    times.map{|i| i.to_i}
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length != 3
    $stderr.puts <<END
Usage : 
    #{$PROGRAM_NAME} <lyr file> <frm file> <framerate> > <ass file>
    #{$PROGRAM_NAME} <lyr file> <frm file> <video file> > <ass file>
END
    exit
  end

  lyr = ARGV[0]
  frm = ARGV[1]
  fps = ARGV[2].to_f
  if fps == 0
    p = VideoProperties.new ARGV[2]
    fps = p.fps
  end

  Gen2ASS.new(File.open(lyr), File.open(frm), fps, $stdout)
end
