
class String
  def cut_ext
    sub /\.[^\.]*$/, ''
  end
end

class Array
  def cut_exts
    map{|i|i.cut_ext}
  end
end
