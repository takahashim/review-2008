#
# $Id: book.rb 3937 2008-04-19 15:05:50Z kmuto $
#
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/preprocessor'
require 'review/volume'
require 'forwardable'

module ReVIEW

  class Entry

    def Entry.cmdline_intern(chaps)
      chaps ? from_chaps(chaps) : from_argv()
    end

    def Entry.from_chaps(chaps)
      chaps.map {|chap| ReVIEW::Entry.new(chap.path, nil, chap.number) }
    end

    def Entry.from_argv
      if ARGV.empty?
        [new('-', $stdin)]
      else
        num = 0
        ARGV.map {|path| new(path, nil, (num += 1)) }
      end
    end

    def initialize(path, file = nil, number = nil)
      @path = path
      @file = file
      @number = number
    end

    attr_reader :path
    attr_reader :number

    def open(&block)
      if @file
        yield @file
      else
        File.open(@path, &block)
      end
    end

    def title
      open {|f|
        return f.gets.strip.sub(/\A=+\s+/, '')
      }
    end

    def volume
      @volume ||= Volume.count_file(@path)
    end

    extend Forwardable
    def_delegators 'volume()', :kbytes, :bytes, :chars, :lines

  end


  class Parser

    def parse_entries(entries)
      book = Book.new
      entries.each do |ent|
        ent.open {|f|
          parse(Preprocessor::Strip.new(f), ent.path).each do |root|
            root.number = ent.number
            book.add_child root
          end
        }
      end
      book
    end

    def parse(f, filename)
      roots = []
      path = []

      while line = f.gets
        case line
        when /\A\s*\z/
          ;
        when /\A(={2,})[\[\s]/
          lev = $1.size
          error! filename, f.lineno, "section level too deep: #{lev}" if lev > 5
          if path.empty?
            # missing chapter label
            path.push Section.new(1, '', filename)
          end
          new = Section.new(lev, get_label(line))
          until path.last.level < new.level
            path.pop
          end
          path.last.add_child new
          path.push new

        when /\A= /
          path.clear
          path.push Chapter.new(get_label(line), filename)
          roots.push path.first

        when %r<\A//\w+(?:\[.*?\])*\{\s*\z>
          error! filename, f.lineno, 'list found before section label' if path.empty?
          path.last.add_child(list = List.new)
          beg = f.lineno
          list.add line
          while line = f.gets
            break if %r<\A//\}> =~ line
            list.add line
          end
          error! filename, beg, 'unterminated list' unless line

        when %r<\A//\w>
          ;
        else
          #error! filename, f.lineno, 'text found before section label' if path.empty?
          next if path.empty?
          path.last.add_child(par = Paragraph.new)
          par.add line
          while line = f.gets
            break if /\A\s*\z/ =~ line
            par.add line
          end
        end
      end

      roots
    end

    def get_label(line)
      line.strip.sub(/\A=+\s*/, '')
    end

    def error!(filename, lineno, msg)
      raise "#{filename}:#{lineno}: #{msg}"
    end

  end


  class Node

    def initialize
      @children = []
    end

    attr_reader :children

    def add_child(c)
      @children.push c
    end
    
    def each_node(&block)
      @children.each do |c|
        yield c
        c.each(&block)
      end
    end
    
    def each_child(&block)
      @children.each(&block)
    end

    def chapter?
      false
    end

    def each_section(&block)
      @children.each do |n|
        n.yield_section(&block)
      end
    end

    def each_section_with_index
      i = 0
      each_section do |n|
        yield n, i
        i += 1
      end
    end

    def n_sections
      cnt = 0
      @children.each do |n|
        n.yield_section { cnt += 1 }
      end
      cnt
    end

  end


  class Book < Node

    def Book.parse_entries(entries)
      Parser.new.parse_entries(entries)
    end

    def Book.parse_files(pathes)
      Parser.new.parse_entries(pathes.map {|path| Entry.new(path) })
    end

    def level
      0
    end

    def estimated_lines
      @children.inject(0) {|sum, n| sum + n.estimated_lines }
    end

    def yield_section
      yield self
    end

    def inspect
      "\#<#{self.class}>"
    end

  end


  class Section < Node

    def initialize(level, label, path = nil)
      super()
      @level = level
      @label = label
      @filename = (path ? real_filename(path) : nil)
    end

    def real_filename(path)
      if FileTest.symlink?(path)
        File.basename(File.readlink(path))
      else
        File.basename(path)
      end
    end
    private :real_filename

    attr_reader :level
    attr_reader :label

    def display_label
      if @filename
        @label + ' ' + @filename
      else
        @label
      end
    end

    def estimated_lines
      @children.inject(0) {|sum, n| sum + n.estimated_lines }
    end

    def yield_section
      yield self
    end

    def inspect
      "\#<#{self.class} level=#{@level} #{@label}>"
    end

  end


  class Chapter < Section

    def initialize(label, path)
      super 1, label, path
      @path = path
      @volume = nil
      @number = nil
    end

    attr_accessor :number

    def chapter?
      true
    end

    def chapter_id
      File.basename(@path, '.*')
    end

    def volume
      return @volume if @volume
      @volume = Volume.count_file(@path)
      @volume.lines = estimated_lines()
      @volume
    end

    def inspect
      "\#<#{self.class} #{@filename}>"
    end

  end


  class Paragraph < Node

    def initialize
      @bytes = 0
    end

    def inspect
      "\#<#{self.class}>"
    end

    def add(line)
      @bytes += line.strip.bytesize
    end

    def estimated_lines
      (@bytes + 2) / ReVIEW.env.page_metric.text.n_columns + 1
    end

    def yield_section
    end

  end


  class List < Node

    def initialize
      @lines = 0
    end

    def inspect
      "\#<#{self.class}>"
    end

    def add(line)
      @lines += 1
    end

    def estimated_lines
      @lines + 2
    end

    def yield_section
    end

  end

end
