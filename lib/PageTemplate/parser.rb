# parser.rb
#
# This contains the guts of the engines that make PageTemplate work.
#

############################################################

class PageTemplate

  # A Namespace object consists of three things:
  #
  # parent: A parent object to get a value from if the namespace
  # does not 'know' a value.
  #
  # object: An object is a hash or list that contains the values that
  # this namespace will refer to. It may also be an object, in which
  # case, its methods are treated as a hash, with respond_to? and
  # send()
  #
  # Cache: A cache ensures that a method on an object will only be
  # called once.
  module NamespaceItem
    attr_accessor :parent, :object

    # Clears the cache
    def clear
      @values = Hash.new
    end
    alias_method :clear_cache, :clear

    # Saves a variable +key+ as the string +value+ in the global 
    # namespace.
    def set(key, value)
      @values ||= {}
      @values[key] = value
    end
    alias_method :[]=, :set

    # Returns the first value found for +key+ in the nested namespaces.
    # Returns nil if no value is found.
    #
    # Values are checked for in this order through each level of namespace:
    # 
    # * level.key
    # * level.key()
    # * level[key]
    #
    # If a value is not found in any of the nested namespaces, get()
    # searches for the key in the global namespace.
    #
    # If +val+ is a dot-separated list of words, then 'key' is the
    # first part of it.  The remainder of the words are sent to key
    # (and further results) to premit accessing attributes of objects.
    def get(val,clean_rescue=true)
      args = parser.args
      @values ||= {}
      @object ||= nil

      clean_rescue = !args['raise_on_error'] if clean_rescue

      val.gsub!(/[#{Regexp.escape(parser.method_separators)}]/,'.')

      key, rest = val.split(/\./, 2)

      value = case
      when @values.has_key?(key)
        @values[key]
      when @values.has_key?(key.to_sym)
        @values[key.to_sym]
      when !@object
        if @parent
          @parent.get(val)
        else
          nil
        end
      when @object.respond_to?(:has_key?)
        if @object.has_key?(key)
          @values[key] = @object[key]
        else
          return @parent.get(val) if @parent
          nil
        end
      when @object.respond_to?(sym = key.to_sym)
        @values[key] = @object.send(sym)
      when key == '__ITEM__'
        @object
      when @parent
        return @parent.get(val)
      else
        nil
      end

      if rest
        names = [key]
        rest.split(/\./).each do |i|
          names << i
          name = names.join('.')
          begin
            value = if @values.has_key?(name)
              @values[name]
            else
              @values[name] = value = case
              when @values.has_key?(name)
                @values[name]
              when value.respond_to?(:has_key?) # Hash
                value[i]
              when value.respond_to?(:[]) && i =~ /^\d+$/ # Array
                value[i.to_i]
              when value.respond_to?(i) # Just a method
                value.send(i)
              else
                nil
              end
            end
          rescue NoMethodError => er
            return nil
          end
        end
      end
      value
    rescue Exception => e
      if clean_rescue
        "[ Error: #{e.message} ]"
      else
        raise e
      end
    end
    alias_method :[], :get

    # Removes an entry from the Namespace
    def delete(key)
      @values.delete(key)
    end

    # parser: most namespace objects won't be a parser, but pass this
    # query up to the parser object.
    def parser
      if @parent
        @parent.parser
      else
        Parser.recent_parser
      end
    end

    # A convenience method to test whether a variable has a true
    # value. Returns nil if +flag+ is not found in the namespace, 
    # or +flag+ has a nil value attached to it.
    def true?(flag)
      args = parser.args
      val = get(flag,false)
      case
      when ! val
        false
      when args['empty_is_true']
        true
      when val.respond_to?(:empty?)
        ! val.empty?
      else
        true
      end
    rescue Exception => er
      false
    end
  end

  class Namespace
    include NamespaceItem

    def initialize(parent=nil,object=nil)
      @values = Hash.new
      @parent = parent
      @object = object
    end

    # Create a new top-level Namespace with a Hash-like object
    def Namespace.construct_from(arg)
      ns = Namespace.new()
      arg.each { |k, v|
        ns[k] = v
      }
      return ns
    end
  end

  # A Source is a source from which templates are drawn.
  #
  # Source#get(name) must return the body of the template that is to
  # be parsed, or nil if it doesn't exist.
  class Source

    def initialize(args = {})
      @args  = args
    end

    def get(name=nil)
      name
    end
  end

  # A StringSource is created with a raw string, which is returned on any
  # call to 'get'.
  class StringSource < Source
    def initialize(args)
      if args.class == String
        @source = args
      else
        @args = args
        @source = args["source"]
      end
    end
    def get()
      return @source
    end
  end

  # FileSource provides access to files within the 'include_paths'
  # argument.
  #
  # It attempts to be secure by not allowing any access outside of
  # The directories detailed within include_paths
  class FileSource < Source
    attr_accessor :paths

    # initialize looks for the following in the args Hash:
    #  * include_paths = a list of file paths
    #  * include_path  = a single file path string 
    #                    (kept for backwards compatibility)
    def initialize(args = {})
      @args  = args
      if @args['include_paths']
        @paths = @args['include_paths']
      elsif @args['include_path']
        @paths = [ @args['include_path'] ]
      else
        @paths = [Dir.getwd,'/']
      end
      @paths = @paths.compact
      @cache = Hash.new(nil)
      @mtime = Hash.new(0)
    end

    # Return the contents of the file +name+, which must be within the
    # include_paths.
    def get(name)
      fn = get_filename(name)
      begin
        case
      when fn.nil?
        nil
      when @cache.has_key?(fn) && (@mtime[fn] > File.mtime(fn).to_i)
        cmds = @cache[fn]
        cmds.clear_cache
        cmds
      else
        IO.read(fn)
      end
      rescue Exception => er
        return "[ Unable to open file #{fn} because of #{er.message} ]"
      end
    end
    def cache(name,cmds)
      fn = get_filename(name)
      @cache[fn] = cmds.dup
      @mtime[fn] = Time.now.to_i
    end
    def get_filename(file)
      # Check for absolute filepaths
      if file == File.expand_path(file)
        if File.exists?(file)
          return file
        end
      end
      file = file.gsub(/\.\.\//,'') 
      @paths.each do |path|
        fn = File.join(path,file)
        fn.untaint
        if File.exists?(fn)
          return fn
        end
      end
      return nil
    end
  end

  # This is the dictionary of commands and the directive that Parser
  # uses to compile a template into a tree of commands.
  #
  # directive is the general format of a PageTemplate command.
  # Default: /\[%(.+?)%\]/m
  #
  # @glossary is a hash table of regexp->Command objects. These
  # regexps should not contain PageTemplate command text. i.e:
  # /var \w+/i should be used instead of /[% var %]/
  class SyntaxGlossary
    class << self
      attr_accessor :directive
      attr_writer :default
      def default(&block)
        if block_given?
          @default = block
        else
          @default
        end
      end

      # Look up +command+ to see if it matches a command within the lookup
      # table, returning the instance of the command for it, or
      # an UnknownCommand if none match.
      def lookup(command)
        @glossary.each do |key,val|
          if m = key.match(command)
            return val.call(m)
          end
        end

        return @default.call(command)
      end
      def modifies?(modifier,cmd,command)
        @modifiers[modifier].call(cmd,command)
      end
    
      # Define a regexp -> Command mapping.
      # +rx+ is inserted in the lookup table as a key for +command+
      def define(rx,&block)
        raise ArgumentError, 'First argument to define must be a Regexp' unless rx.is_a?(Regexp)
        raise ArgumentError, 'Block expected' unless block
        @glossary ||= {}
        @glossary[rx] = block
      end

      def modifier(sym,&block)
        raise ArgumentError, 'First argument to define must be a Symbol' unless sym.is_a?(Symbol)
        raise ArgumentError, 'Block expected' unless block
        @modifiers ||= Hash.new(lambda { false })
        @modifiers[sym] = block
      end

      # This is shorthand for define(+key+,Valuecommand), and also
      # allows +key+ to be a string, converting it to a regexp before
      # adding it to the dictionary.
      def define_global_var(rx)
        @glossary ||= {}
        rx = /^(#{key.to_s}(?:\.\w+\??)*)(?:\s:(\w+))?$/ unless rx.is_a?(Regexp)
        @glossary[rx] = lambda { |match|
          ValueCommand.new(match[1],match[2])
        }
      end
    end
  end

  # This is the regexp we tried using for grabbing an entire line
  # Good for everything but ValueCommand :-/.
  # /(?:^\s*\[%([^\]]+?)%\]\s*$\r?\n?|\[%(.+?)%\])/m,
  class DefaultGlossary < SyntaxGlossary
    @directive = /\[%(.+?)%\]/m

    default { |command|
      UnknownCommand.new(command)
    }

    define(/^var ((?:\w+)(?:\.\w+\??)*)(?:\s+:(\w+))?$/i) { |match|
      # Value, Preprocessor
      ValueCommand.new(match[1],match[2])
    }

    define(/^--(.+)$/i) { |match|
    # The Comment
      CommentCommand.new(match[1])
    }

    define(/^define (\w+)\s+?(.+)$/i) { |match|
      DefineCommand.new(match[1], match[2])
    }

    define(/^filter :(\w+)$/i) { |match|
      FilterCommand.new(match[1])
    }

    define(/^(if|unless) ((\w+)(\.\w+\??)*)$/i) { |match|
      # Called_As, Value
      IfCommand.new(match[1],match[2])
    }

    define(/^(in|loop) (\w+(?:\.\w+\??)*)(?:\:((?:\s+\w+)+))?$/i) { |match|
      # Called_As, Value, Iterators
      LoopCommand.new(match[1],match[2],match[3])
    }

    define(/^include ((\w+)(?:\.\w+\??)*)$/i) { |match|
      # Value
      IncludeCommand.new(match[1])
    }

    # Command#else's expect only to be called
    modifier(:else) { |cmd,command|
      puts "Uh, whoops? #{command}" if command =~ /tmpl/mi
      case command
      when /^(else|no|empty)$/i
        cmd.else
        true
      else
        false
      end
    }

    # elsif: accepts else and elsif
    modifier(:elsif) { |cmd,command|
      case command
      when /^(?:elsif|elseif|else if) (.+)$/i
        cmd.elsif($1)
        true
      when /^(else|no|empty)$/i
        cmd.else
        true
      else
        false
      end
    }

    # Command#end
    # accepts 'end', 'end(name)' and 'end (name)'
    modifier(:end) { |cmd,command|
      case command
      when /^end\s*(#{cmd.called_as})?$/i
        cmd.end
        true
      else
        false
      end
    }
    # For case statements.
    modifier(:when) { |cmd,command|
      case command
      when /^when\s+(\w(?:.\w+\??)*)$/i
        cmd.when($1)
        true
      when /^else$/i
        cmd.else
        true
      else
        false
      end
    }
  end

  # Preprocessor is a parent class for preprocessors.
  # A preprocessor is used to process or otherwise prepare output for
  # printing by Valuecommand
  #
  # Preprocessors must be objects, that take a string to convert in
  # some form. Typically singletons.
  class Preprocessor
  end

  class DefaultPreprocessor
    class << self
      # Default, unescaped string.
      def unescaped(str)
        str
      end
      # :process, for backwards compatability.
      alias_method :process, :unescaped
      # Reverse the string. Don't see any use for this :D.
      def reverse(str)
        str.reverse
      end
      # escape URIs into %20-style escapes.
      def escapeURI(string)
        string.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
        end.tr(' ', '+')
      end
      # Escape all HTML
      def escapeHTML(string)
        str = string.gsub(/&/n, '&amp;')
        str.gsub!(/\"/n, '&quot;')
        str.gsub!(/>/n, '&gt;')
        str.gsub!(/</n, '&lt;')
        str
      end
      # Escape HTML, but also turn newlines into <br />s
      def simple(str)
        escapeHTML(str).gsub(/\r\n|\n/,"<br />\n")
      end
    end
  end

  # The big ass parser that does all the dirty work of turning
  # templates into compiled commands.
  #
  # Parser.new() accepts a hash as an argument, and looks for these
  # keys: (with defaults)
  #
  #  'namespace' => A namespace object. (A new namespace)
  #  'glossary'  => A SyntaxGlossary class singleton. (DefaultGlossary)
  #  'preprocessor' => The preprocessor. (DefaultPreprocessor)
  #  'default_processor' => The processor. (:process)
  #  'source' => The Source for templates. (FileSource)
  #
  # Once the parser is created, it can compile and parse any number of
  # templates. 
  #
  # It can be treated as a one-template item by using
  # Parser#load(template), and calling Parser.output
  #
  # To create separate generated templates from the same engine, use
  # Parser#parse, or Parser#load. (It will still keep the most recent
  # one it's #load'd, but that will not affect previously parsed or
  # loaded)
  class Parser
    attr_reader :preprocessor, :default_processor
    attr_reader :glossary, :namespace, :source
    attr_reader :args, :commands, :method_separators

    # This is corny, but recent_parser returns the most recently created
    # Parser.
    def Parser.recent_parser
      @@recent_parser
    end
    # Parser.new() accepts a hash as an argument, and looks for these
    # keys: (with defaults)
    #
    #  'namespace' => A namespace object. (A new namespace)
    #  'glossary'  => A SyntaxGlossary object. (a dup of DEFAULTGLOSSARY)
    #  'preprocessor' => The preprocessor. (DefaultPreprocessor)
    #  'default_processor' => The processor. (:process)
    #  'source' => The Source for templates. (FileSource)
    def initialize(args = {})
      @namespace    = self
      @@recent_parser = self
      @args         = args # For sub-commands
      @parent       = args['namespace'] || nil
      if @parent
        unless @parent.is_a? Namespace then
          @parent = Namespace.construct_from(args['namespace'])
        end
      end
      @glossary     = args['glossary'] || DefaultGlossary
      @preprocessor = args['preprocessor'] || DefaultPreprocessor
      @default_processor = args['default_processor'] || :unescaped
      @method_separators = args['method_separators'] || './'
      @source       = (args['source'] || FileSource).new(@args)
      @commands     = nil
    end
    # Load +name+ from a template, and save it to allow this parser to
    # use it for output.
    def load(name)
      @commands = compile(name)
    end
    # Load +name+ from a template, but do not save it.
    def compile(name)
      body = @source.get(name)
      case
      when body.is_a?(Command)
        body
      when body
        cmds = parse(body)
        @source.cache(name,cmds) if @source.respond_to?(:cache)
        cmds
      else
        cmds = Template.new(self)
        cmds.add TextCommand.new("[ Template '#{name}' not found ]")
        cmds
      end
    end
    # Compile a Template (BlockCommand) from a string. Does not save
    # the commands.
    def parse(body)
      rx = @glossary.directive
      stack = [Template.new(self)]
      stack[0].parent = self
      last = stack.last
      modifier = nil
      closer = nil
      while (m = rx.match(body))
        pre = m.pre_match
        command = m[1..-1].compact.first.strip.gsub(/\s+/,' ')
        body = m.post_match
        
        # Convert all pre-text to a TextCommand
        if (pre && pre.length > 0)
          stack.last.add TextCommand.new(pre)
        end

        # If the command at the top of the stack is a 'Stacker',
        # Does this command modify it? If so, just skip back.
        next if modifier && @glossary.modifies?(modifier,last,command)

        # If it closes, we're done changing this. Pop it off the
        # Stack and add it to the one above it.
        if closer and @glossary.modifies?(closer,last,command)
          cmd = stack.pop
          last = stack.last
          last.add(cmd)
          modifier = last.class.modifier
          closer = last.class.closer
          next
        end

        # Create the command
        cmd = @glossary.lookup(command)
        
        # If it's a stacking command, push it on the stack
        if cmd.is_a?(StackableCommand)
          modifier = cmd.class.modifier
          closer   = cmd.class.closer
          stack.push cmd
          last = cmd
        else
          last.add cmd
        end
      end
      stack.last.add TextCommand.new(body) if body && body.length > 0
      if (stack.length > 1)
        raise ArgumentError, 'Mismatched command closures in template'
      end
      stack[0]
    end

    # Since a Parser is also a namespace object, include NamespaceItem
    include NamespaceItem
    # But redefine parser
    def parser
      self
    end

    # Not really of any point, but clears the saved commands.
    def clearCommands
      @commands = nil
    end
    # If any commands are loaded and saved, return a string of it.
    def output(*args)
      return '' unless @commands
      @commands.output(*args)
    end
  end
end
