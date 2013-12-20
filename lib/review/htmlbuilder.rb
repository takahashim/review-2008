# -*- encoding: EUC-JP -*-
#
# $Id: htmlbuilder.rb 3761 2007-12-31 07:20:09Z aamine $
#
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/htmlutils'
require 'review/textutils'

module ReVIEW

  class HTMLBuilder < Builder

    include TextUtils
    include HTMLUtils

    def extname
      '.html'
    end

    def builder_init(no_error = false)
      @no_error = no_error
    end
    private :builder_init

    def builder_init_file
      @warns = []
      @errors = []
    end
    private :builder_init_file

    def result
      messages() + @output.string
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
      puts '' if level > 1
      puts "<h#{level}>#{caption}</h#{level}>"
    end

    def ul_begin
      puts '<ul>'
    end

    def ul_item(lines)
      puts "<li>#{lines.join("\n")}</li>"
    end

    def ul_end
      puts '</ul>'
    end

    def ol_begin
      puts '<ol>'
    end

    def ol_item(lines)
      puts "<li>#{lines.join("\n")}</li>"
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
      puts "<dd>#{lines.join("\n")}</dd>"
    end

    def dl_end
      puts '</dl>'
    end

    def paragraph(lines)
      puts "<p>#{lines.join("\n")}</p>"
    end

    def read(lines)
      puts %Q[<p class="lead">\n#{lines.join("\n")}\n</p>]
    end

    def list_header(id, caption)
      puts %Q[<p class="toplabel">#{@chapter.list(id).number}: #{escape_html(caption)}</p>]
    end

    def list_body(lines)
      puts '<pre class="list">'
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre>'
    end

    def emlist(lines)
      quotedlist lines, 'emlist'
    end

    def cmd(lines)
      quotedlist lines, 'cmd'
    end

    def quotedlist(lines, css_class)
      puts %Q[<blockquote><pre class="#{css_class}">]
      lines.each do |line|
        puts detab(line)
      end
      puts '</pre></blockquote>'
    end
    private :quotedlist

    def quote(lines)
      puts "<blockquote>#{lines.join("\n")}</blockquote>"
    end

    def image_image(id, metric, caption)
      puts %Q[<p class="image">]
      puts %Q[<img src="#{@chapter.image(id).path}" alt="(#{escape_html(caption)})">]
      puts %Q[</p>]
      image_header id, caption
    end

    def image_dummy(id, caption, lines)
      puts %Q[<pre class="dummyimage">]
      lines.each do |line|
        puts detab(line)
      end
      puts %Q[</pre>]
      image_header id, caption
    end

    def image_header(id, caption)
      puts %Q[<p class="botlabel">]
      puts %Q[#{@chapter.image(id).number}: #{escape_html(caption)}]
      puts %Q[</p>]
    end

    def table_header(id, caption)
      puts %Q[<p class="toplabel">#{@chapter.table(id).number}: #{escape_html(caption)}</p>]
    end

    def table_begin(ncols)
      puts '<table>'
    end

    def tr(rows)
      puts "<tr>#{rows.join('')}</tr>"
    end

    def th(str)
      "<th>#{str}</th>"
    end

    def td(str)
      "<td>#{str}</td>"
    end
    
    def table_end
      puts '</table>'
    end

    def comment(str)
      puts %Q(<p class="comment">[Comment] #{escape_html(str)}</p>)
    end

    def footnote(id, str)
      puts %Q(<p class="comment"><a name="fn-#{id}">#{escape_html(str)}</a></p>)
    end

    def inline_fn(id)
      %Q(<a href="\#fn-#{id}">*#{@chapter.footnote(id).number}</a>)
    end

    def compile_ruby(base, ruby)
      escape_html(base)   # tmp
    end

    def compile_kw(word, alt)
      '<span class="kw">' +
        if alt
        #then escape_html(word + sprintf(@locale[:parens], alt.strip))
        then escape_html(word + " (#{alt.strip})")
        else escape_html(word)
        end +
      '</span>'
    end

    def inline_i(str)
      %Q(<i>#{escape_html(str)}</i>)
    end

    def inline_b(str)
      %Q(<b>#{escape_html(str)}</b>)
    end

    def text(str)
      str
    end

    def nofunc_text(str)
      escape_html(str)
    end

  end

end   # module ReVIEW
