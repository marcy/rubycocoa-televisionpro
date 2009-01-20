# -*- coding: utf-8 -*-
#
#  AppController.rb
#  TelevisionPro
#
#  Created by Masashi Oyamada on 08/11/15.
#  Copyright (c) 2008 Masashi Oyamada All rights reserved.
#

require "get_program.rb"
require 'PreferenceController'

require 'fileutils'
require 'pathname'
require 'osx/cocoa'

$KCODE = 'UTF8'

class AppController < OSX::NSObject
  ib_action :push_time
  ib_action :push_reload
  ib_action :select_prefecture
  ib_action :search
  # ib_action :prefectures

  ib_outlet :window
  ib_outlet :tableView
  ib_outlet :progressIndicator
  ib_outlet :info_label
  ib_outlet :info
  ib_outlet :load
  ib_outlet :summary
  ib_outlet :search
  ib_outlet :prefecture
  # ib_outlet :prefectures_items

  #   def prefectures_items
  #     @generater ||= GetProgram.new
  #     @generater.prefectures.values
  #   end

  attr_reader :my_preference

  def showPreferencePanel (sender)
    if @preferenceController.nil?
      @preferenceController = PreferenceController.alloc.init(self)
    end
    @preferenceController.showWindow(self)
    @preferenceController.set_label
  end
  ib_action :showPreferencePanel

  def awakeFromNib()
    @lib_dir = Pathname.new('~/Library/Application Support/TelevisionPro/').expand_path
    @lib_fname = File.join(@lib_dir, "TelevisionPro.yaml")
    unless File.exist?(@lib_dir)
      FileUtils.mkpath(@lib_dir)
    end
    yaml = nil
    if File.exist?(@lib_fname)
      yaml = File.read(@lib_fname)
    end
    if yaml.nil? or yaml.empty?
      @my_preference = Hash.new
      @my_preference["channel_num"] = 7
      @my_preference["prefecture"] = "東京"
    else
      @my_preference = YAML.load(yaml)
    end

    d = Time.now
    @info.setStringValue("#{d.year}/#{d.month}/#{d.day}")
    @prefecture.setStringValue(@my_preference["prefecture"])

    @generater = GetProgram.new(@my_preference["prefecture"], 
      @my_preference["channel_num"])
    @prefecture_code = @my_preference["prefecture"]
    @program_data = @generater.to_a
    @tableView.reloadData
  end

  def mypreference(key, value)
    File.open(@lib_fname, "w") do |f|
      @my_preference[key] = value
      @my_preference.each do |key, value|
        f.write("#{key}: #{value}\n")
      end
    end
  end

  def focus_search_box
    @search.setSelectable(1)
  end

  def search(sender)
    keyword = sender.stringValue.to_s
    unless keyword.empty?
      progress_indicator(sender) do
        @generater ||= GetProgram.new
        @program_data = @generater.search(keyword)
        @tableView.reloadData
        @info_label.setStringValue("検索: ")
        @info.setStringValue("\"#{keyword}\" #{@program_data.size}件")
      end
    end
  end

  def set_channel(channel, sender)
    @generater ||= GetProgram.new
    @generater.channel_num = sender.stringValue.to_i
    @program_data = @generater.to_a
    set_date
    @tableView.reloadData
  end

  def select_channel_num(sender)
    set_channel(sender.stringValue.to_i, sender)
  end

  def set_prefecture(prefecture_name, sender)
    @generater ||= GetProgram.new
    @prefecture_code = @generater.prefecture_code(prefecture_name)
    @prefecture_code = "" if @prefecture_code.nil?
    @prefecture.setStringValue("#{prefecture_name}の番組表")
    reload_with_progress_indicator(sender)
  end

  def select_prefecture(sender)
    name = sender.stringValue.to_s
    set_prefecture(name, sender)
  end

  def push_time(sender)
    progress_indicator(sender) do
      @hour = sender.title.to_i
      @generater ||= GetProgram.new
      @generater.time = @hour
      @program_data = @generater.to_a
      set_date
      @tableView.reloadData
    end
  end

  def down_time(sender)
    @hour ||= Time.now.hour
    @hour -= 1
    @hour = 5 if @hour < 5
    ch_hour(sender)
  end

  def up_time(sender)
    @hour ||= Time.now.hour
    @hour += 1
    @hour = 28 if @hour > 28
    ch_hour(sender)
  end

  def push_reload(sender)
    @prefecture_code ||= ""
    reload_with_progress_indicator(sender)
  end

  ## NSTableView dataSource ##

  def numberOfRowsInTableView(tableView)
    # @program_data ? @program_data.size*2 : 0
    @program_data ? @program_data.size : 0
  end

  def tableView_objectValueForTableColumn_row(tableView, tableColumn, row)
    is_even = row.to_i % 2 == 0
    identifier = tableColumn.identifier.to_s
    #    show_data = @program_data[row.to_i/2]
    show_data = @program_data[row.to_i]
    case identifier
    when "ch"
      return show_data[:ch_title]
      #       if is_even
      #         return show_data[:ch_title]
      #       else
      #         return ""
      #       end
    when "time"
      return show_data[:start_time] + "~" + show_data[:end_time]
      #       if is_even
      #         return show_data[:start_time] + "~" + show_data[:end_time]
      #       else
      #         return ""
      #       end
    when "show"
      return show_data[:show_title]
      #       if is_even
      #         return show_data[:show_title]
      #       else
      #         return "   >> " + show_data[:summary]
      #       end
    end
    return ""
  end

  ## NSTableView delegate ##

  def tableViewSelectionDidChange(note)
    selected_row = @tableView.selectedRow.to_i
    show_data = @program_data[selected_row]
    if show_data
      str = show_data[:summary]
    else
      str = ""
    end
    @summary.setStringValue(str)
  end

  def tableView_willDisplayCell_forTableColumn_row(
      tableView, cell, tableColumn, row)
    white_color = OSX::NSColor.whiteColor
    stripe_color = OSX::NSColor.colorWithCalibratedRed_green_blue_alpha(
      0.9, 1.0, 1.0, 1.0)

    cell.setDrawsBackground(1)
    if row.to_i % 2 == 1
      cell.setBackgroundColor(stripe_color)
    else
      cell.setBackgroundColor(white_color)
    end
  end

  private

  def reload
    @generater ||= GetProgram.new
    @generater.read_data(@prefecture_code)
    @program_data = @generater.to_a
    set_date
    @tableView.reloadData
  end

  def set_date
    d = Time.now
    hour = @generater ? @generater.time : d.hour
    @info_label.setStringValue("日付: ")
    @info.setStringValue "#{d.year}/#{d.month}/#{d.day} #{hour}時"
  end

  def reload_with_progress_indicator(sender)
    progress_indicator(sender) do
      reload
    end
  end

  def progress_indicator(sender, &block)
    @progressIndicator.startAnimation(sender)
    block.call
    @progressIndicator.stopAnimation(sender)
  end

  def ch_hour(sender)
    progress_indicator(sender) do
      @generater ||= GetProgram.new
      @generater.time = @hour
      @program_data = @generater.to_a
      set_date
      @tableView.reloadData
    end
  end

end
