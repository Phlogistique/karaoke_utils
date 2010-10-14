
class String
  def basename
    sub /\.[^\.]*$/, ''
  end

  def escape_shell
    "'" + gsub("'", "'\"'\"'") + "'"
  end
end

class Array
  def basename
    map{|i|i.basename}
  end
end
