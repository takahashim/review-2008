#
# $Id: exception.rb 3641 2007-01-25 16:48:46Z aamine $
#
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

module ReVIEW

  class Error < ::StandardError; end
  class ApplicationError < Error; end
  class ConfigError < Error; end
  class ApplicationError < Error; end
  class CompileError < Error; end
  class SyntaxError < CompileError; end

end
