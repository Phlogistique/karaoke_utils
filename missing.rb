#!/usr/bin/env ruby1.8
# lol I spent like two hours trying to write a makefile to do this but I forgot
# about spaces in filename so fuck GNU make

class String; def basename; sub /\..*?$/, ''; end; def escape_shell; "'" + gsub("'", "'\"'\"'") + "'"; end; end
class Array; def basename; map{|i|i.basename}; end; end

avi = Dir["*.avi"]
txt = Dir["*.txt"]

puts (avi.basename - txt.basename).map{|i|i+".avi"}
puts (txt.basename - avi.basename).map{|i|i+".txt"}

