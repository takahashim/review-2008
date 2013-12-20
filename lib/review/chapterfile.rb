#
# $Id: chapterfile.rb 3653 2007-01-29 03:10:16Z aamine $
#
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/index'
require 'review/volume'

module ReVIEW

  class ChapterFile

    def initialize(env, number, dirname, basename)
      @env = env
      @number = number
      @dirname = dirname
      @basename = basename
      @title = nil
      @content = nil
      @list_index = nil
      @table_index = nil
      @footnote_index = nil
      @image_index = nil
    end

    attr_reader :env
    attr_reader :number
    attr_reader :dirname
    attr_reader :basename

    def inspect
      "\#<#{self.class} #{number} #{@dirname}/#{basename}>"
    end

    def name
      File.basename(@basename, @env.ext)
    end

    alias id name

    def title
      @title ||= open {|f| f.gets.sub(/\A=/, '').strip }
    end

    def path
      "#{@dirname}/#{@basename}"
    end

    def size
      File.size(path())
    end

    def kbytes
      (size().to_f / 1024).ceil
    end

    def n_chars
      volume().chars
    end

    def n_lines
      volume().lines
    end

    def volume
      @volume ||= Volume.count_file(path())
    end

    def open(&block)
      File.open(path(), &block)
    end

    def content
      @content = File.read(path())
    end

    def lines
      # FIXME: we cannot duplicate Enumerator on ruby 1.9 HEAD
      (@lines ||= content().lines.to_a).dup
    end

    def list(id)
      list_index()[id]
    end

    def list_index
      @list_index ||= ListIndex.parse(lines())
    end

    def table(id)
      table_index()[id]
    end

    def table_index
      @table_index ||= TableIndex.parse(lines())
    end

    def footnote(id)
      footnote_index()[id]
    end

    def footnote_index
      @footnote_index ||= FootnoteIndex.parse(lines())
    end

    def image(id)
      image_index()[id]
    end

    def image_index
      @image_index ||= ImageIndex.parse(lines(), id(), @env.image_dir, @env.image_types)
    end

  end

end
