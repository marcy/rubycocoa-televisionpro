# -*- coding: mule-utf-8 -*-

=begin
Copyright (c) 2005-2006 KATO Kazuyoshi <kzys@8-p.info>
This source code is released under the MIT license.
=end

require 'kconv'
require 'open-uri'
require "yaml"

$KCODE = "UTF8"

class Channel
  def initialize(number, title)
    @number = number
    @title = title

    @programs = {}
  end

  def fetch(hour)
    @programs[hour]
  end

  def << (show)
    # 5:00 - 6:00 don't regist at 6
    last = if show.last_min > 0
             show.last_hour
           else
             show.last_hour - 1
           end

    # regist
    (show.start_hour..last).each do |h|
      @programs[h] ||= []
      @programs[h] << show
    end
  end

  attr_reader :number, :title
end

class Show
  def initialize(start_hour, start_min, last_hour, last_min, title)
    @start_hour = start_hour
    @start_min = start_min
    @last_hour = last_hour
    @last_min = last_min
    @title = title
    @summary = ""
  end

  attr_accessor :summary
  
  attr_reader :title, :start_hour, :start_min, :last_hour, :last_min

  alias_method :hour, :start_hour
  alias_method :min,  :start_min
end

class GetProgram
  attr_accessor :time
  attr_writer :channel_num
  attr_reader :prefectures

  def initialize(prefecture_code="", channel_num=7)
    yml = File.join(File.dirname(__FILE__), "./prefectures.yml")
    @prefectures = YAML::load(File.read(yml))
    @time = Time.now.hour
    @channel_num = channel_num
    if prefecture_code.empty?
      read_data(prefecture_code)
    end
  end
  
  def search(key)
    result = []
    @channels.each_with_index do |ch, i|
      break if i >= @channel_num
      (5..28).each do |hour|
        ch_item = ch.fetch(hour)
        next unless ch_item
        ch_item.each_with_index do |show, i|
          next if not(show.title.index(key)) and not(show.summary.index(key))
          hash = {}
          hash[:ch_title] = ch.title
          hash[:start_time] = format("%02d:%02d", show.start_hour, show.start_min)
          hash[:end_time] = format("%02d:%02d", show.last_hour, show.last_min)
          hash[:show_title] = show.title
          hash[:summary] = show.summary
          result << hash
        end
      end
    end
    result.uniq
  end

  def prefecture_code(name)
    @prefectures[name]
  end

  def read_data(prefecture_code="")
    uri = (if prefecture_code.empty?
             "http://www.ontvjapan.com/program/gridOneday.php?"
           else
             "http://www.ontvjapan.com/program/gridOneday.php?tikicd=#{prefecture_code}"
           end)
    html = nil
    page = 1

    @channels = []
    channels_map = {}

    loop do
      # $stderr.print("Getting page #{page}...")

      data = URI(uri+"&page=#{page}").read

      html = data.toutf8

      if @channels.empty?
        # $stderr.print("Parsing channels...")
        @channels = create_channels(html)
        @channels.each do |ch|
          channels_map[ch.number] = ch
        end
      end

      # $stderr.print("Parsing page #{page}...")
      parse_programs(channels_map, html, Time.now.day)

      if html =~ NEXT_PAGE_PATTERN
        page += 1
      else
        break
      end
    end
    @channels
  end
  
  def time=(time)
    if 0 <= time and time <= 4
      @time = time + 24
    else 
      @time = time
    end
  end

  def to_a(max_ch=@channel_num)
    result = []
    @channels.each_with_index do |ch, i|
      break if i >= max_ch
      ch_item = ch.fetch(@time)
      next unless ch_item
      ch_item.each_with_index do |show, i|
        hash = {}
        hash[:ch_title] = i == 0 ? ch.title : ""
        hash[:start_time] = format("%02d:%02d", show.start_hour, show.start_min)
        hash[:end_time] = format("%02d:%02d", show.last_hour, show.last_min)
        hash[:show_title] = show.title
        hash[:summary] = show.summary
        result << hash
      end
    end
    result
  end
  
  private

  CHANNEL_PATTERN = %r{<OPTION VALUE="/program/gridOneday.php\?.+?" >(.+?)</OPTION><!--(\d{4})-->}
  TITLE_PATTERN = %r{<a .*?href="(/genre/detail.php3\?.*?&hsid=\d{4}\d{2}(\d{2})(\d{4})\d{3})" target=_self title="(\d{2}):(\d{2})-(\d{2}):(\d{2}) .*?">(.*)</a>}
  TOMMOROW_PATTERN = %r{<TD rowspan=12 class=time width="10" valign="top"><b>24</b></TD>}
  NEXT_PAGE_PATTERN = %r{<a href="/program/gridOneday\.php\?.*?&page=(\d+).*?"><IMG border=0 src="/images/grid/right.gif"</a>}

  def create_channels(html)
    result = []

    # Half
    html = html[0, html.length / 2]

    html.scan(CHANNEL_PATTERN) do
      result << Channel.new($2.to_i, $1)
    end

    result
  end

  def parse_summary(lines)
    subtitle = nil

    while ln = lines.shift
      case ln
      when %r{<span class="style_corner">(.*?)</span>}
        corner = $1
        corner = nil if corner.empty?

        return (if subtitle and corner
                  "#{subtitle}&#13;#{corner}"
                elsif subtitle or corner
                  "#{subtitle}#{corner}"
                else
                  nil
                end)
      when %r{<span class="style_subtitle">(.*?)</span>}
        subtitle = $1
      end
    end
  end

  def parse_programs(channels_map, html, today)
    tommorow = false

    lines = html.split(/\n/)

    while ln = lines.shift
      if md = ln.match(TITLE_PATTERN)
        title = md[8].gsub(/<.+?>/, '')

        summary = parse_summary(lines)
        unless summary
          summary = title
        end

        summary.gsub!(/&#.+?;/, ' ')
        # title = "<div onmouseover=\"showSummary(this, event, '#{summary}')\"><a onclick=\"top.openONTV('#{md[1]}')\">#{title}</a></div>"

        day, ch, start_hour, start_min, last_hour, last_min = *(md[2, 6].collect do |i| i.to_i end)
        if tommorow
          start_hour += 24
          last_hour += 24
        elsif start_hour > last_hour
          last_hour += 24
        end

        show = Show.new(start_hour, start_min, last_hour, last_min, title)
        show.summary = summary
        channels_map[ch] << show
      elsif ln =~ TOMMOROW_PATTERN
        tommorow = true
      end
    end
  end

end

## for test
if __FILE__ == $0
  generater = GetProgram.new
  channels = generater.read_data("0103")
  channels.each_with_index do |ch, i|
    puts "*** #{ch.title} ***"
    ch_item = ch.fetch(Time.now.hour)
    next unless ch_item
    ch_item.each_with_index do |show, i|
      puts
      puts "#{show.start_hour}:#{show.start_min}"
      puts "#{show.last_hour}:#{show.last_min}"
      puts show.title
      puts
    end
  end
  p generater.to_a.size
end
