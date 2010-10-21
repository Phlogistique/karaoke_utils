#!/usr/bin/env ruby1.8
# lol I spent like two hours trying to write a makefile to do this but I forgot
# about spaces in filenames so fuck GNU make

require File.dirname(__FILE__) + "/utils.rb"

$toyunda2ass ||= ENV["TOYUNDA2ASS"]
$toyunda2ass ||= File.dirname(__FILE__) + "/../mplayer-toyunda-lol/toyunda2ass.rb"

avi = Dir["**/*.avi"]
txt = Dir["**/*.txt"]

basenames = avi.cut_exts & txt.cut_exts
basenames.each do |name|
  ass = name + ".ass"
  avi = name + ".avi"
  txt = name + ".txt"
  next if File.exist? ass and File.ctime(ass) > File.ctime(txt) and File.ctime(ass) > File.ctime(avi)
  
  command = "ruby1.9 #{$toyunda2ass} #{txt.escape_shell} #{avi.escape_shell} > #{ass.escape_shell}"
  puts command
  unless system command
    puts "FAILED conversion for file #{name}"
    exit 1
  end
end

