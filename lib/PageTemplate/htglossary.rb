# htmltemplate.rb
#
# An emulation layer on top of PT to mimic HTML::Template
#

############################################################

class PageTemplate
  class HTGlossary < SyntaxGlossary
    # @directive = /<(?:!--\s*(tmpl.+?)\s*--|(TMPL.+?)(?:\/)?)>/mi
    @directive = /(?:<\s*((?:\/?)TMPL_.*?)>|<!--\s*((?:\/?)TMPL.+?)\s*-->)/i

    default { |command|
      puts "default: #{command}"
      TextCommand.new("<!--#{command}-->")
    }

    define(/^tmpl_var (?:name=)?"?((?:\w+)(?:\.\w+\??)*)"?(?:\s+processor="?(\w+)"?)?$/i) {
      |match|
      # Value, Preprocessor, Parser
      ValueCommand.new(match[1],match[2])
    }

    define(/^(tmpl_if|tmpl_unless) (?:name=)?"?((\w+)(\.\w+\??)*)"?$/i) {
      |match|
      # Called_As, Value, parser
      IfCommand.new(match[1],match[2])
    }

    define(/^(tmpl_loop) (?:name=)"?(\w+(?:\.\w+\??)*)"?(?:\s+iterators?="?((?:\s*\w+)+)"?)?$/i) {
      |match|
      # Called_As, Value, Iterators
      LoopCommand.new(match[1],match[2],match[3])
    }

    define(/^tmpl_include (?:name=|file=)?"?((\w+)(?:\.\w+\??)*)"?$/i) {
      |match|
      # Value, parser
      IncludeCommand.new(match[1])
    }

    # Command#else's expect only to be called
    modifier(:elsif) { |cmd,command|
      if command =~ /^\s*tmpl_else\s*$/i
        cmd.else
        true
      else
        false
      end
    }
    modifier(:else) { |cmd,command|
      if command =~ /^\s*tmpl_else\s*$/i
        cmd.else
        true
      else
        false
      end
    }
    modifier(:end) { |cmd,command|
      if command =~ /^\s*\/\s*#{cmd.called_as}\s*$/i
        cmd.end
        true
      else
        false
      end
    }
    modifier(:when) { |cmd,command|
      case command
      when /^tmpl_when\s+(?:name=)"?(\w(?:.\w+\??)*)"?$/i
        cmd.when($1)
        true
      when /^tmpl_else$/i
        cmd.else($1)
        true
      else
        false
      end
    }
  end
end
