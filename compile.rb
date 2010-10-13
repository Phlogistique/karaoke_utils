#!/usr/bin/env ruby1.8
# lol I spent like two hours trying to write a makefile to do this but I forgot
# about spaces in filename so fuck GNU make

class String; def basename; sub /\..*?$/, ''; end; def escape_shell; "'" + gsub("'", "'\"'\"'") + "'"; end; end
class Array; def basename; map{|i|i.basename}; end; end

avi = Dir["*.avi"]
txt = Dir["*.txt"]

basenames = avi.basename & txt.basename
basenames.each do |name|
  ass = name + ".ass"
  avi = name + ".avi"
  txt = name + ".txt"
  next if File.exist? ass and File.ctime(ass) > File.ctime(txt) and File.ctime(ass) > File.ctime(avi)
  
  command = "ruby1.9 ../../code/mplayer-toyunda-lol/toyunda2ass.rb #{txt.escape_shell} #{avi.escape_shell} > #{ass.escape_shell}"
  puts command
  unless system command
    puts "FAILED conversion for file #{name}"
    exit 1
  end
end

