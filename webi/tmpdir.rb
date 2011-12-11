class TmpDir

  require "fileutils"
  require "shellwords"
  include FileUtils

  def TmpDir::first_suffix_available path
    fullname = nil
    i = 0
    loop do
      fullname = "#{path}#{i}"
      break unless File.exists? fullname
      i += 1
    end
    fullname
  end

  @@basedir = "/tmp/tempdir"

  def initialize(name = nil)
    if name
      @name = name
      @fullname = "#{@@basedir}/#{@name}"
      if File.exists? @fullname
        @fullname = TmpDir::first_suffix_available("#{@fullname}.")
      end
    else
      @fullname = TmpDir::first_suffix_available("#{@@basedir}/")
    end
    
    mkdir_p @fullname
  end

  def file name
    @fullname + "/" + name
  end
  
  def dir
    @fullname
  end

  def shellfile name
    file(name).shellescape
  end

  def rm
    rm_rf @fullname
  end
end
