# commands.rb
#
# This contains the various Command objects that are the building
# blocks of PageTemplate.
#

############################################################



class PageTemplate
  # Command classes generate text output based on conditions which vary
  # between each class. Command provides an abstract base class to show
  # interface.
  class Command
    attr_reader :called_as
    class << self
      attr_reader :modifier, :closer
    end

    # Subclasses of Command use the output method to generate their text
    # output.  +namespace+ is a Namespace object, which may be 
    # required by a particular subclass.
    #
    # Command#output must return a string
    def output(namespace = nil)
      raise NotImplementedError, 
            "output() must be implemented by subclasses"
    end

    # to_s of a Command prints out class and command information, for
    # debugging and visual summary of the template without parsing the
    # outputs.
    def to_s
      "[ #{self.class} ]"
    end
  end

  # CommentCommand is a command that just returns nothing for its
  # output, allowing the designer to populate their pages with
  # PageTemplate-style comments as well.
  class CommentCommand < Command
    # output returns nothing.
    def output(namespace=nil)
      ''
    end
    # Save the +comment+ for to_s
    def initialize(comment='')
      @comment = comment
    end
    def to_s
      "[ Comment: #{@comment} ]"
    end
  end

  # An UnknownCommand is exactly that: A command we know nothing
  # about.
  #
  # We keep this and save it for future use in case we will know
  # something about it before output is called.
  class UnknownCommand < Command
    # If the command that UnknownCommand is set to exists, find out if
    # the command exists in the Parser's glossary.
    def output(namespace)
      cls = namespace.parser.glossary.lookup(@command)
      case cls
      when UnknownCommand
        "[ Unknown Command: #{@command} ]"
      else
        cls.output(namespace)
      end
    end
    # Save the +command+ and the +parser+, so we can look it
    # up and hopefully 
    def initialize(command)
      @command = command
    end
    def to_s
      "[ UnknownCommand: #{@command} ]"
    end
  end

  # StackableCommand is the parent class of any command that creates a
  # branch in the logic: such as If, Loop, etcetera.
  #
  # Any child that wants to do more than stand alone must inherit from
  # StackableCommand. We recommend setting @called_as, so 
  # all of StackableCommand's ways of closing blocks work.
  class StackableCommand < Command
    @modifier = nil
    @closer   = :end

    def end
    end

    # @called_as is set to the command which this is called as. This
    # allows a number of [% end %], [% end name %], [% endname %] or
    # even [% /name %] to close StackableCommands.
    def initialize(called_as=nil)
      raise ArgumentError, 'StackableCommand should not be called directly'
    end
    def add(block)
      raise ArgumentError, 'StackableCommand should not be called directly'
    end
    def to_s
      "[ #{@called_as} ]"
    end
  end

  # BlockCommand provides a single interface to multiple Command
  # objects.
  # This should probably never be called by the designer or
  # programmer, but by StackableCommands.
  class BlockCommand < Command
    def initialize()
      @commandBlock = []
    end

    # Return Commands held, as a string
    def to_s
      '[ Blocks: ' + @commandBlock.map{ |i| "[#{i.to_s}]" }.join(' ') + ']'
    end
    
    # Returns the number of Commands held in this BlockCommand
    def length
      @commandBlock.length
    end

    # Adds +command+ to the end of the BlockCommand's 
    # chain of Commands.
    #
    # A TypeError is raised if the object being added is not a ((<Command>)).
    def add(command)
      unless command.is_a?(Command)
        raise TypeError, 'BlockCommand.add: Attempt to add non-Command object'
      end
      @commandBlock << command
    end

    # Calls Command#output(namespace) on each Command contained in this 
    # object.  The output is returned as a single string.  If no output
    # is generated, returns an empty string.
    def output(namespace = nil)
      @commandBlock.map{|x| x.output(namespace)}.join('')
    end
  end

  # Template is the top-level blockcommand object
  # It is what is returned on Template.load() or
  # Template.parse()
  #
  # Template should only be called by the Parser, and never
  # by anything else.
  class Template < BlockCommand
    @modifier = nil
    @closer   = nil
    # Template must know about the parser so it can access its
    # namespace.
    def initialize(parser)
      @parser = parser
      super()
    end
    def to_s
      '[ Template: ' + @commandBlock.map{ |i| "[#{i.to_s}]" }.join(' ') + ']'
    end

    # Template is also a NamespaceItem
    include NamespaceItem

    # Template#output is a special case for a Command. Because
    # Template is what's returned by Parser.load() or Parser.parse(),
    # the programmer may well call Template#output(anything).
    #
    # If +object+ is a Namespace, then treat output as a typical
    # BlockCommand. If +object+ is nil, then namespace is
    # @parser. Otherwise, a new namespace is created, a
    # child of @namespace, and is assigned +object+ as its namespace
    def output(object=nil)
      @parent = @parser
      case
      when object.nil?
        super(self)
      when object.is_a?(NamespaceItem)
        @parent = object
        super(self)
      else
        namespace = Namespace.new(self)
        namespace.object = object
        super(namespace)
      end
    end
  end

  # A very simple Command which outputs a static string of text
  class TextCommand < Command

    # Creates a TextCommand object, saving +text+ for future output.
    def initialize(text)
      @text = text
    end

    def to_s
      @text
    end

    # Returns the string provided during this object's creation.
    def output(namespace = nil)
      @text
    end
  end

  # DefineCommand will set a variable within the enclosing namespace
  class DefineCommand < Command
    def initialize(name, value)
      @name = name
      @value = value
    end

    # Doesn't return any output
    def output(namespace)
      namespace[@name] = @value
      return
    end
  end

  # FilterCommand filters its block through a preprocessor
  #  [% filter :processor %]text[% end %]
  class FilterCommand < StackableCommand
    @closer = :end
    def initialize(filter)
      @called_as = "filter"
      @processor = filter
      @text = []
    end

    def add(line)
      @text.push(line)
    end

    def output(namespace=nil)
      parser = namespace.parser if namespace
      parser = Parser.recent_parser unless parser
      namespace ||= parser
      preprocessor = parser.preprocessor
      processor = @processor || parser.default_processor
      text = ""
      @text.each { |c| text += c.output(namespace) }
      if preprocessor.respond_to?(processor)
        preprocessor.send(processor, text)
      else
        "[ ValueCommand: unknown preprocessor #{@processor} ]"
      end
    end
  end

  # ValueCommand will print out a variable name, possibly passing its
  # value through a preprocessor.
  #
  # [% var variable [:processor] %]
  #
  # +variable+ is first plucked out of the Namespace,
  #
  # The to_s of the output from Namespace#get is passed through
  # parser's preprocessor. If :processor is defined, then 
  # parser.preprocessor.send(:processor,body) is called. This allows the
  # designer to choose a particular format for the output. If
  # :processor is not given, then parser's default processor is used.
  class ValueCommand < Command

    # Creates the ValueCommand, with +value+ as the name of the variable
    # to be inserted during output. +parser+ is the Parser object,
    # which we save so we can access its Preprocessor and its default
    # preprocessor
    def initialize(value,preprocessor)
      @value = value
      @processor = preprocessor
    end

    # Requests the value of this object's saved value name from 
    # +namespace+, and returns the string representation of that
    # value to the caller, after passing it through the preprocessor.
    def output(namespace = nil)
      parser = namespace.parser if namespace
      parser = Parser.recent_parser unless parser
      namespace ||= parser
      preprocessor = parser.preprocessor
      processor = @processor || parser.default_processor
      if preprocessor.respond_to?(processor)
        preprocessor.send(processor,namespace.get(@value).to_s)
      else
        "[ ValueCommand: unknown preprocessor #{@processor} ]"
      end
    end

    def to_s
      str = "[ Value: #{@value} "
      str << ":#{@processor} " if (@processor)
      str << ']'
      str
    end
  end

  # IfCommand is a StackableCommand. It requires an opening:
  # [% if variable %] or [% unless variable %].
  #
  # On execution, if +variable+ is true, then the contents of
  # IfCommand's @commands is printed. 
  #
  # [% else %] may be specified for either if or unless, after which
  # objects are added to @falseCommands, and are printed if +variable+
  # is false, instead.
  class IfCommand < StackableCommand
    @modifier = :elsif
    @closer   = :end

    # +command+ must match "if <value>" or "unless <value>"
    def initialize(called_as, value)
      @value = value
      @called_as = called_as
      @trueCommands = []
      @trueCommands << [value,BlockCommand.new]
      @falseCommands = BlockCommand.new
      @in_else = (called_as == 'unless')
      @switched = false
    end
    # Add the command to the @trueCommands or @falseCommands block,
    # depending on if the command is an 'if' or 'unless' and if 'else'
    # has been called.
    def add(command)
      unless @in_else
        @trueCommands.last.last.add command
      else
        @falseCommands.add command
      end
    end
    # an elseif will create a new condition.
    def elsif(value)
      raise Argumentrror, "'elsif' cannot be passed after 'else' or in an 'unless'" if @switched || @in_else
      @trueCommands << [value,BlockCommand.new]
    end
    # an 'else' will modify the command, switching it from adding to
    # @trueCommands to adding to @falseCommands, or vice versa.
    def else
      raise ArgumentError, "More than one 'else' to IfCommand" if @switched
      @in_else = ! @in_else
      @switched = true
    end
    # If @value is true within the context of +namespace+, then print
    # the output of @trueCommands. Otherwise, print the output of
    # @falseCommands
    def output(namespace=nil)
      val = ''
      @trueCommands.each do |val,commands|
        return commands.output(namespace) if namespace.true?(val)
      end
      @falseCommands.output(namespace)
    end
    def to_s
      str = '['
      if @called_as == 'if'
        str = ' If'
        label = ' If'
        str += @trueCommands.map { |val,commands|
          s = "#{label} (#{val}) #{commands}"
          label = ' Elsif'
        }.join('')
        if @falseCommands.length > 0
          str << " else: #{@falseCommands}"
        end
      else
        str = "[ Unless (#{@value}): #{@falseCommands}"
        if @trueCommands.length > 0
          str << " else: #{@trueCommands}"
        end
      end
      str << ' ]'
      str
    end
  end

  # LoopCommand is a StackableCommand. It requires an opening:
  # [% if variable %] or [% unless variable %].
  #
  # +variable+ is fetched from the namespace.
  #
  # On execution, if +variable+ is true, and non-empty, then
  # @commands is printed once with each item in the list placed in
  # its own namespace and passed to the loop commands.
  # (a list is defined as an object that responds to :map)
  #
  # If +variable+ is true, but does not respond to :map, then
  # the list is called once
  #
  # [% else %] may be specified, modifying LoopCommand to print out
  # @elseCommands in case +variable+ is false, or empty.
  class LoopCommand < StackableCommand
    @modifier = :else
    @closer   = :end

    # [% in variable %] or [% loop variable %]
    # Or [% in variable: name %]
    def initialize(called_as, value, iterators)
      @called_as = called_as
      @value     = value
      if iterators
        @iterators = iterators.strip.gsub(/\s+/, ' ').split
      else
        @iterators = nil
      end

      @switched  = false
      @commands  = BlockCommand.new
      @elseCommands = BlockCommand.new
      @in_else = false
    end
    # An 'else' defines a list of commands to call when the loop is
    # empty.
    def else
      raise ArgumentError, "More than one 'else' to IfCommand" if @switched
      @in_else = ! @in_else
      @switched = true
    end
    # adds to @commands for the loop, or @elseCommands if 'else' has
    # been passed.
    def add(command)
      unless @in_else
        @commands.add command
      else
        @elseCommands.add command
      end
    end
    # If +variable+ is true, and non-empty, then @commands is printed
    # once with each item in the list placed in its own namespace and
    # passed to the loop commands.  (a list is defined as an object
    # that responds to :map)
    #
    # If +variable+ is true, but does not respond to :map, then
    # the list is called once
    def output(namespace)

      vals = namespace.get(@value)
      ns = nil
      return @elseCommands.output(namespace) unless vals
      unless vals.respond_to?(:map) && vals.respond_to?(:length)
        vals = [vals]
      end

      return @elseCommands.output(namespace) if vals.empty?

      # Unfortunately, no "map_with_index"
      len = vals.length
      i = 1
      odd = true
      ns = Namespace.new(namespace)

      # Print the output of all the objects joined together.
      case
      when @iterators.nil? || @iterators.empty?
        vals.map { |item|
          ns.clear
          ns.object = item
          ns['__FIRST__'] = (i == 1) ? true : false
          ns['__LAST__'] = (i == len) ? true : false
          ns['__ODD__'] = odd
          ns['__INDEX__'] = i-1
          odd = ! odd
          i += 1
          @commands.output(ns)
        }.join('')
      when @iterators.size == 1
        iterator = @iterators[0]
        vals.map { |item|
          ns.clear_cache
          # We have an explicit iterator - don't set an object for it.
          # ns.object = item
          ns['__FIRST__'] = (i == 1) ? true : false
          ns['__LAST__'] = (i == len) ? true : false
          ns['__ODD__'] = odd
          ns['__INDEX__'] = i-1
          odd = ! odd
          ns[iterator] = item
          i += 1
          @commands.output(ns)
        }.join('')
      else
        vals.map { |list|
          ns.clear_cache
          ns['__FIRST__'] = (i == 1) ? true : false
          ns['__LAST__'] = (i == len) ? true : false
          ns['__ODD__'] = odd
          ns['__INDEX__'] = i-1
          @iterators.each_with_index do |iterator,index|
            ns[iterator] = list[index]
          end
          odd = ! odd
          i += 1
          @commands.output(ns)
        }.join('')
      end
    end
    
    def to_s
      str = "[ Loop: #{@value} " + @commands.to_s
      str << " Else: " + @elseCommands.to_s if @elseCommands.length > 0
      str << ' ]'
      str
    end
  end

  # IncludeCommand allows the designer to include a template from
  # another source.
  #
  # [% include variable %] or [% include literal %]
  #
  # If +literal+ exists in parser.source, then it is called without
  # passing it to its namespace. If it does not exist, then it is
  # evaluated within the context of its namespace and then passed to
  # parser.source for fetching the body of the file/source.
  #
  # The body returned by the Source is then passed to Parser for
  # compilation.
  class IncludeCommand < Command
    def initialize(value)
      @value = value
    end
    def to_s
      "[ Include: #{@value} ]"
    end
    # If @value exists in parser.source, then it is called without
    # passing it to its namespace. If it does not exist, then it is
    # evaluated within the context of its namespace and then passed to
    # parser.source for fetching the body of the file/source.
    #
    # The body returned by the Source is then passed to Parser for
    # compilation.
    def output(namespace)
      # We don't use parser.compile because we need to know when something
      # doesn't exist.
      parser = namespace.parser
      fn = @value
      body = parser.source.get(fn)
      unless body
        fn = namespace.get(@value)
        body = parser.source.get(fn) if fn
      end
      if body.is_a?(Command)
        body.output(namespace)
      elsif body
        cmds = parser.parse(body)
        parser.source.cache(fn,cmds)
        cmds.output(namespace)
      else
        "[ Template '#{fn}' not found ]"
      end
    end
  end
end
