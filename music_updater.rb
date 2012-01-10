require 'fileutils'
require 'rest-client'
require 'json'
require 'open-uri'
require '../constants.rb'

MUSIC_DIR = '/media/DATA/Music'
MP3_DIR = '/media/DATA/mp3'
COVER_ART = 'cover.jpg'

def get_cover_art(artist, album)
	title = album.match(/\d{4} - /) ? album.slice(7..-1) : album
	search = "#{artist} #{title}"
	puts "Getting cover art for #{search}"
	resp = RestClient.get Constants::LAST_FM_API_URL, {:params => {
		:method => 'album.search',
		:limit => 1,
		:page => 1,
		:api_key => Constants::LAST_FM_API_KEY,
		:format => 'json',
		:album => search
	}}

	result = JSON.parse(resp.to_str)
	num = result['results']['opensearch:totalResults'].to_i()

	if num > 0
		image = result['results']['albummatches']['album']['image']
		image.each do |i|
			if i['size'] == 'large'
				return i['#text']
			end
		end
	end

	puts "No album art found"
	return nil
end

puts 'Updating FLAC files'
system("/usr/bin/perl flac2mp3/flac2mp3.pl #{MUSIC_DIR} #{MP3_DIR}")

puts 'Updating MP3 files'
mp3s = `find #{MUSIC_DIR} -name '*.mp3'`.split("\n")
mp3s.each do |f|
	relative = f.slice(MUSIC_DIR.length..-1)
	new_file = MP3_DIR + relative
	FileUtils.mkdir_p(File.dirname(new_file))
	if !File.exists?(new_file)
		File.symlink(f, new_file)
	end
end

system("symlinks -dr #{MP3_DIR}")

puts 'Updating cover art'
dirs = `find #{MP3_DIR} -mindepth 2 -maxdepth 2 -type d`.split("\n")
index = MP3_DIR.split(File::SEPARATOR).size()
dirs.each do |d|
	cover_art_file = d + File::SEPARATOR + COVER_ART
	if !File.exists?(cover_art_file)
		paths = d.split(File::SEPARATOR)
		artist = paths[index]
		album = paths[index + 1]
		url = get_cover_art(artist, album)
		if !url.nil?
			image = open(url).read
			File.open(cover_art_file, 'w') {|f| f.write(image)}
		end
	end
end

