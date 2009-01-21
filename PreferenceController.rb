# -*- coding: utf-8 -*-
#
#  AppController.rb
#  TelevisionPro
#
#  Created by Masashi Oyamada on 08/11/15.
#  Copyright (c) 2008 Masashi Oyamada All rights reserved.
#

require 'osx/cocoa'

class PreferenceController < OSX::NSWindowController
  include OSX

  # Default_Label = "環境設定してください"

  ib_outlet :channel_num
  ib_outlet :select_prefecture
  ib_outlet :wait_text
  ib_outlet :now_prefecture
  ib_outlet :now_channel_num

  def init(main_controller)
    @main_controller = main_controller
    initWithWindowNibName "Preferences"
    setWindowFrameAutosaveName "PrefWindow"
    return self
  end

  def set_label
    @now_channel_num.setStringValue(@main_controller.my_preference["channel_num"])
    @now_prefecture.setStringValue(@main_controller.my_preference["prefecture"])
  end

  def select_channel_num(sender)
    show_wait do
      channel = sender.stringValue.to_i
      @main_controller.set_channel(channel, sender)
      @main_controller.mypreference("channel_num", channel)
      @now_channel_num.setStringValue(channel.to_s)
    end
  end
  ib_action :select_channel_num

  def select_prefecture(sender)
    show_wait do
      name = @select_prefecture.stringValue.to_s
      @main_controller.set_prefecture(name, sender)
      @main_controller.mypreference("prefecture", name)
      @now_prefecture.setStringValue(name)
    end
  end
  ib_action :select_prefecture

  def show_wait(&block)
    # @wait_text.setStringValue("データ取得中...")
    block.call
    # @wait_text.setStringValue(Default_Label)
  end
end
