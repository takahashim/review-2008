# -*- encoding: euc-japan -*-
#
# $Id: idgxmlbuilder.rb 3761 2007-12-31 07:20:09Z aamine $
#
# Copyright (c) 2002-2007 Minero Aoki
#                    2008 Kenshi Muto <kmuto@debian.org>
#   (based on htmlbuilder.rb)
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/htmlutils'
require 'review/textutils'

module ReVIEW

  class IDGXMLBuilder < Builder

    include TextUtils
    include HTMLUtils

    [:i, :tt, :ttbold, :tti, :idx, :hidx, :dtp, :sup, :sub, :hint, :raw, :maru, :keytop, :labelref].each {|e|
      Compiler.definline(e)
    }
    Compiler.defsingle(:dtp, 1)
    Compiler.defsingle(:raw, 1)
    Compiler.defsingle(:indepimage, 1)
    Compiler.defsingle(:label, 1)

    Compiler.defblock(:insn, 1)
    Compiler.defblock(:flushright, 0)
    Compiler.defblock(:note, 0..1)
    Compiler.defblock(:important, 0..1)
    Compiler.defblock(:notice, 0..1)
    Compiler.defblock(:point, 0..1)
    Compiler.defblock(:reference, 0)
    Compiler.defblock(:term, 0)
    Compiler.defblock(:practice, 0)
    Compiler.defblock(:box, 0..1)
    Compiler.defblock(:expert, 0)
    Compiler.defblock(:lead, 0)

    def extname
      '.xml'
    end

    def builder_init(no_error = false)
      @no_error = no_error
    end
    private :builder_init

    def builder_init_file
      @warns = []
      @errors = []
      @section = 0
      @subsection = 0
      @subsubsection = 0
      @subsubsubsection = 0
      @noindent = nil
      @rootelement = "doc"
      @secttags = nil

      puts %Q(<?xml version="1.0" encoding="UTF-8"?>)
      print %Q(<#{@rootelement} xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/">)
    end
    private :builder_init_file

    def result
      s = ""
      unless @secttags.nil?
        s += "</sect4>" if @subsubsubsection > 0
        s += "</sect3>" if @subsubsection > 0
        s += "</sect2>" if @subsection > 0
        s += "</sect>" if @section > 0
        s += "</chapter>" if @chapter.number > 0
      end
      messages() + @output.string + s + "</#{@rootelement}>\n"
    end

    def warn(msg)
      if @no_error
        @warns.push [@location.filename, @location.lineno, msg]
        puts "----WARNING: #{escape_html(msg)}----"
      else
        $stderr.puts "#{@location}: warning: #{msg}"
      end
    end

    def error(msg)
      if @no_error
        @errors.push [@location.filename, @location.lineno, msg]
        puts "----ERROR: #{escape_html(msg)}----"
      else
        $stderr.puts "#{@location}: error: #{msg}"
      end
    end

    def messages
      error_messages() + warning_messages()
    end

    def error_messages
      return '' if @errors.empty?
      "<h2>Syntax Errors</h2>\n" +
      "<ul>\n" +
      @errors.map {|file, line, msg|
        "<li>#{escape_html(file)}:#{line}: #{escape_html(msg.to_s)}</li>\n"
      }.join('') +
      "</ul>\n"
    end

    def warning_messages
      return '' if @warns.empty?
      "<h2>Warnings</h2>\n" +
      "<ul>\n" +
      @warns.map {|file, line, msg|
        "<li>#{escape_html(file)}:#{line}: #{escape_html(msg)}</li>\n"
      }.join('') +
      "</ul>\n"
    end

    def headline(level, caption)
      prefix = ""
      case level
      when 1
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
          print "</sect3>" if @subsubsection > 0
          print "</sect2>" if @subsection > 0
          print "</sect>" if @section > 0
        end

        print %Q(<chapter id="chap:#{@chapter.number}">) unless @secttags.nil?
        if @chapter.number.to_s =~ /^\d+$/
          prefix = "第#{@chapter.number}章　"
        elsif !@chapter.number.nil? && !@chapter.number.to_s.empty?
          prefix = "#{@chapter.number}　"
        end
        @section = 0
        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
      when 2
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
          print "</sect3>" if @subsubsection > 0
          print "</sect2>" if @subsection > 0
          print "</sect>" if @section > 0
        end
        @section += 1
        print %Q(<sect id="sect:#{@chapter.number}.#{@section}">) unless @secttags.nil?

        prefix = (!@chapter.number.nil? && !@chapter.number.to_s.empty?) ? "#{@chapter.number}.#{@section}　" : ""

        @subsection = 0
        @subsubsection = 0
        @subsubsubsection = 0
      when 3
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
          print "</sect3>" if @subsubsection > 0
          print "</sect2>" if @subsection > 0
        end

        @subsection += 1
        print %Q(<sect2 id="sect:#{@chapter.number}.#{@section}.#{@subsection}">) unless @secttags.nil?
        prefix = (!@chapter.number.nil? && !@chapter.number.to_s.empty?) ? "#{@chapter.number}.#{@section}.#{@subsection}　" : ""

        @subsubsection = 0
        @subsubsubsection = 0
      when 4
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
          print "</sect3>" if @subsubsection > 0
        end

        @subsubsection += 1
        print %Q(<sect3 id="sect:#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}">) unless @secttags.nil?
        prefix = (!@chapter.number.nil? && !@chapter.number.to_s.empty?) ? "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}　" : ""

        @subsubsubsection = 0
      when 5
        unless @secttags.nil?
          print "</sect4>" if @subsubsubsection > 0
        end

        @subsubsubsection += 1
        print %Q(<sect4 id="sect:#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}.#{@subsubsubsection}">) unless @secttags.nil?
        prefix = (!@chapter.number.nil? && !@chapter.number.to_s.empty?) ? "#{@chapter.number}.#{@section}.#{@subsection}.#{@subsubsection}.#{@subsubsubsection}　" : ""
      else
        raise "caption level too deep or unsupported: #{level}"
      end

      prefix = "" if (level.to_i > @@secnolevel)
      puts %Q(<title aid:pstyle="h#{level}">#{prefix}#{escape_html(caption)}</title><?dtp level="#{level}" section="#{prefix}#{escape_html(caption)}"?>)
    end

    def ul_begin
      puts '<ul>'
    end

    def ul_item(lines)
      puts %Q(<li aid:pstyle="ul-item">#{lines.join("\n").chomp}</li>)
    end

    def choice_single_begin
      puts "<choice type='single'>"
    end

    def choice_multi_begin
      puts "<choice type='multi'>"
    end

    def choice_single_end
      puts "</choice>"
    end

    def choice_multi_end
      puts "</choice>"
    end

    def ul_end
      puts '</ul>'
    end

    def ol_begin
      puts '<ol>'
    end

    def ol_item(lines)
      puts %Q(<li aid:pstyle="ol-item">#{lines.join("\n").chomp}</li>)
    end

    def ol_end
      puts '</ol>'
    end

    def dl_begin
      puts '<dl>'
    end

    def dt(line)
      puts "<dt>#{line}</dt>"
    end

    def dd(lines)
      puts "<dd>#{lines.join("\n").chomp}</dd>"
    end

    def dl_end
      puts '</dl>'
    end

    def paragraph(lines)
      if @noindent.nil?
        puts "<p>#{lines.join('')}</p>"
      else
        puts %Q(<p aid:pstyle="noindent">#{lines.join('')}</p>)
        @noindent = nil
      end
    end

    def read(lines)
      puts %Q[<p aid:pstyle="lead">#{lines.join('')}</p>]
    end

    def lead(lines)
      read(lines)
    end

    def inline_list(id)
      if !@chapter.number.nil? && !@chapter.number.to_s.empty?
        "リスト#{@chapter.number}.#{@chapter.list(id).number}"
      else
        "リスト#{@chapter.list(id).number}"
      end
    end

    def list_header(id, caption)
      if !@chapter.number.nil? && !@chapter.number.to_s.empty?
        puts %Q[<codelist>\n<caption>リスト#{@chapter.number}.#{@chapter.list(id).number}　#{escape_html(caption)}</caption>]
      else
        puts %Q[<codelist>\n<caption>リスト#{@chapter.list(id).number}　#{escape_html(caption)}</caption>]
      end
    end

    def list_body(lines)
      print %Q(<pre>)
      lines.each do |line|
        puts detab(line)
      end
      puts "</pre></codelist>"
    end

    def emlist(lines)
      quotedlist lines, 'emlist'
    end

    def cmd(lines)
      quotedlist lines, 'cmd'
    end

    def quotedlist(lines, css_class)
      print %Q[<list><pre>]
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre></list>'
    end
    private :quotedlist

    def quote(lines)
      puts "<quote>\n#{lines.join("\n")}</quote>"
    end

    def inline_table(id)
      if !@chapter.number.nil? && !@chapter.number.to_s.empty?
        "表#{@chapter.number}.#{@chapter.table(id).number}"
      else
        "表#{@chapter.table(id).number}"
      end
    end

    def inline_img(id)
      if !@chapter.number.nil? && !@chapter.number.to_s.empty?
        "図#{@chapter.number}.#{@chapter.image(id).number}"
      else
        "図#{@chapter.image(id).number}"
      end
    end

    def image_image(id, metric, caption)
      puts "<img>"
      puts %Q[<Image href="file://#{@chapter.image(id).path.sub(/^.\//, "")}" />]
      image_header id, caption
      puts "</img>"
    end

    def image_dummy(id, caption, lines)
      puts "<img>"
      image_header id, caption
      print %Q[<pre aid:pstyle="dummyimage">]
      lines.each do |line|
        puts detab(line)
      end
      print %Q[</pre>]
      puts "</img>"
    end

    def image_header(id, caption)
      if !@chapter.number.nil? && !@chapter.number.to_s.empty?
        puts %Q[<caption>図#{@chapter.number}.#{@chapter.image(id).number}　#{escape_html(caption)}</caption>]
      else
        puts %Q[<caption>図#{@chapter.image(id).number}　#{escape_html(caption)}</caption>]
      end
    end

    def table(lines, id, caption)
      puts "<table>"
#      super(lines, id, caption)
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
#        rows.push(line.gsub("&quot;", "\"").gsub("&lt;", "<").gsub("&gt;", ">").gsub("&amp;", "&").gsub(/\t\.\t/, "\t\t").gsub(/^\./, ""))
        rows.push(line.gsub(/\t\.\t/, "\t\t").gsub(/^\./, ""))
      end

#FIXME        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      
      begin
        table_header id, caption
      rescue KeyError => err
        error "no such table: #{id}"
      end
      return if rows.empty?
#      table_begin rows.first.size
      print "<tbody>"
      if sepidx
        sepidx.times do
          puts "<tr type=\"header\">" + rows.shift + "</tr>"
        end
        lastline = rows.pop
        rows.each do |row|
          puts "<tr>" + row + "</tr>"
        end
        puts "<tr type=\"lastline\">" + lastline + "</tr>"
      else
        rows.each do |row|
          puts "<tr>" + row + "</tr>"
        end
      end
#      table_end
      print "</tbody>"
      puts "</table>"
    end

    def table_header(id, caption)
      if !@chapter.number.nil? && !@chapter.number.to_s.empty?
        puts %Q[<caption>表#{@chapter.number}.#{@chapter.table(id).number}　#{escape_html(caption)}</caption>]
      else
        puts %Q[<caption>表#{@chapter.table(id).number}　#{escape_html(caption)}</caption>]
      end
    end

    def table_begin(ncols)
      #  aid:trows="" aid:tcols="" widths="列1の幅, 列2の幅, ..."をdtp命令で入れておく
#      puts %Q(<表 xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/" aid:table="table">)
    end

    def tr(rows)
      # FIXME
      puts "<tr>" + rows.join("\t") + "</tr>"
    end

    def th(str)
      # FIXME aid:ccolwidth=""
      # FIXME strが2回エスケープされている
#      %Q(<セル aid:table="cell" aid:theader="" aid:crows="1" aid:ccols="1">#{str}</セル>)
      %Q(<?dtp tablerow header?>#{str})
    end

    def td(str)
      # FIXME aid:ccolwidth=""
      # FIXME strが2回エスケープされている
#      %Q(<セル aid:table="cell" aid:crows="1" aid:ccols="1">#{str}</セル>)
      str
    end
    
    def table_end
#      puts '</表>'
      print "<?dtp tablerow last?>"
    end

    def comment(str)
      print %Q(<!-- [Comment] #{escape_html(str)} -->)
    end

    def footnote(id, str)
      # FIXME: inline_fnと合わせて処理必要。2パースの処理をすべきか
#      puts %Q(<footnote id="#{id}" no="#{@chapter.footnote(id).number}">#{compile_inline(str)}</footnote>)
    end

    def inline_fn(id)
      %Q(<footnote>#{compile_inline(@chapter.footnote(id).content.strip)}</footnote>)
    end

    def compile_ruby(base, ruby)
      %Q(<GroupRuby><aid:ruby xmlns:aid="http://ns.adobe.com/AdobeInDesign/3.0/"><aid:rb>#{escape_html(base.sub(/^\s+/, "").sub(/\s+$/, ""))}</aid:rb><aid:rt>#{escape_html(ruby.sub(/^\s+/, "").sub(/\s+$/, ""))}</aid:rt></aid:ruby></GroupRuby>)
    end

    def compile_kw(word, alt)
      '<keyword>' +
        if alt
        #then escape_html(word + sprintf(@locale[:parens], alt.strip))
        then escape_html(word + "（#{alt.strip}）")
        else escape_html(word)
        end +
      '</keyword>' +
        %Q(<index value="#{escape_html(word)}" />) +
        if alt
          alt.split(/\s*,\s*/).collect! {|e| %Q(<index value="#{e.strip}" />) }.join
        else
          ""
        end
    end

    def inline_sup(str)
      %Q(<sup>#{escape_html(str)}</sup>)
    end

    def inline_sub(str)
      %Q(<sub>#{escape_html(str)}</sub>)
    end

    def inline_raw(str)
      %Q(#{str.gsub("\\n", "\n")})
    end

    def inline_hint(str)
      %Q(\n<hint>#{escape_html(str)}</hint>)
    end

    def inline_maru(str)
      sprintf("&#x%x;", 9311 + str.to_i)
    end

    def inline_idx(str)
      %Q(#{escape_html(str)}<index value="#{escape_html(str)}" />)
    end

    def inline_hidx(str)
      %Q(<index value="#{escape_html(str)}" />)
    end

    def inline_ami(str)
      %Q(<ami>#{escape_html(str)}</ami>)
    end

    def inline_i(str)
      %Q(<i>#{escape_html(str)}</i>)
    end

    def inline_b(str)
      %Q(<b>#{escape_html(str)}</b>)
    end

    def inline_tt(str)
      %Q(<tt>#{escape_html(str)}</tt>)
    end

    def inline_ttbold(str)
      index = escape_html(str).gsub(/<.*?>/, "").gsub(/\*/, "ESCAPED_ASTERISK").gsub(/'/, "&#27;")
      %Q(<tt style='bold'>#{escape_html(str)}</tt><index value='#{index}' />)
    end

    def inline_tti(str)
      %Q(<tt style='italic'>#{escape_html(str)}</tt>)
    end

    def inline_bou(str)
      %Q(<bou>#{escape_html(str)}</bou>)
    end

    def inline_keytop(str)
      %Q(<keytop>#{escape_html(str)}</keytop>)
    end

    def inline_labelref(idref)
      %Q(<ref id='#{idref}' />) # FIXME:節名とタイトルも込みで要出力
    end

    def noindent
      @noindent = true
    end

    def linebreak
      # FIXME:pが閉じちゃってるので一度戻らないといけないが、難しい…。
      puts "<br />"
    end

    def pagebreak
      puts "<pagebreak />"
    end

    def nonum_begin(level, caption)
      puts %Q(<title aid:pstyle="h#{level}">#{escape_html(caption)}</title><?dtp level="#{level}" section="#{escape_html(caption)}"?>)
    end

    def nonum_end(level)
    end

    def circle_begin(level, caption)
      puts %Q(<title aid:pstyle="smallcircle">・#{escape_html(caption)}</title>)
    end

    def circle_end(level)
    end

    def column_begin(level, caption)
      print "<column>"
      puts %Q(<title aid:pstyle="column-title">#{caption}</title>)
    end

    def column_end(level)
      puts "</column>"
    end

    def flushright(lines)
      puts "<p align='right'>#{lines.join("\n")}</p>"
    end

    def note(lines, caption = nil)
      print "<note>"
      puts "<title aid:pstyle='note-title'>#{caption}</title>" unless caption.nil?
      puts "#{lines.join("\n")}</note>"
    end

    def important(lines, caption = nil)
      print "<important>"
      puts "<title aid:pstyle='important-title'>#{caption}</title>" unless caption.nil?
      puts "#{lines.join("\n")}</important>"
    end

    def term(lines)
      puts "<term>#{lines.join("\n")}</term>"
    end

    def notice(lines, caption = nil)
      if caption.nil?
        puts "<notice>#{lines.join("\n")}</notice>"
      else
        puts "<notice-t><title aid:pstyle='notice-title'>#{caption}</title>"
        puts "#{lines.join("\n")}</notice-t>"
      end
    end

    def point(lines, caption = nil)
      if caption.nil?
        puts "<point>#{lines.join("\n")}</point>"
      else
        puts "<point-t><title aid:pstyle='point-title'>#{caption}</title>"
        puts "#{lines.join("\n")}</point-t>"
      end
    end

    def reference(lines)
      puts "<reference>#{lines.join("\n")}</reference>"
    end

    def practice(lines)
      puts "<practice>#{lines.join("\n")}</practice>"
    end

    def expert(lines)
      puts "<expert>#{lines.join("\n")}</expert>"
    end

    def insn(lines, caption)
      puts %Q[<insn><floattitle type="insn">#{caption}</floattitle>]
      puts "<p>#{lines.join("\n")}</p></insn>"
    end

    def box(lines, caption = nil)
      if caption.nil?
        print %Q[<box>]
      else
        puts %Q[<box><title aid:pstyle="box-title">#{caption}</title>]
      end
      puts "#{lines.join("\n")}</box>"
    end

    def indepimage(id)
      puts "<img>"
      puts %Q[<Image href="file://images/#{@chapter.id}-#{id}.eps" />] # FIXME
      puts "</img>"
    end

    def label(id)
      # FIXME
      print "<label id='#{id}' />"
    end

    def dtp(str)
      print %Q(<?dtp #{str} ?>)
    end

    def inline_dtp(str)
      "<?dtp #{str} ?>"
    end

    def raw(str)
      print str.gsub("\\n", "\n")
    end

    def text(str)
      str
    end

    def nofunc_text(str)
      escape_html(str)
    end

  end

end   # module ReVIEW
