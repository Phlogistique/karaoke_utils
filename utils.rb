
class String
  def cut_ext
    sub /\.[^\.]*$/, ''
  end

  def escape_shell
    "'" + gsub("'", "'\"'\"'") + "'"
  end
end

class Array
  def cut_exts
    map{|i|i.cut_ext}
  end
end
