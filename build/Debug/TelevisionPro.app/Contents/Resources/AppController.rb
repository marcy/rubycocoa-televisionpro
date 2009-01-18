# -*- coding: mule-utf-8 -*-
#
#  AppController.rb
#  TelevisionPro
#
#  Created by Masashi Oyamada on 08/11/15.
#  Copyright (c) 2008 Masashi Oyamada All rights reserved.
#

require "get_program.rb"

require 'osx/cocoa'

class AppController < OSX::NSObject
  ib_action :push_time
  ib_action :push_reload
  ib_action :select_prefecture
  ib_action :search
  
  ib_outlet :window
  ib_outlet :tableView
  ib_outlet :progressIndicator
  ib_outlet :info_label
  ib_outlet :info
  ib_outlet :load
  ib_outlet :summary

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

  def select_channel_num(sender)
    @generater ||= GetProgram.new
    @generater.channel_num = sender.stringValue.to_i
    @program_data = @generater.to_a
    set_date
    @tableView.reloadData
  end
  
  def select_prefecture(sender)
    @generater ||= GetProgram.new
    name = sender.stringValue.to_s
    @prefecture_code = @generater.prefecture_code(name)
    @prefecture_code = "" if @prefecture_code.nil?
    reload_with_progress_indicator(sender)
  end

  def push_time(sender)
    progress_indicator(sender) do 
      hour = sender.title.to_s
      @generater ||= GetProgram.new
      @generater.time = hour.to_i
      @program_data = @generater.to_a
      set_date
      @tableView.reloadData
    end
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
    str = show_data[:summary]
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

  def reload
    @generater ||= GetProgram.new
    @generater.read_data(@prefecture_code)
    @program_data = @generater.to_a
    set_date
    @tableView.reloadData
  end

end
