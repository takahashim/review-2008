# -*- encoding: EUC-JP -*-
#
# $Id: topbuilder.rb 3789 2008-01-04 04:42:09Z kmuto $
#
# Copyright (c) 2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/textutils'

module ReVIEW

  class TOPBuilder < Builder

    include TextUtils

    def builder_init_file
      @section = 0
      @blank_seen = true
    end
    private :builder_init_file

    def print(s)
      @blank_seen = false
      super
    end
    private :print

    def puts(s)
      @blank_seen = false
      super
    end
    private :puts

    def blank
      @output.puts unless @blank_seen
      @blank_seen = true
    end
    private :blank

    def result
      @output.string
    end

    def warn(msg)
      $stderr.puts "#{@location.filename}:#{@location.lineno}: warning: #{msg}"
    end

    def error(msg)
      $stderr.puts "#{@location.filename}:#{@location.lineno}: error: #{msg}"
    end

    def messages
      error_messages() + warning_messages()
    end

    def headline(level, caption)
      blank
      case level
      when 1
        puts "■H1■第#{@chapter.number}章　#{caption}"
      when 2
        puts "■H2■#{@chapter.number}.#{@section += 1}　#{caption}"
      when 3
        puts "■H3■#{caption}"
      when 4
        puts "■H4■#{caption}"
      else
        raise "caption level too deep or unsupported: #{level}"
      end
    end

    def column_begin(level, caption)
      blank
      puts "◆→開始:コラム -編集者←◆"
      puts "■#{caption}"
    end

    def column_end(level)
      puts "◆→終了:コラム -編集者←◆"
      blank
    end

    def ul_begin
      blank
    end

    def ul_item(lines)
      puts "●\t#{lines.join('')}"
    end

    def ul_end
      blank
    end

    def ol_begin
      blank
      @olitem = 0
    end

    def ol_item(lines)
      puts "#{@olitem += 1}\t#{lines.join('')}"
    end

    def ol_end
      blank
      @olitem = nil
    end

    def dl_begin
      blank
    end

    def dt(line)
      puts "★#{line}☆"
    end

    def dd(lines)
      split_paragraph(lines).each do |paragraph|
        puts "\t#{paragraph.gsub(/\n/, '')}"
      end
    end

    def split_paragraph(lines)
      lines.map {|line| line.strip }.join("\n").strip.split("\n\n")
    end

    def dl_end
      blank
    end

    def paragraph(lines)
      puts lines.join('')
    end

    alias read paragraph

    def inline_list(id)
      "リスト#{@chapter.number}.#{@chapter.list(id).number}"
    end

    def list_header(id, caption)
      blank
      puts "◆→開始:リスト -編集者←◆"
      puts "リスト#{@chapter.number}.#{@chapter.list(id).number}　#{caption}"
      blank
    end

    def list_body(lines)
      lines.each do |line|
        puts line
      end
      puts "◆→終了:リスト -編集者←◆"
      blank
    end

    def emlist(lines)
      blank
      puts "◆→開始:インラインリスト -編集者←◆"
      lines.each do |line|
        puts line
      end
      puts "◆→終了:インラインリスト -編集者←◆"
      blank
    end

    def cmd(lines)
      blank
      puts "◆→開始:コマンド -編集者←◆"
      lines.each do |line|
        puts line
      end
      puts "◆→終了:コマンド -編集者←◆"
      blank
    end

    def inline_img(id)
      "図#{@chapter.number}.#{@chapter.image(id).number}"
    end

    def image(lines, id, caption)
      blank
      puts "◆→開始:図 -編集者←◆"
      puts "図#{@chapter.number}.#{@chapter.image(id).number}　#{caption}"
      blank
      if @chapter.image(id).bound?
        puts "◆→#{@chapter.image(id).path} -編集者←◆"
      else
        lines.each do |line|
          puts line
        end
      end
      puts "◆→終了:図 -編集者←◆"
      blank
    end

    def inline_table(id)
      "表#{@chapter.number}.#{@chapter.table(id).number}"
    end

    def table_header(id, caption)
      blank
      puts "◆→開始:表 -編集者←◆"
      puts "表#{@chapter.number}.#{@chapter.table(id).number}　#{caption}"
      blank
    end

    def table_begin(ncols)
    end

    def tr(rows)
      puts rows.join("\t")
    end

    def th(str)
      "★#{str}☆"
    end

    def td(str)
      str
    end
    
    def table_end
      puts "◆→終了:表 -編集者←◆"
      blank
    end

    def comment(str)
      puts "◆→DTP担当様:#{str} -編集者←◆"
    end

    def inline_fn(id)
      "【注#{@chapter.footnote(id).number}】"
    end

    def footnote(id, str)
      puts "【注#{@chapter.footnote(id).number}】#{str}"
    end

    def compile_kw(word, alt)
      if alt
      then "★#{word}☆（#{alt.sub(/^\s+/,"")}）"
      else "★#{word}☆"
      end
    end

    def inline_chap(id)
      #"「第#{super}章　#{inline_title(id)}」"
      # "第#{super}章"
      super
    end

    def compile_ruby(base, ruby)
      "#{base}◆→DTP担当様:「#{base}」に「#{ruby}」とルビ -編集者←◆"
    end

    def inline_bou(str)
      "#{str}◆→DTP担当様:「#{str}」に傍点 -編集者←◆"
    end

    def inline_i(str)
      "▲#{str}☆"
    end

    def inline_b(str)
      "★#{str}☆"
    end

    def inline_ami(str)
      "#{str}◆→DTP担当様:「#{str}」に網カケ -編集者←◆"
    end

    def text(str)
      str
    end

    def nofunc_text(str)
      str
    end

  end

end   # module ReVIEW
