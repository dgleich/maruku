=begin maruku_doc
Extension: math
Attribute: html_math_engine
Scope: document, element
Output: html
Summary: Select the rendering engine for MathML.
Default: <?mrk Globals[:html_math_engine].to_s ?>

Select the rendering engine for math.

If you want to use your custom engine `foo`, then set:

  HTML math engine: foo
{:lang=markdown}

and then implement two functions:

  def convert_to_mathml_foo(kind, tex)
    ...
  end
=end

=begin maruku_doc
Extension: math
Attribute: html_png_engine
Scope: document, element
Output: html
Summary: Select the rendering engine for math.
Default: <?mrk Globals[:html_math_engine].to_s ?>

Same thing as `html_math_engine`, only for PNG output.

  def convert_to_png_foo(kind, tex)
    # same thing
    ...
  end
{:lang=ruby}

=end

module MaRuKu
  module Out
    module HTML
      # Creates an xml Mathml document of this node's TeX code.
      #
      # @return [REXML::Document]
      def render_mathml(kind, tex)
        engine = get_setting(:html_math_engine)
        method = "convert_to_mathml_#{engine}"
        if self.respond_to? method
          mathml = self.send(method, kind, tex)
          return mathml || convert_to_mathml_none(kind, tex)
        end

        # TODO: Warn here
        puts "A method called #{method} should be defined."
        return convert_to_mathml_none(kind, tex)
      end

      # Renders a PNG image of this node's TeX code.
      # Returns
      #
      # @return [MaRuKu::Out::HTML::PNG, nil]
      #   A struct describing the location and size of the image,
      #   or nil if no library is loaded that can render PNGs.
      def render_png(kind, tex)
        engine = get_setting(:html_png_engine)
        method = "convert_to_png_#{engine}".to_sym
        return self.send(method, kind, tex) if self.respond_to? method

        puts "A method called #{method} should be defined."
        return nil
      end
      
      # Renders a MathJax block of out this node's TeX code.
      #
      # @return [REXML::Document]
      def render_mathjax(kind,tex)
        if kind == :equation
          # using the script that works with Instapaper
          # see http://www.leancrew.com/all-this/2010/11/mathjax-markdown-and-instapaper/
          # <span class="MathJax_Preview"><code>[math]</code></span>
          # <script type="math/tex; mode=display">\int f(x) = F(x)</script>
			
          equation = create_html_element 'span'
          
          span = create_html_element 'span'
          add_class_to(span,'MathJax_Preview')
          code = convert_to_mathml_none(:equation, tex.strip)	
          span << code
			
          script = create_html_element 'script'
          script.attributes['type'] = 'math/tex; mode=display'
          script << Text.new("#{tex.strip}")
			
          equation << span 
          equation << script
			
          return equation
        else
          script = create_html_element 'script'
          script.attributes['type'] = 'math/tex'
          script << Text.new("#{tex.strip}")
          return script
        end
      end

      def pixels_per_ex
        $pixels_per_ex ||= render_png(:inline, "x").height
      end

      def adjust_png(png, use_depth)
        src = png.src

        height_in_px = png.height
        depth_in_px = png.depth
        height_in_ex = height_in_px / pixels_per_ex
        depth_in_ex = depth_in_px / pixels_per_ex
        total_height_in_ex = height_in_ex + depth_in_ex
        style = ""
        style << "vertical-align: -#{depth_in_ex}ex;" if use_depth
        style << "height: #{total_height_in_ex}ex;"

        img = Element.new 'img'
        img.attributes['src'] = src
        img.attributes['style'] = style
        img.attributes['alt'] = "$#{self.math.strip}$"
        img
      end

      def to_html_inline_math
        mathml  = get_setting(:html_math_output_mathml)  && render_mathml(:inline, self.math)
        png     = get_setting(:html_math_output_png)     && render_png(:inline, self.math)
        mathjax = get_setting(:html_math_output_mathjax) && render_mathjax(:inline, self.math)

        span = create_html_element 'span'
        add_class_to(span, 'maruku-inline')

        if mathml
          add_class_to(mathml, 'maruku-mathml')
          return mathml
        end

        if png
          img = adjust_png(png, true)
          add_class_to(img, 'maruku-png')
          span << img
        end
        
        if mathjax
          span << mathjax
        end

        span
      end

      def to_html_equation
        mathml  = get_setting(:html_math_output_mathml)  && render_mathml(:equation, self.math)
        png     = get_setting(:html_math_output_png)     && render_png(:equation, self.math)
        mathjax = get_setting(:html_math_output_mathjax) && render_mathjax(:equation, self.math)
        
        if mathjax
          span = create_html_element 'span'
          add_class_to(span, 'maruku-equation')
			
          span << mathjax
			
          # mathjax handles equation numbering
          return span
        end

        div = create_html_element 'div'
        add_class_to(div, 'maruku-equation')
        if mathml
          if self.label  # then numerate
            span = Element.new 'span'
            span.attributes['class'] = 'maruku-eq-number'
            span << Text.new("(#{self.num})")
            div << span
            div.attributes['id'] = "eq:#{self.label}"
          end	
          add_class_to(mathml, 'maruku-mathml')
          div << mathml
        end

        if png
          img = adjust_png(png, false)
          add_class_to(img, 'maruku-png')
          div << img
          if self.label  # then numerate
            span = Element.new 'span'
            span.attributes['class'] = 'maruku-eq-number'
            span << Text.new("(#{self.num})")
            div << span
            div.attributes['id'] = "eq:#{self.label}"
          end	
        end

        source_span = Element.new 'span'
        add_class_to(source_span, 'maruku-eq-tex')
        code = convert_to_mathml_none(:equation, self.math.strip)
        code.attributes['style'] = 'display: none'
        source_span << code
        div << source_span

        div
      end

      def to_html_eqref
        unless eq = self.doc.eqid2eq[self.eqid]
          maruku_error "Cannot find equation #{self.eqid.inspect}"
          return Text.new("(eq:#{self.eqid})")
        end

        a = Element.new 'a'
        a.attributes['class'] = 'maruku-eqref'
        a.attributes['href'] = "#eq:#{self.eqid}"
        a << Text.new("(#{eq.num})")
        a
      end

      def to_html_divref
        unless hash = self.doc.refid2ref.values.find {|h| h.has_key?(self.refid)}
          maruku_error "Cannot find div #{self.refid.inspect}"
          return Text.new("\\ref{#{self.refid}}")
        end
        ref= hash[self.refid]

        a = Element.new 'a'
        a.attributes['class'] = 'maruku-ref'
        a.attributes['href'] = "#" + self.refid
        a << Text.new(ref.num.to_s)
        a
      end
    end
  end
end
