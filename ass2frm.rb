#!/usr/bin/env ruby

if ARGV.length != 2
  $stderr.puts "Usage : #{$0} <name.ass> <frames per second OR video file>"
  $stderr.puts "The video file is used only to retrieve the number of frames per second."
  $stderr.puts "The scripts create an .frm and a .lyr file in the same directory as the ASS file."
  $stderr.puts "Some defaults styling attributes are added in the .lyr file, make sure to edit it to put your own. The style is NOT (yet) retrieved from the ASS file."
  exit 1
end

$regex_line = /^Dialogue: ?.*?, ?(.*?), ?(.*?), ?(.*?), ?.*?, ?.*?, ?.*?, ?.*?, ?.*?,(.*)/
$regex_style = /^Style: ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*?), ?(.*)/
$regex_time = /^(\d+):(\d+):(\d+(?:\.\d+)?)$/
$regex_delay = /^\{\\kf?(\d+)\}(?=\{)/
$regex_syllabe = /\{\\k(f?)(\d+)\}([^\{]+)/

class String
  def escape_shell # there must be a less stupid way to do this
    "'" + gsub("'", "'\"'\"'") + "'"
  end


  def color_ass_to_toyunda
    # FIXME: This is prolly all kind of wrong because the spec is retarded
    a,r,g,b = scan(/&H([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i)[0]
    #a = (0xFF - a.to_i(16)).to_s(16)
    r+g+b
  end
  
end


def get_fps(file)
  if not File.exists?(file)
    $stderr.puts "The file doesn't exist: #{file}"
    return nil
  end

  io = IO.popen %(mplayer -slave -quiet -vo null -ao null #{file.escape_shell}), "r+"
  io.puts "get_property fps"
  io.puts "quit"
  while io.gets
    if $_ =~ /^ANS_fps=\d+\.\d+/
      fps = $_[/\d+\.\d+/]
    end
  end
  return fps.to_f
end

path_ass = ARGV[0]
fps = ARGV[1].to_f
fps = get_fps(ARGV[1]) if fps.zero?
exit 1 if fps.nil?

if not path_ass =~ /\.(ass|ssa)$/
  $stderr.puts "This doesn't look like an ASS file : " + path_ass
  exit 1
end

path_frm = path_ass.sub(/\.(ass|ssa)$/, ".frm")
path_lyr = path_ass.sub(/\.(ass|ssa)$/, ".lyr")

file_frm = File.new(path_frm, "w")
file_lyr = File.new(path_lyr, "w")

ass = File.readlines(path_ass)

dialogues = ass.select{|line| line =~ $regex_line}
style_definitions = ass.select{|line| line =~ $regex_style}

$stderr.print "Unparsed lines: \n", (ass - dialogues - style_definitions).map{|l| "\t" + l}.join

styles = Hash.new
style_definitions.each do |line|
  name, fontname, fontsize, primarycolour, secondarycolour, outlinecolour,
    backcolour, bold, italic, underline, strikeout, scalex, scaley, spacing,
    angle, borderstyle, outline, shadow, alignment, marginl, marginr, marginv,
    encoding = line.scan($regex_style).flatten
  styles[name] = {
    :fontname => fontname, :fontsize => fontsize,
    :primarycolour => primarycolour, :secondarycolour => secondarycolour,
    :outlinecolour => outlinecolour, :backcolour => backcolour, :bold => bold,
    :italic => italic, :underline => underline, :strikeout => strikeout,
    :scalex => scalex, :scaley => scaley, :spacing => spacing, :angle => angle,
    :borderstyle => borderstyle, :outline => outline, :shadow => shadow,
    :alignment => alignment, :marginl => marginl, :marginr => marginr,
    :marginv => marginv, :encoding => encoding
  }
end

curr_style = nil # The line's style
continuous = nil # Does the line contain continuous karaoke? (\kf in ASS)
dialogues.each do |line|
  
  start_time, end_time, style, lyrics = line.scan($regex_line).flatten

  if style != curr_style
    curr_style = style
    file_lyr.puts "%color #{styles[style][:secondarycolour].color_ass_to_toyunda} FFFFFF #{styles[style][:primarycolour].color_ass_to_toyunda}"
    align = styles[style][:alignment].to_i
    offset = [7, 8, 9].include?(align) ? 0 :
             [4, 5, 6].include?(align) ? 4 :
             1 == align ? 6 :
             2 == align ? 8 :
             3 == align ? 9 : nil;
    file_lyr.puts "%set base_vertical_offset #{offset}"
  end

  start_time = start_time.scan($regex_time).flatten
  start_time = start_time[0].to_i * 3600 + start_time[1].to_i * 60 + start_time[2].to_f

  if lyrics =~ $regex_delay
    start_time += lyrics.scan($regex_delay)[0][0].to_i / 100.0
    lyrics.sub!($regex_delay, "")
  end

  syllabes = lyrics.scan($regex_syllabe)

  if continuous != (continuous = !!syllabes.find { |s| s[0] == "f" }) # when the style changes
    file_lyr.puts "%style " + (continuous ? "continuous" : "default")
  end

  now = start_time * fps
  syllabes.each { |s|
      file_frm.puts "#{now.round} #{(now += s[1].to_i * fps / 100).round}"
      file_lyr.print "&" + s[2]
  }
  file_lyr.puts
end

# vim: shiftwidth=2:expandtab
