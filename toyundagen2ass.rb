#!/usr/bin/env ruby
# coding: utf-8

require File.dirname(__FILE__) + '/video_properties.rb'

class Gen2ASS

  StyleLine = /^%/
  GenSyllab = /&([^&\r\n]+)/
  FrmSyllab = /^(?:==)?\s*(\d+)\s+(\d+)\s*$/
  Header = <<END
[Script Info]
Title: karaoke
ScriptType: v4.00+
WrapStyle: 0
ScaledBorderAndShadow: yes
Collisions: Normal

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,20,&H00FFFFFF,&H000088EF,&H00000000,&H00666666,-1,0,0,0,100,100,0,0,1,3,0,8,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

END

  @@err = $stderr
  @@kf = "kf"
  def self.stderr= err
    @err = err
  end
  def self.karaoke_type= kf
    @@kf = kf
  end

  def seconds_to_time n
    "" <<
      (n.to_i / 3600).to_s << 
      ":" << 
      ((n.to_i % 3600) / 60).to_s <<
      ":" <<
      sprintf("%.2f", (n % 60))
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
          raise "Not enough timed syllabs?"
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

    start_delay = 100
    start = start / @fps - 1
    if start < 0
      start_delay += start * 100
      start = 0
    end

    type = "Dialogue"
    layer = 1
    start = seconds_to_time(start)
    stop = seconds_to_time(stop / @fps)
    style = "Default"
    name = ""
    marginl = marginr = marginv = "0000"
    effect = ""
    text = "{\\k#{start_delay}}" + syls.map{|i| "{\\#{@@kf}#{(i[1]/@fps*100).round}}#{i[0]}"}.join

    type + ": " + [layer, start, stop, style, name, marginl, marginr, marginv,
      effect, text].join(',') + "\n"
  end

  def nextLine
    while true
      line = @lyr.gets
      if not line
        @@err << "End of lyr file at line #{@lyr.lineno}; exiting\n"
        return nil
      end

      next if not (line =~ /^(&|--)/)

      syls = line.scan(GenSyllab)

      if syls.empty?
        @@err << "No valid syllabs in this line: \"#{line.chomp}\"\n"
        next
      end

      return syls.flatten
    end
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
      next if not times

      return times.map{|i| i.to_i}
    end
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
