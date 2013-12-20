#
# $Id: review-index 2227 2006-05-13 00:09:08Z aamine $
#
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of LGPL, see the file "COPYING".
#

require 'review/htmlutils'

module ReVIEW

  class TOCPrinter

    def TOCPrinter.default_upper_level
      99   # no one use 99 level nest
    end

    def initialize(print_upper)
      @print_upper = print_upper
    end

    def print?(level)
      level <= @print_upper
    end

  end


  class TextTOCPrinter < TOCPrinter
    def print_book(book)
      print_children book
    end

    private

    def print_children(node)
      return unless print?(node.level + 1)
      node.each_section_with_index do |sec, idx|
        print_node idx+1, sec
        print_children sec
      end
    end

    LABEL_LEN = 54

    def print_node(seq, node)
      if node.chapter?
        vol = node.volume
        printf "%-#{LABEL_LEN}s %2dKB %5dC %4dL\n",
               "#{chapnumstr(node.number)} #{node.label} (#{node.chapter_id})",
               vol.kbytes, vol.chars, vol.lines
      else
        printf "%-#{LABEL_LEN}s             %4d\n",
               "  #{'   ' * (node.level - 1)}#{seq} #{node.label}",
               node.estimated_lines
      end
    end

    def chapnumstr(n)
      n ? sprintf('%2d.', n) : '   '
    end

    def volume_columns(level, volstr)
      cols = ["", "", "", nil]
      cols[level - 1] = volstr
      cols[0, 3]   # does not display volume of level-4 section
    end

  end


  class HTMLTOCPrinter < TOCPrinter

    include HTMLUtils

    def print_book(book)
      return unless print?(1)
      book.each_section_with_index do |chap, idx|
        name = "chap#{idx+1}"
        label = "��#{idx+1}�� #{chap.label}"
        puts h2(a_name(escape_html(name), escape_html(label)))
        return unless print?(2)
        if print?(3)
          print_chap_sections chap
        else
          print_chapter chap
        end
      end
    end

    private

    def print_chap_sections(chap)
      puts "<ol>"
      chap.each_section do |sec|
        puts li(escape_html(sec.label))
      end
      puts "</ol>"
    end

    def print_chapter(chap)
      chap.each_section do |sec|
        puts h3(escape_html(sec.label))
        next unless print?(4)
        next if sec.n_sections == 0
        puts "<ul>"
        sec.each_section do |node|
          puts li(escape_html(node.label))
        end
        puts "</ul>"
      end
    end

    def h2(label)
      "<h2>#{label}</h2>"
    end

    def h3(label)
      "<h3>#{label}</h2>"
    end

    def li(content)
      "<li>#{content}</li>"
    end

    def a_name(name, label)
      %Q(<a name="#{name}">#{label}</a>)
    end

  end

  class IDGTOCPrinter < TOCPrinter
    def print_book(book)
      puts %Q(<?xml version="1.0" encoding="UTF-8"?>)
      puts %Q(<doc xmlns:aid='http://ns.adobe.com/AdobeInDesign/4.0/'><title aid:pstyle="h0">1���ѡ���1</title><?dtp level="0" section="��1�����ѡ���1"?>) # FIXME: �������ȥ����ˤϡ� && �����Ȥ˷�̤�ʬ����ˤϡ�
      puts %Q(<ul aid:pstyle='ul-partblock'>)
      print_children book
      puts %Q(</ul></doc>)
    end

    private

    def print_children(node)
      return unless print?(node.level + 1)
      node.each_section_with_index do |sec, idx|
        print_node idx+1, sec
        print_children sec
      end
    end

    LABEL_LEN = 54

    def print_node(seq, node)
      if node.chapter?
        vol = node.volume
        printf "<li aid:pstyle='ul-part'>%s</li>\n",
               "#{chapnumstr(node.number)}#{node.label}"
      else
        printf "<li>%-#{LABEL_LEN}s\n",
               "  #{'   ' * (node.level - 1)}#{seq}��#{node.label}</li>"
      end
    end

    def chapnumstr(n)
      n ? sprintf('��%d�ϡ�', n) : ''
    end

    def volume_columns(level, volstr)
      cols = ["", "", "", nil]
      cols[level - 1] = volstr
      cols[0, 3]   # does not display volume of level-4 section
    end
  end
end
