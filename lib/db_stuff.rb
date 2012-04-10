require 'active_record'
require 'mysql2'

module DbStuff

#ActiveRecord::Base.logger = Logger.new(STDERR)
#ActiveRecord::Base.colorize_logging = false

def DbStuff.get_connection
  conn = ActiveRecord::Base.establish_connection(
    #:adapter => "sqlite3",
    #:dbfile  => ":memory:",
    #:database => "db/cddb"
    :adapter => "mysql2",
    :database => "cddb",
    :user => 'williams',
    :password => 'Y0urSQL!',
    :host => 'localhost'
  )
  #conn = ActiveRecord::Base.connection
  puts "connection: #{conn}"
  #if conn.active?
  #  puts "Connection to MySQL is active"
  #else
  #  puts "Connection to MySQL is inactive"
  #end
  tables = conn.tables
  puts tables
end

def create_tables
  ActiveRecord::Schema.define do
    create_table :albums do |t|
      t.column :title, :string
      t.column :artist, :string
      t.column :year, :integer
      t.column :genre, :string
      t.column :playorder, :string
    end

  #  create_table :artists do |t|
  #    t.column :name, :string
  #  end

    create_table :tracks do |t|
      t.column :album_id, :integer
      t.column :track_number, :integer
      t.column :title, :string
      t.column :artist, :string
      t.column :ext, :string
    end
  end
end

def add_disk(ref)
  album = Album.create(
    :album => ref[:album],
    :artist => ref[:artist],
    :year => ref[:year],
    :genre => ref[:genre],
    :playorder => ref[:playorder]
  )
  ref[:tracks].each do |t|
    album.tracks.create(
      :track_number => t,
      :title => ref[:tracks][t][:title],
      :artist => ref[:tracks][t][:artist],
      :ext => ref[:tracks][t][:ext]
    )
  end
end

class Artist < ActiveRecord::Base
  has_many :albums
  has_many :tracks
end

class Album < ActiveRecord::Base
  has_many :tracks
end

class Track < ActiveRecord::Base
  belongs_to :album
  belongs_to :artist
  has_one :artist
end

end #module DbStuff

