# -*- encodin: EUC-JP -*-
#
# $Id: compiler.rb 3927 2008-03-05 06:45:54Z kmuto $
#
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/compat'
require 'review/preprocessor'
require 'review/exception'
require 'lineinput'

module ReVIEW

  class Location
    def initialize(filename, f)
      @filename = filename
      @f = f
    end

    attr_reader :filename

    def lineno
      @f.lineno
    end

    def string
      "#{@filename}:#{@f.lineno}"
    end

    alias to_s string
  end


  class Compiler

    def initialize(strategy)
      @strategy = strategy
    end

    attr_reader :strategy

    def compile(chap)
      @chapter = chap
      do_compile
      @strategy.result
    end

    class SyntaxElement
      def initialize(name, type, argc, &block)
        @name = name
        @type = type
        @argc_spec = argc
        @checker = block
      end

      attr_reader :name

      def check_args(args)
        unless @argc_spec === args.size
          raise CompileError, "wrong # of parameters (block command //#{@name}, expect #{@argc_spec} but #{args.size})"
        end
        @checker.call(*args) if @checker
      end

      def min_argc
        case @argc_spec
        when Range then @argc_spec.begin
        when Integer then @argc_spec
        else
          raise TypeError, "argc_spec is not Range/Integer: #{inspect()}"
        end
      end

      def block_required?
        @type == :block
      end

      def block_allowed?
        @type == :block or @type == :optional
      end
    end

    SYNTAX = {}

    def Compiler.defblock(name, argc, optional = false, &block)
      defsyntax name, (optional ? :optional : :block), argc, &block
    end

    def Compiler.defsingle(name, argc, &block)
      defsyntax name, :line, argc, &block
    end

    def Compiler.defsyntax(name, type, argc, &block)
      SYNTAX[name] = SyntaxElement.new(name, type, argc, &block)
    end

    def syntax_defined?(name)
      SYNTAX.key?(name.to_sym)
    end

    def syntax_descriptor(name)
      SYNTAX[name.to_sym]
    end

    class InlineSyntaxElement
      def initialize(name)
        @name = name
      end

      attr_reader :name
    end

    INLINE = {}

    def Compiler.definline(name)
      INLINE[name] = InlineSyntaxElement.new(name)
    end

    def inline_defined?(name)
      INLINE.key?(name.to_sym)
    end

    defblock :read, 0
    defblock :list, 2
    defblock :emlist, 0
    defblock :cmd, 0
    defblock :table, 2
    defblock :quote, 0
    defblock :image, 2..3, true

    defsingle :footnote, 2
    defsingle :comment, 1
    defsingle :noindent, 0
    defsingle :linebreak, 0
    defsingle :pagebreak, 0

    definline :chapref
    definline :chap
    definline :title
    definline :img
    definline :list
    definline :table
    definline :fn
    definline :kw
    definline :ruby
    definline :bou
    definline :ami
    definline :b

    private

    def do_compile
      f = LineInput.new(Preprocessor::Strip.new(StringIO.new(@chapter.content)))
      @strategy.bind self, @chapter, Location.new(@chapter.basename, f)
      tagged_section_init
      while f.next?
        case f.peek
        when /\A=+[\[\s]/
          compile_headline f.gets
        when %r<\A\s+\*>
          compile_ulist f
        when %r<\A\s+��>
          compile_multichoice f
        when %r<\A\s+��>
          compile_singlechoice f
        when %r<\A\s+\d+\.>
          compile_olist f
        when %r<\A:\s>
          compile_dlist f
        when %r<\A//\}>
          error 'block end seen but not opened'
          f.gets
        when %r<\A//[a-z]+>
          name, args, lines = read_command(f)
          syntax = syntax_descriptor(name)
          unless syntax
            error "unknown command: //#{name}"
            compile_unknown_command args, lines
            next
          end
          compile_command syntax, args, lines
        when %r<\A//>
          line = f.gets
          warn "`//' seen but is not valid command: #{line.strip.inspect}"
          if block_open?(line)
            warn "skipping block..."
            read_block(f)
          end
        else
          if f.peek.strip.empty?
            f.gets
            next
          end
          compile_paragraph f
        end
      end
      close_all_tagged_section
    end

    def compile_headline(line)
      m = /\A(=+)(?:\[(.+?)\])?(.*)/.match(line)
      level = m[1].size
      tag = m[2]
      caption = m[3].strip
      while @tagged_section.last and @tagged_section.last[1] >= level
        close_tagged_section(* @tagged_section.pop)
      end
      if tag
        open_tagged_section tag, level, caption
      else
        @strategy.headline level, @strategy.text(caption)
      end
    end

    def headline(level, caption)
      @strategy.headline level, @strategy.text(caption)
    end

    def tagged_section_init
      @tagged_section = []
    end

    def open_tagged_section(tag, level, caption)
      mid = "#{tag}_begin"
      unless @strategy.respond_to?(mid)
        error "strategy does not support tagged section: #{tag}"
        headline level, caption
        return
      end
      @tagged_section.push [tag, level]
      @strategy.__send__ mid, level, @strategy.text(caption)
    end

    def close_tagged_section(tag, level)
      mid = "#{tag}_end"
      if @strategy.respond_to?(mid)
        @strategy.__send__ mid, level
      else
        error "strategy does not support block op: #{mid}"
      end
    end

    def close_all_tagged_section
      until @tagged_section.empty?
        close_tagged_section(* @tagged_section.pop)
      end
    end

    def compile_ulist(f)
      @strategy.ul_begin
      f.while_match(/\A\s+\*/) do |line|
        buf = [text(line.sub(/\*/, '').strip)]
        f.while_match(/\A\s+(?!\*)\S/) do |cont|
          buf.push text(cont.strip)
        end
        @strategy.ul_item buf
      end
      @strategy.ul_end
    end

    def compile_multichoice(f)
      @strategy.choice_multi_begin
      f.while_match(/\A\s+��/) do |line|
        buf = [text(line.sub(/��/, '').strip)]
        f.while_match(/\A\s+(?!��)\S/) do |cont|
          buf.push text(cont.strip)
        end
        @strategy.ul_item buf
      end
      @strategy.choice_multi_end
    end

    def compile_singlechoice(f)
      @strategy.choice_single_begin
      f.while_match(/\A\s+��/) do |line|
        buf = [text(line.sub(/��/, '').strip)]
        f.while_match(/\A\s+(?!��)\S/) do |cont|
          buf.push text(cont.strip)
        end
        @strategy.ul_item buf
      end
      @strategy.choice_single_end
    end

    def compile_olist(f)
      @strategy.ol_begin
      f.while_match(/\A\s+\d+\./) do |line|
        buf = [text(line.sub(/\d+\./, '').strip)]
        f.while_match(/\A\s+(?!\d+\.)\S/) do |cont|
          buf.push text(cont.strip)
        end
        @strategy.ol_item buf
      end
      @strategy.ol_end
    end

    def compile_dlist(f)
      @strategy.dl_begin
      while /\A:/ =~ f.peek
        @strategy.dt text(f.gets.sub(/:/, '').strip)
        @strategy.dd f.break(/\A\S/).map {|line| text(line.strip) }
        f.skip_blank_lines
      end
      @strategy.dl_end
    end

    def compile_paragraph(f)
      buf = []
      f.until_match(%r<\A//>) do |line|
        break if line.strip.empty?
        buf.push text(line.strip)
      end
      @strategy.paragraph buf
    end

    def read_command(f)
      line = f.gets
      name = line.slice(/[a-z]+/).intern
      args = parse_args(line.sub(%r<\A//[a-z]+>, '').rstrip.chomp('{'))
      lines = block_open?(line) ? read_block(f) : nil
      return name, args, lines
    end

    def block_open?(line)
      line.rstrip[-1,1] == '{'
    end

    def read_block(f)
      head = f.lineno
      buf = []
      f.until_match(%r<\A//\}>) do |line|
        buf.push text(line.rstrip)
      end
      unless %r<\A//\}> =~ f.peek
        error "unexpected EOF (block begins at: #{head})"
        return buf
      end
      f.gets   # discard terminator
      buf
    end

    def parse_args(str)
      return [] if str.empty?
      unless str[0,1] == '[' and str[-1,1] == ']'
        error "argument syntax error: #{str.inspect}"
        return []
      end
      str[1..-2].split('][', -1)
    end

    def compile_command(syntax, args, lines)
      unless @strategy.respond_to?(syntax.name)
        error "strategy does not support command: //#{syntax.name}"
        compile_unknown_command args, lines
        return
      end
      begin
        syntax.check_args args
      rescue CompileError => err
        error err.message
        args = ['(NoArgument)'] * SYNTAX[name].min_argc
      end
      if syntax.block_allowed?
        compile_block syntax, args, lines
      else
        if lines
          error "block is not allowed for command //#{syntax.name}; ignore"
        end
        compile_single syntax, args
      end
    end

    def compile_unknown_command(args, lines)
      @strategy.uknown_command args, lines
    end

    def compile_block(syntax, args, lines)
      @strategy.__send__(syntax.name, (lines || default_block(syntax)), *args)
    end

    def default_block(syntax)
      if syntax.block_required?
        error "block is required for //#{syntax.name}; use empty block"
      end
      []
    end

    def compile_single(syntax, args)
      @strategy.__send__(syntax.name, *args)
    end

    def text(str)
      return '' if str.empty?
      words = str.split(/(@<\w+>\{(?:[^\}\\]+|\\.)*\})/, -1)
      unless words.size / 2 == str.scan(/@<\w+>/).size
        error "`@<xxx>' seen but is not valid inline op: #{str.inspect}"
      end
      result = @strategy.nofunc_text(words.shift)
      until words.empty?
        result << compile_inline(words.shift.gsub(/\\\}/, '}'))
        result << @strategy.nofunc_text(words.shift)
      end
      result
    end
    public :text   # called from strategy

    def compile_inline(str)
      op, arg = /\A@<(\w+)>\{(.*?)\}\z/.match(str).captures
      unless inline_defined?(op)
        raise CompileError, "no such inline op: #{op}"
      end
      unless @strategy.respond_to?("inline_#{op}")
        raise "strategy does not support inline op: @<#{op}>"
      end
      @strategy.__send__("inline_#{op}", arg)
    rescue => err
      error err.message
      @strategy.nofunc_text(str)
    end

    def warn(msg)
      @strategy.warn msg
    end

    def error(msg)
      @strategy.error msg
    end

  end

end   # module ReVIEW
