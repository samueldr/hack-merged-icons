#!/usr/bin/env ruby

require "fileutils"

if defined?(Encoding.default_internal)
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

include FileUtils

class Theme # {{{
  # Raw ini-like data for the icon theme
  attr_accessor :data

  # Path for the theme
  attr_accessor :path

  def initialize()
    @data = Hash.new() { |h, k| h[k] = {} }
  end

  # String values
  {
    name: "Name",
    comment: "Comment",
    example: "Example",
  }.each do |meth, key|
    define_method(meth) do
      @data["Icon Theme"][key]
    end
    define_method(:"#{meth}=") do |val|
      @data["Icon Theme"][key] = val.to_s
    end
  end

  # List of strings values
  {
    directories: "Directories",
    scaled_directories: "ScaledDirectories",
    inherits: "Inherits",
  }.each do |meth, key|
    define_method(meth) do
      return [] unless @data["Icon Theme"][key]
      @data["Icon Theme"][key].split(",")
    end
    define_method(:"#{meth}=") do |val|
      @data["Icon Theme"][key] = val.join(",")
    end
  end

  # Boolean values
  {
    hidden: "Hidden",
  }.each do |meth, key|
    define_method(meth) do
      val = @data["Icon Theme"][key]
      val ||= "false"
      val.downcase == "true"
    end
    define_method(:"#{meth}=") do |val|
      @data["Icon Theme"][key] =
        if !!val then
          "true"
        else
          "false"
        end
    end
  end

  # Returns a hash of the form:
  # {
  #   "Context/extensionless-icon-name" => [
  #     [ "/prefix/share/icons/the-theme", "/directory/icon.ext" ],
  #   ]
  # }
  def known_icons()
    @known_icons if @known_icons

    @known_icons = {}
    directories.each do |directory_name|
      dir_path = File.join(@path, directory_name)
      next unless Dir.exists?(dir_path)
      data = @data[directory_name]
      context = data["Context"]
      Dir.entries(dir_path).each do |name|
        next if name.match(/^\.\.?$/)
        next unless name.match(/(\.png|\.svg)$/)
        extensionless_icon_name = name.sub(/\.[^.]+/, "")
        name_with_context = "#{context}/#{extensionless_icon_name}"
        @known_icons[name_with_context] ||= []
        entry = [
          @path,
          File.join(dir_path, name).sub(/^#{@path}/, "")
        ]
        @known_icons[name_with_context] << entry
      end
    end
    @known_icons
  end

  def self.read(path)
    Theme.new().tap do |inst|
      inst.path = File.dirname(path)
      inst.unserialize(File.read(path))
    end
  end

  def unserialize(contents)
    # Strip comments, filter empty lines, strip beginning/end spaces
    contents = contents
      .lines
      .map {|l| l.gsub(/#.*/, "")}
      .filter {|l| !l.match(/^\s*$/)}
      .map(&:strip)
    current_category = nil
    contents.each do |line|
      if match = line.match(/^\[(.+)\]$/)
        current_category = self.data[match[1]]
      else
        raise "Assigning value without a category" unless current_category
        k, v = line.split("=", 2).map(&:strip)
        current_category[k] = v
      end
    end
  end

  def write(path)
    File.write(path, serialize())
  end

  def serialize()
    lines = []
    @data.each do |cat_name, cat_data|
      lines << "[#{cat_name}]"
      cat_data.each do |k, v|
        lines << [k, v].join("=")
      end
      lines << ""
    end

    lines.join("\n")
  end
end
# }}}

$out = ENV["out"]
$theme_name = ENV["themeName"]
$remove_legacy_icons = ENV["removeLegacyIcons"] == "1"

# Pick the given icon themes
# But skip hicolor
icon_theme_index_files =
  ENV["iconThemes"]
  .split(/\s+/)
  .map { |path| File.join(path, "index.theme") }

icon_theme_index_files.select { |path| !File.exists?(path) }.tap do |missing_themes|
  if missing_themes.length > 0
    $stderr.puts("The following theme paths are invalid (missing index.theme)")
    $stderr.puts(missing_themes.map {|path| "  - #{path}"}.join("\n"))
    exit 2
  end
end

icon_theme_index_files =
  [File.join(ENV["hicolor"], "share/icons/hicolor/index.theme")] + icon_theme_index_files

$theme_path = File.join($out, "share/icons/#{$theme_name}")


#
# Read icon themes
#

icon_themes = icon_theme_index_files.map do |index_file|
  Theme.read(index_file)
end


#
# Identify icon source
#

# We have to pick one icon source per icon name.
# Otherwise we might have a bigger-sized icon that doesn't actually match the
# smaller icons!

# Icons have to be kept per (extension-less) filename and "context".
known_icons = icon_themes.map(&:known_icons).reduce(&:merge)


#
# Merged directory contents
#

mkdir_p($theme_path)

# Create all directories we're going to symlink into
icon_themes.each do |theme|
  theme.directories.each do |dir|
    mkdir_p(File.join($theme_path, dir))
  end
end

# Given all known icons, symlink them
known_icons.values.flatten(1).each do |entry|
  theme_dir, icon_name = entry
  orig =
    begin
      File.realpath(File.join(theme_dir, icon_name))
    rescue Errno::ENOENT
      # Skip dangling links
      $stderr.puts "(Skipping dangling symlink #{File.join(theme_dir, icon_name)})"
      next
    end
  new = File.join($theme_path, icon_name)
  FileUtils.ln_s(orig, new, force: true)
end


#
# Build the index.theme for the merged icon set
#

merged_theme = Theme.new()
merged_theme.name = "Merged icons"
merged_theme.example = "folder"
merged_theme.comment = "Merged icons from: #{icon_themes.reverse.map(&:name).join(", ")}"

# This will collect all the theme data, preferring the ones listed last.
icon_themes.each do |theme|
  # Merge directories *lists*
  merged_theme.directories = (theme.directories + merged_theme.directories).uniq
  merged_theme.scaled_directories = (theme.scaled_directories + merged_theme.scaled_directories).uniq

  # Then merge directory informations
  data = theme.data.dup
  data.delete("Icon Theme")
  merged_theme.data.merge!(data)
end

# Write the new index.theme file
merged_theme.write(File.join($theme_path, "index.theme"))

# Remove legacy icons
if $remove_legacy_icons
  Dir.glob(File.join($theme_path, "**/legacy")).each do |dir|
    FileUtils.rm_r(dir)
    FileUtils.ln_s("/var/empty", dir, force: true)
  end
end
