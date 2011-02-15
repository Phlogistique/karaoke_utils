Encoding::default_external="BINARY"

class String
  alias :read :to_s
end


class TmpDir

  require "fileutils"
  require "shellwords"
  include FileUtils

  @@basedir = "/tmp/tempdir"

  def initialize
    @name = rand(36 ** 10).to_s(36)
    @fullname = "#{@@basedir}/#{@name}"
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

__END__
def filename_wtf f
  if f.is_a? String
    f
  elsif f.is_a? StringIO
    f.orig
end
