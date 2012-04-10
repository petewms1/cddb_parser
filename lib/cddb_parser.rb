#require "cddb_parser/version"
#require 'active_record'
require 'yaml'
#require_relative '../lib/db_stuff'

module CddbParser

class GetOpts
  LIST_CODES = %w[all artist info meta track]
  LIST_ABBREV = {
    'a' => 'all', 'art' => 'artist', 'i' => 'info', 'm' => 'meta', 't' => 'track'
  }

  def self.parse(args)
    #options = {}
    options = OpenStruct.new
    #options.list = 'all'
    options.verbose = false

    OptionParser.new do |opts|
      opts.banner = "Usage: cddb_parser [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-C", "--check", "check files only") do |c|
        options.check = 1
      end

      fmt_list = (LIST_ABBREV.keys + LIST_CODES).join(',')
      #fmt_list = LIST_ABBREV.each {|k,v| "#{k}/#{v}"}
      opts.on("-L", "--list [FMT]", LIST_ABBREV, LIST_CODES, "Select list format",
        "(#{fmt_list})") do |fmt|
        if options.check
          STDERR.puts "error: cannot use -L and -C together"
          exit 1
        end
        options.list = fmt.nil? ? 'all' : fmt
      end

      opts.on("-S", "--store DATABASE", "store info in database") do |s|
        if options.check
          STDERR.puts "Can't run store and check together"
          exit 1
        elsif options.list
          STDERR.puts "Can't run list and store together"
          exit 1
        end
        options.store = s
      end

      opts.separator ""
      opts.separator "Store options:"

      opts.on("-p", "--password PASSWORD", "database password") do |p|
        unless options.store
          STDERR.puts "Store option must be specified for password"
          exit 1
        end
        options.password = p
      end

      opts.on("-u", "--user USER", "database username") do |u|
        unless options.store
          STDERR.puts "Store option must be specified for user"
          exit 1
        end
        options.user = u
      end

      opts.separator ""
      opts.separator "Helper options:"

      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options.verbose = v
      end

      # Another typical switch to print the version.
      opts.on_tail("--version", "Show version") do
        puts OptionParser::Version.join('.')
        exit
      end

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

    end.parse!

    options.files = ARGV
    if options.files.empty?
      STDERR.puts "At least one CDDB file must be specified!"
      exit 1
    end
    options
  end
end # Class GetOpts

class ParseCddbFile
  def initialize(files)
    @files = []
    self.build_file_list(files)
    pp "Files: #{@files}"
    @files.sort!
  end

  def readable_file?(arg)
      File::file?(arg) && File.readable?(arg)
  end

  def build_file_list(targets)
    targets.each do |t|
      puts "file: #{t}"
      if File::directory?(t)
        puts "Expanding directory #{t}"
        self.expand_directory(t)
      elsif readable_file?(t)
        @files << t
      else
        STDERR.puts "File #{t} is invalid"
      end
    end
  end

  def expand_directory(dir)
    #Dir.glob("dir/*").each do |f|
    Dir.entries(dir).select do |f|
      file = [dir,f].join('/')
      puts "dir: #{file}"
      if readable_file?(file)
        puts "readalbe #{file}"
        @files << file
      end
    end
  end

  def check_files
    puts "Here in parsecddb check!"
    @files.each do |f|
      self.scan_file f
      exit 0
    end
  end

  def scan_file(file)
    year = ''
    genre = ''
    discid = ''
    artist_album = ''
    extd = ''
    compilation = 0
    trackmap = {'TTITLE'=>:title, 'TARTIST'=>:artist,'EXTT'=>:ext}
    tracks = Hash.new {|h,k| h[k] = {}}
    playorder = []
    trkct = 0

    File.open(file).each do |line|
      #puts "FILE: #{file}"
      line.chomp
      case line
        when /^#\s+(\d+)\s*$/
          tracks[trkct][:offset] = $1.to_i
          trkct += 1
        when /^#\s+Disc\s+length:?\s+(\d+)\s+sec/i
          disk_secs = $1
        when /^DTITLE=(.*)/
          artist_album << $1
        when /^DYEAR=(.*)/
          year = $1
          #puts "year: #{year}"
        when /^DGENRE=(.*)/
          genre = $1
          #puts "genre: #{genre}"
        when /^DID3=(\d+)/
          did = $1
        when /^DISCID=(.*)/
          discid = $1
        when /^EXTD=(.*)/
          extd << $1
        when /^(#{trackmap.keys.join("|")})(\d+)=(.*)/
          field, trackno, value = $1, $2, $3
          field = trackmap[field]
          compilation = 1 if field == 'artist'
          tracks[trackno.to_i][field] = "" if tracks[trackno.to_i][field].nil?
          tracks[trackno.to_i][field] << value
        when /^PLAYORDER=(.*)/
          playorder << $1 if $1 !~ /^\s*$/
        end
      end
      disk_artist, disk_album = artist_album.split(/\s+\/\s+/)
      if compilation == 1
        disk_artist = "Various Artists"
      else
        tracks.each do |k,v|
          if tracks[k][:artist].nil?
            tracks[k][:artist] = disk_artist
          end
        end
      end
      ref = {
        artist: disk_artist,
        album: disk_album,
        year: year,
        genre: genre,
        playorder: playorder,
        tracks: tracks
      }
      [discid, ref]
  end

  def list_files(option)
    puts "Here in parsecddb list! (#{option})"
    @files.each do |f|
      discid, ref = self.scan_file(f)
      puts YAML.dump(ref)
    end
  end

  def store_files(db, user, pw)
    puts "Here in parsecddb store! (#{db}, #{user}, #{pw})"
    @files.each do |f|
      discid, ref = self.scan_file(f)
      #puts YAML.dump(ref)
      #DbStuff::add_disk(ref)
      #conn = DbStuff::get_connection
    end
  end

end # class ParseCddbFile

end # Module CddbParser

