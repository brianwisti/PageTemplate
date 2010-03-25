= PageTemplate.rb README

Use PageTemplate.rb to create output based on template pages and 
the code of your program.  This package is inspired by, but not 
quite like, Perl's HTML::Template package.  Its main intent is to 
separate design and code for CGI programs, but it could be useful 
in other contexts as well (Ex: site generation packages).

PageTemplate.rb is distributed under the MIT License, which is included
within this document in the License section.  

As a side note: if you are using PageTemplate in your projects, or 
add features to your copy, I'd love to hear about it.  If you feel like
it.

Brian Wisti (brian.wisti at gmail)
Greg Millam (walker at rubyforge)

http://coolnamehere.com/products/pagetemplate

== Features

* Variable substitution
* If, Unless, and If/Else structures
* Loops and Loop/Else structures
* Customizable Syntax
* Include content from external files (new in 1.1)

== Requirements

  * ruby 1.8

== Install

=== Generic Install

De-Compress archive and enter its top directory.
Then type:

   ($ su)
    # ruby setup.rb 

You can also install files into your favorite directory
by supplying setup.rb some options. Try "ruby setup.rb --help".
Since we don't really know how setup.rb works, we've included
the English-language version of the setup usage file. Enjoy.

=== Install With Rake

    $ rake
    $ sudo rake install

=== Install With RubyGems

Download the gem file from the 
[PageTemplate RubyForge page]:http://rubyforge.org/projects/pagetemplate/

Then, use the gem command to install it:

    $ sudo gem install -l PageTemplate-2.2.3.gem

I think that's all there is to it. I'm new to gems, though, so let me
know if I missed something.

== Usage

PageTemplate.rb is a class library, and has no command line or 
interactive capabilities.  See PageTemplate for a
reference to the classes and methods contained in this package.
There is a tutorial and user guide available online, at 
http://pagetemplate.org/

== License

The MIT License

Copyright (c) 2002-2006 Brian Wisti, Greg Millam

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



Brian Wisti (brian.wisti at gmail)
Greg Millam (walker at rubyforge)
