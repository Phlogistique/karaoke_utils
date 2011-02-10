#!/usr/bin/env ruby1.9
# coding: utf-8
# Well this would indeed be a Makefile's work but make screws filenames with
# spaces and I don't want to learn rake.

require 'shellwords'
require 'yaml'
require File.dirname(__FILE__) + "/utils.rb"

yaml_file = 'uploads.yaml'

if File.exists? yaml_file
  vids = YAML::load_file(yaml_file)
else
  vids = []
end

added = false
Dir['**/*.{avi,mkv,mp4}'].each do |video|
  unless vids.find {|v| v["file"] == video}
    added = true
    vids << {
      "file" => video,
      "title" => video.cut_ext,
      "description" => "Timed by " + (
        assname = video.sub(/(?<=\.)[^\.]+$/, "ass")
        dir = Dir['/home/no/up/karaoke/*'].find { |dir| 
          Dir["#{dir}/**/*"].find {|name| File.basename(name) == File.basename(assname) } 
        }
        dir ? File.basename(dir) : "anonymous"
      ),
      "upload" => true,
    }
  end
end
vids.sort_by {|v| File.ctime v["file"] }
File.open(yaml_file, "w") {|f| f.print vids.to_yaml }

if added
  puts "Found some new files; please review uploads.yaml before uploading."
  exit
end

email = (ARGV[0] or (print "Email: "; gets.chomp.shellescape))
password = (ARGV[1] or (print "Password: "; gets.chomp.shellescape))
vids.each do |video|
  next if video["uploaded"]
  next unless video["upload"]
  command = "youtube-upload #{email} #{password} "
  command << video["file"].shellescape << " " << video["title"].shellescape << "' (karaoke)' "
  command << video["description"].shellescape << " Music 'karaoke, anime'"

  puts command

  success = system(command)
  if success
    video["uploaded"] = true
    File.open(yaml_file, "w") {|f| f.print vids.to_yaml }
    sleep 600
  else
    puts "FAIL upload for video " + video["title"]
    exit
  end
end

# vim: shiftwidth=2:expandtab
