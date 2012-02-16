require 'rubygems'
require 'ramaze'
require 'shellwords'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require "tmpdir"

$karaoke_utils = File.expand_path "..", File.dirname(__FILE__)

$gen2ass= File.expand_path "toyundagen2ass.rb", $karaoke_utils
$ass2frm = File.expand_path "ass2frm.rb", $karaoke_utils
$toyundagen = File.expand_path "toyunda-gen.rb", $karaoke_utils
require $gen2ass

Encoding::default_external="BINARY" if RUBY_VERSION > "1.9"

class KaraokeTools < Ramaze::Controller
  def index
    <<-END
      <html>
        <head>
          <title>Karaoke conversion tools</title>
        </head>
        <body>
          <ul>
            <li><a href="ass_toyunda_form">ASS => Toyunda-gen</a></li>
            <li><a href="toyundagen_ass_form">Toyunda-gen => ASS</a></li>
            <li><a href="cut_kana">Lyrics -> .lyr for toyunda-gen</a></li>
          </ul>
          <p>
            You can get the tools I wrote for performing these conversions in
            <a href="http://neetwork.net/up/code/karaoke_utils/">karaoke_utils</a>
            and
            <a href="http://neetwork.net/up/code/mplayer-toyunda-lol/">mplayer-toyunda-lol</a>.
            They are written in Ruby 1.8 or 1.9 (depends on the file).
            Don't hesitate to ask me about how to use them.</p>
        </body>
      </html>
    END
  end

  def ass_toyunda_form
    %q(
      <html>
        <head>
          <title>ASS => Toyunda-gen</title>
        </head>
        <body>
          <?r if flash[:message] ?> <p><strong>#{flash[:message]}</strong></p> <?r end ?>
          <h1>ASS => Toyunda-gen</h1>
          <form method="post" action="ass_to_toyunda" enctype="multipart/form-data">
            <input type="radio" name="output_type" value="zip_frm_lyr" checked>Don't run toyunda-gen, get a zip file with .lyr and .frm<br>
            <input type="radio" name="output_type" value="zip_frm_lyr_txt">Do run toyunda-gen, get a zip file with .lyr, .frm and .txt<br>
            <input type="radio" name="output_type" value="txt">Do run toyunda-gen, only get a .txt<br><br>
            ASS file: <input type="file" name="file" size="20"><br>
            Framerate: <input type="text" name="fps" size="10"><br>
            <input type="submit">
          </form>
        </body>
      </html>
    )
  end

  def toyundagen_ass_form
    <<-END
      <html>
        <head>
          <title>Toyunda-gen => ASS</title>
        </head>
        <body>
          <?r if flash[:message] ?> <p><strong>#{flash[:message]}</strong></p> <?r end ?>
          <h1>Toyunda-gen => ASS</h1>
          <form method="post" action="toyundagen_to_ass" enctype="multipart/form-data">
            .lyr file: <input type="file" name="lyr" size="20"><br>
            .frm file: <input type="file" name="frm" size="20"> (optional)<br>
            Framerate: <input type="text" name="fps" size="10"><br>
            <input type="radio" name="karaoke_type" value="kf" checked>\\\\kf (continuous)<br>
            <input type="radio" name="karaoke_type" value="k">\\\\k (discrete)<br>
            <input type="radio" name="karaoke_type" value="hybrid">hybrid:
            <input type="text" name="t" size="5" value="0.8"><br><br>
            <input type="submit">
          </form>
          <p>You can use a .txt output by toyunda-gen for the .lyr field. If you do, you can leave the .frm field empty.</p>
        </body>
      </html>
    END
  end
  def cut_kana
    if request.post?
      @text = request[:file] ? request[:file][:tempfile].read : request[:lyrics]
      @split = split_kana(@text, request[:separator], request[:casesensitive], request[:timelong])
      if request[:output_type] == "lyr"
        name = (request[:file] ? stem(request[:file][:filename]) : "lyrics") + ".lyr"
        send_file(response, "text/plain", name, @split)
      end
    end

    %q(
      <html>
        <head>
          <title>.lyr generator</title>
        </head>
        <body>
          <?r if flash[:message] ?> <p><strong>#{flash[:message]}</strong></p> <?r end ?>
          <h1>.lyr generator</h1>
          <form method="post" action="cut_kana" enctype="multipart/form-data">
            <input type="radio" name="output_type" value="lyr" checked>Download a .lyr file<br>
            <input type="radio" name="output_type" value="inline">Just see the result<br>
            Text file with lyrics: <input type="file" name="file" size="20"><br>
            Lyrics: <br><textarea name="lyrics"><?r if @text ?>#{html_escape @text}<?r end ?></textarea><br>
            Separator: <input type="text" name="separator" size="2" value="&amp;"><br>
            <!-- <input type="radio" name="where" value="before" checked>&be&fore
            <input type="radio" name="where" value="after">af&ter&
            <input type="radio" name="where" value="between">be&tween <br> -->
            <input type="checkbox" name="casesensitive" value="casesensitive" checked>Don't touch uppercase words<br>
            <input type="checkbox" name="timelong" value="timelong" checked>Time long vowels and double consonnants as two syllabs<br>
            <input type="submit">
          </form>
          <p>Fill only one of "Text file with lyrics" and "Lyrics".</p>
          <?r if @split ?><pre>#{html_escape @split}</pre><?r end ?>
        </body>
      </html>
    )
  end

  def ass_to_toyunda
    redirect r(:ass_toyunda_form) unless request.post? 

    unless request[:file]
      flash[:message] = "No file given."
      redirect r(:ass_toyunda_form)
    end

    unless request[:fps]
      flash[:message] = "No framerate given."
      redirect r(:ass_toyunda_form)
    end

    fps = request[:fps].to_f

    if fps <= 0
      flash[:message] = "Invalid framerate given; please input a positive number."
      redirect r(:ass_toyunda_form)
    end

    case request[:output_type]
    when "zip_frm_lyr"
      run_toyundagen = false
      send_zip = true
    when "zip_frm_lyr_txt"
      run_toyundagen = true
      send_zip = true
    when "txt"
      run_toyundagen = true
      send_zip = false
    else
      run_toyundagen = false
      send_zip = true
    end

    tempfile, filename = request[:file].values_at(:tempfile, :filename)
    basename = File.basename filename
    stem = basename.sub(/\.[^\.]+$/, "")
    dir = TmpDir.new stem
    ass_path = dir.file(basename)
    log_path = dir.file("log")
    FileUtils.cp(tempfile.path, ass_path)

    call_ass2frm(ass_path, fps, log_path)

    if run_toyundagen
      frm, lyr, txt =
        ["frm", "lyr", "txt"].map{|ext| dir.file(stem + "." + ext)}
      call_toyundagen(lyr, frm, txt, log_path)
    end
    if send_zip
      send_zip_of_tmp_dir(response, dir, stem)
    else
      send_file(response, "text/plain", stem + '.txt', File.read(txt))
    end
  end

  def toyundagen_to_ass
    redirect r(:toyunda_ass_form) unless request.post?

    unless request[:lyr]
      flash[:message] = "No lyr file given."
      redirect r(:ass_toyunda_form)
    end

    fps = request[:fps].to_f
    if fps <= 0
      flash[:message] = "Invalid framerate given; please input a positive number."
      redirect r(:toyundagen_ass_form)
    end

    karaoke_type =
      case request[:karaoke_type]
        when "k" then false
        when "ks" then true
        else request[:t].to_f
      end

    lyr_tempfile, lyr_filename = request[:lyr].values_at(:tempfile, :filename)
    lyr_basename = File.basename lyr_filename
    stem = lyr_basename.sub(/\.[^\.]+$/, "")
    dir = TmpDir.new stem
    lyr_path = dir.file(lyr_basename)
    FileUtils.cp(lyr_tempfile.path, lyr_path)

    if request[:frm]
      frm_tempfile, frm_filename = request[:frm].values_at(:tempfile, :filename)
      frm_basename = File.basename frm_filename
      frm_path = dir.file(frm_basename)
      FileUtils.cp(frm_tempfile.path, frm_path)
    else
      frm_path = lyr_path
    end

    ass_path = dir.file(stem + ".ass")
    log_path = dir.file("log")

    if call_gen2ass(lyr_path, frm_path, fps, ass_path, log_path, karaoke_type)
      send_file(response, "text/ass", stem + '.ass', File.read(ass_path))
    else
      redirect r(:toyundagen_ass_form)
    end
  end

  private

  def call_gen2ass(lyr_path, frm_path, fps, ass_path, log_path, karaoke_type = true)
    lyr = File.open(lyr_path)
    frm = File.open(frm_path)
    ass = File.open(ass_path, 'w')
    log = File.open(log_path, 'a')
    begin
      Gen2ASS.new(lyr, frm, fps, ass, :err => log, :kf => karaoke_type)
      return true
    rescue Exception => e
      flash[:message] = '<pre>' +
          "Couldn't convert your file:\n\n" +
          e.message + "\n" +
          e.backtrace.join("\n") + '</pre>'
      return false
    ensure
      [log, ass, lyr, frm].each{|f| f.close}
    end
  end

  def call_ass2frm(ass_path, fps, log_path)
    command = $ass2frm + " " + ass_path.shellescape + " " + fps.to_s +
      " 1>>" + log_path.shellescape +
      " 2>>" + log_path.shellescape 
    File.open(log_path, "a") {|f| f.puts f.puts command }
    system command
  end

  def call_toyundagen(lyr, frm, txt, log_path)
    command = $toyundagen + 
      " " + lyr.shellescape +
      " " + frm.shellescape +
      " 1>" + txt.shellescape +
      " 2>>" + log_path.shellescape
    File.open(log_path, 'a') {|f| f.puts "\n\n" + command }
    system command
  end

  def send_zip_of_tmp_dir(response, tmpdir, stem)
    command = "zip -rj - #{tmpdir.dir.shellescape}"
    send_file(response, 'application/zip', stem + '.zip', %x(#{command}))
  end

  def send_file(response, type, name, contents)
    response['Content-Type'] = type
    response['Content-Disposition'] = %(attachment; filename="#{name}")
    respond contents
  end

  $kana = /(?:[kstnhmrwngzdbpjf]|ch|sh|ts)?y?[aeiuo]|[kstngzdbpc]/
  $kanai = /(?:[kstnhmrwngzdbpjf]|ch|sh|ts)?y?[aeiuo]|[kstngzdbpc]/i
  $kanal = /(?:[kstnhmrwngzdbpjf]|ch|sh|ts)*y?[aeiuo]+n?/
  $kanali = /(?:[kstnhmrwngzdbpjf]|ch|sh|ts)*y?[aeiuo]+n?/i

  def split_kana(line, separator = "|", case_sensitive = true, time_long_as_two = true)
    exp = time_long_as_two ? (case_sensitive ? $kana : $kanai) :
                             (case_sensitive ? $kanal : $kanali)
    division = /(#{exp}|\w+)|(\W+)/
    line.scan(division).map{|i| i[0] ? separator + i[0] : i[1] }.join
  end
  
  def stem name
    File.basename(name).sub(/\.[^\.]+$/, "")
  end

end

Ramaze.start
