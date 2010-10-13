#!/usr/bin/env ruby1.8
# show which videos have no subs and which subs have no video in pwd

require File.dirname(__FILE__) + "/utils.rb"

avi = Dir["*.avi"]
txt = Dir["*.txt"]

puts (avi.basename - txt.basename).map{|i|i+".avi"}
puts (txt.basename - avi.basename).map{|i|i+".txt"}

