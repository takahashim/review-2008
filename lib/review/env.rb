#
# $Id: env.rb 3861 2008-01-28 07:39:13Z kmuto $
#
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/chapterfile'
require 'review/exception'
require 'review/compat'

module ReVIEW

  @default_env = nil

  def ReVIEW.env
    @default_env ||= Environment.load_default
  end

  class Environment

    def Environment.load_default
      %w( . .. ../.. ).each do |basedir|
        if File.file?("#{basedir}/PARAMS") or File.file?("#{basedir}/CHAPS")
          return load(basedir)
        end
      end
      new('.')
    end

    def Environment.load(dir)
      update_rubyenv dir
      if File.file?("#{dir}/PARAMS")
      then new(dir, load_params("#{dir}/PARAMS"))
      else new(dir)
      end
    end

    def Environment.load_params(path)
      mod = Module.new
      mod.module_eval File.read(path), path
      {
        :chapter_file => const_get_safe(mod, :CHAPS_FILE),
        :index_file   => const_get_safe(mod, :INDEX_FILE),
        :reject_file  => const_get_safe(mod, :REJECT_FILE) ||
                         const_get_safe(mod, :WORDS_FILE),
        :nocode_file  => const_get_safe(mod, :NOCODE_FILE),
        :predef_file  => const_get_safe(mod, :PREDEF_FILE),
        :postdef_file => const_get_safe(mod, :POSTDEF_FILE),
        :ext          => const_get_safe(mod, :EXT),
        :image_dir    => const_get_safe(mod, :IMAGE_DIR),
        :image_types  => const_get_safe(mod, :IMAGE_TYPES),
        :page_metric  => get_page_metric(mod)
      }
    end

    def Environment.get_page_metric(mod)
      if paper = const_get_safe(mod, :PAPER)
        unless PageMetric.respond_to?(paper.downcase)
          raise ConfigError, "unknown paper size: #{paper}"
        end
        return PageMetric.send(paper.downcase)
      end
      PageMetric.new(const_get_safe(mod, :LINES_PER_PAGE_list) || 46,
                     const_get_safe(mod, :COLUMNS_list)        || 80,
                     const_get_safe(mod, :LINES_PER_PAGE_text) || 30,
                     const_get_safe(mod, :COLUMNS_text)        || 74)  # 37zw
    end

    def Environment.const_get_safe(mod, name)
      return nil unless mod.const_defined?(name)
      mod.const_get(name)
    end
    private_class_method :const_get_safe

    @basedir_seen = {}

    def Environment.update_rubyenv(dir)
      return if @basedir_seen.key?(dir)
      if File.directory?("#{dir}/lib/review")
        $LOAD_PATH.unshift "#{dir}/lib"
      end
      if File.file?("#{dir}/review-ext.rb")
        Kernel.load File.expand_path("#{dir}/review-ext.rb")
      end
      @basedir_seen[dir] = true
    end

    def initialize(basedir, params = {})
      @basedir = basedir
      @chapter_file = params[:chapter_file] || 'CHAPS'
      @index_file   = params[:index_file]   || 'INDEX'
      @reject_file  = params[:reject_file]  || 'REJECT'
      @nocode_file  = params[:nocode_file]  || 'NOCODE'
      @predef_file  = params[:predef_file]  || 'PREDEF'
      @postdef_file = params[:postdef_file] || 'POSTDEF'
      @page_metric  = params[:page_metric]  || PageMetric.a5
      @ext          = params[:ext]          || '.re'
      @image_dir    = params[:image_dir]    || 'images'
      @image_types  = unify_exts(params[:image_types]  ||
                                 %w( eps tif tiff png bmp jpg jpeg gif ))
      @parts = nil
      @chapter_index = nil
    end

    def unify_exts(list)
      list.map {|ext| (ext[0] == '.') ? ext : ".#{ext}" }
    end
    private :unify_exts

    def self.path_param(name)
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def #{name}
          "\#{@basedir}/\#{@#{name}}"
        end
      End
    end

    path_param  :chapter_file
    path_param  :index_file
    path_param  :reject_file
    path_param  :nocode_file
    path_param  :predef_file
    path_param  :postdef_file
    attr_reader :ext
    path_param  :image_dir
    attr_reader :image_types
    attr_reader :page_metric

    def chaps
      parts().flatten
    end

    def parts
      return @parts if @parts
      num = 0
      mainparts = read_CHAPS()\
          .strip.lines.map {|line| line.strip }.join("\n").split(/\n{2,}/)\
          .map {|part|
            part.split.map {|name|
              ChapterFile.new(self, (num += 1), @basedir, name)
            }
          }

      if File.file?("#{@basedir}/preface#{@ext}")
        mainparts.unshift [ChapterFile.new(self, nil, @basedir, "preface#{@ext}")]
      end

      if !read_PREDEF().empty?
        read_PREDEF().strip.lines.map {|line| line.strip }.join("\n").map.reverse_each {|line|
          (name, mark) = line.split(/\s/)
          mainparts.unshift [ChapterFile.new(self, mark, @basedir, name)]
        }
      end

      if File.file?("#{@basedir}/appendix#{@ext}")
        mainparts.push [ChapterFile.new(self, nil, @basedir, "appendix#{@ext}")]
      end

      if !read_POSTDEF().empty?
        read_POSTDEF().strip.lines.map {|line| line.strip }.join("\n").map.reverse_each {|line|
          (name, mark) = line.split(/\s/)
          mainparts.push [ChapterFile.new(self, mark, @basedir, name)]
        }
      end

      @parts = mainparts
    end

    def chapter_index
      @chapter_index ||= ChapterIndex.new(chaps())
    end

    def chapter(id)
      chapter_index()[id]
    end

    private

    def read_CHAPS
      File.read("#{@basedir}/#{@chapter_file}")
    rescue Errno::ENOENT
      Dir.entries(@basedir).select {|ent| File.extname(ent) == @ext }.sort.join("\n")
    end

    def read_PREDEF
      File.read("#{@basedir}/#{@predef_file}")
    rescue Errno::ENOENT
      return ""
    end

    def read_POSTDEF
      File.read("#{@basedir}/#{@postdef_file}")
    rescue Errno::ENOENT
      return ""
    end

    def add_prefix(pathes)
      return pathes unless pathes.all? {|path| not File.exist?(path) }
      raise 'must not happen' unless File.directory?('manuscript')
      pathes.map {|path| 'manuscript/' + path }
    end

    def makevar(name)
      read_makefile_param(search_makefile(), name)
    end

    def search_makefile
      %w( . .. ).each do |dir|
        path = "#{@basedir}/#{dir}/Makefile"
        return path if File.file?(path)
      end
      raise ConfigError, 'Makefile not found'
    end

    def read_makefile_param(path, name)
      File.open(path) {|f|
        while line = f.gets
          if /\A#{name}\s*=\s*/ === line
            buf = line.sub(/\A.*=/, '')
            while /\\$/ === line
              buf.strip!
              buf.chop!
              buf << ' ' << (line = f.gets)
            end
            return buf.split
          end
        end
      }
      nil
    end
  
  end


  PageMetric = Struct.new(:list, :text)
  Metric = Struct.new(:n_lines, :n_columns)

  class << PageMetric
    alias _new new
    remove_method :new

    def new(ll, lt, cl, ct)
      _new(Metric.new(ll, lt), Metric.new(cl, ct))
    end

    def a5
      new(46, 80, 30, 74)
    end
  end

end
