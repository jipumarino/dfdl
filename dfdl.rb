#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'json'
require 'yaml'
require 'fileutils'
require 'tmpdir'

class Package
  attr_reader :release_dir, :cache_dir, :url, :filename

  def initialize(release_dir, cache_dir)
    @release_dir = release_dir
    @cache_dir = cache_dir
  end

  def choose
    list = get_list
    list.reverse.each.with_index{|n,i| puts "#{list.size-i}) #{n[:name]}"}
    index = gets.chomp.to_i - 1
    choice = list[index]
    @filename, @url = choice[:name], choice[:url]
  end

  def download
    `curl -L -C - '#{url}' -o #{cache_dir}/#{filename}`
  end

  def run
    choose
    download
    extract
  end

  protected

  def unzip(src, dest)
    `unzip #{src} -d #{dest}`
  end

  def untarbz2(src, dest)
    `tar xjf #{src} -C #{dest}`
  end
end

class BitBucketPackage < Package
  def get_list
    return @list if @list
    doc = JSON.load(open(releases_url))
    acc = doc["values"]
    if false
      while doc["next"] do
        doc = JSON.load(open(doc["next"]))
        acc.concat(doc["values"])
      end
    end
    @list = acc.select{|a| a["name"] =~ /OSX/}.map{|a| {name: a["name"], url: a["links"]["self"]["href"]}}
  end
end

class GitHubPackage < Package
  def get_list
    return @list if @list
    url = releases_url
    doc = JSON.load(open(releases_url + "?access_token=#{Config.github_token}"))
    assets = doc.flat_map{|r| r["assets"]}.select{|a| a["name"] =~ match_name}
    @list = assets.map{|a| {name: a["name"], url: a["browser_download_url"]}}
  end
end

class PyLNPPackage < BitBucketPackage
  def releases_url
    "https://api.bitbucket.org/2.0/repositories/Pidgeot/python-lnp/downloads"
  end

  def extract
    unzip("#{cache_dir}/#{filename}", release_dir)
  end
end

class DFPackage < Package
  def get_list
    return @list if @list
    doc = Nokogiri::HTML(open("http://bay12games.com/dwarves/older_versions.html"))
    hrefs = doc.xpath("//a[contains(@href,'osx')]").map{|n| n["href"]}
    @list = hrefs.map{|href| {name: href, url: "http://bay12games.com/dwarves/#{href}"}}
  end

  def extract
    untarbz2("#{cache_dir}/#{filename}", release_dir)
  end
end

class DFHackPackage < GitHubPackage
  def match_name
    /OSX/
  end

  def releases_url
    "https://api.github.com/repos/DFHack/dfhack/releases"
  end

  def extract
    untarbz2("#{cache_dir}/#{filename}", "#{release_dir}/df_osx")
  end
end

class TWBTPackage < GitHubPackage
  def match_name
    /osx/
  end

  def releases_url
    #"https://api.github.com/repos/mifki/df-twbt/releases"
    "https://api.github.com/repos/thurin/df-twbt/releases"
  end

  def extract
    unzip("#{cache_dir}/#{filename}", "#{release_dir}/twbt")
    FileUtils.mv(Dir["#{release_dir}/twbt/*.png"], "#{release_dir}/df_osx/data/art")
    FileUtils.mv(Dir["#{release_dir}/twbt/*.lua"], "#{release_dir}/df_osx/hack/lua")
    FileUtils.mv("#{release_dir}/twbt/overrides.txt", "#{release_dir}/df_osx/data/init")
    FileUtils.mv(Dir["#{release_dir}/twbt/**/*.dylib"], "#{release_dir}/df_osx/hack/plugins")
    FileUtils.rm_rf("#{release_dir}/twbt")
  end
end

class PEStarterPackPackage < Package
  def get_list
    return @list if @list
    doc = Nokogiri::HTML(open("http://df.wicked-code.com"))
    hrefs = doc.xpath("//a[contains(@href,'zip')]").map{|n| n["href"]}
    @list = hrefs.map{|href| {name: href, url: "http://df.wicked-code.com/#{href}"}}.reverse
  end

  def extract
    unzip("#{cache_dir}/#{filename}", release_dir)
    FileUtils.rm_rf(Dir["#{release_dir}/*.exe"])
    FileUtils.rm_rf(Dir["#{release_dir}/Dwarf Fortress *"])
    FileUtils.rm_rf(Dir["#{release_dir}/LNP/utilities/*"])
  end
end

module Config
  def self.load
    @config = YAML.load(open("config.yml"))
  end

  def self.github_token
    @config["github_token"]
  end
end


class Release

  attr_reader :release_dir, :cache_dir, :target_dir

  def initialize
    Config.load
    @release_dir = Dir.mktmpdir
    @cache_dir = FileUtils.mkdir_p('package_cache').first
    @target_dir = "df-" + Time.new.strftime("%Y%m%d%H%M%S")
  end

  def run_packages
    PyLNPPackage.new(release_dir, cache_dir).run
    PEStarterPackPackage.new(release_dir, cache_dir).run
    DFPackage.new(release_dir, cache_dir).run
    DFHackPackage.new(release_dir, cache_dir).run
    TWBTPackage.new(release_dir, cache_dir).run
  end

  def copy_additional_tilesets
    FileUtils.cp(Dir["tilesets/*"], "#{release_dir}/LNP/tilesets")
  end

  def setup_apps
    FileUtils.cp_r("apps/Dwarf Fortress.app", release_dir)
    FileUtils.cp("apps/Dwarf Fortress.app/Contents/Resources/df.icns", "#{release_dir}/PyLNP.app/Contents/Resources/df.icns")
    FileUtils.cp("apps/LNPInfo.plist", "#{release_dir}/PyLNP.app/Contents/Info.plist")
    FileUtils.cp("apps/remove_quarantine", "#{release_dir}/remove_quarantine")
    FileUtils.mv("#{release_dir}/PyLNP.app", "#{release_dir}/Dwarf Fortress LNP.app")
    FileUtils.touch("#{release_dir}/Dwarf Fortress LNP.app")
  end

  def setup_config
    FileUtils.cp("#{release_dir}/df_osx/dfhack.init-example", "#{release_dir}/df_osx/dfhack.init")
  end

  def move_target
    FileUtils.mv(release_dir, target_dir)
  end

  def verify_target
    if Dir.exist?(target_dir)
      puts "The target folder '#{@target_dir}' already exists. Do you want to overwrite it? (y/n)"
      choice = gets.chomp
      if choice == "y"
        FileUtils.rm_rf(target_dir)
      else
        puts "Quitting."
        exit(0)
      end
    end
  end

  def run
    verify_target
    run_packages
    copy_additional_tilesets
    setup_config
    setup_apps
    move_target
  end

end

Release.new.run
