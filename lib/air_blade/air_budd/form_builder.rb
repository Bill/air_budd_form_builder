module AirBlade
  module AirBudd

    class BaseBuilder < ActionView::Helpers::FormBuilder
      include Haml::Helpers if defined? Haml       # for compatibility
      include ActionView::Helpers::TextHelper      # so we can use concat
      include ActionView::Helpers::CaptureHelper   # so we can use capture


      # Rails' render_partial calls this (to_s) to find default form
      # when you do something like: render :partial => f (for some builder f)
      # By defining this as an unchanging value for this class and subclasses
      # we enable reuse of templates between form rendering and div rendering.
      def self.to_s
        'FormBuilder'
      end
      
      # App-wide form configuration.
      # E.g. in config/initializers/form_builder.rb:
      #
      #   AirBlade::AirBudd::FormBuilder.default_options[:required_signifier] = '*'
      #
      class_inheritable_reader :default_options
      class_inheritable_hash_writer :default_options, :instance_writer => false

      self.default_options = { :label_suffix => ':'}

      # Within the form's block you can get good buttons with:
      #
      #   <% f.buttons do |b| %>
      #     <%= b.save %>
      #     <%= b.cancel %>
      #   <% end %>
      #
      # You can have save, cancel, edit and delete buttons.
      # Each one takes an optional label.  For example:
      #
      #     <%= b.save :label => 'Update' %>
      #
      # See the documentation for the +button+ method for the
      # options you can use.
      #
      # You could call the button method directly, e.g. <%= f.button %>,
      # but then your button would not be wrapped with a div of class
      # 'buttons'.  The div is needed for the CSS.
      def buttons(&block)
        content = capture(self, &block)
        concat '<div class="buttons">', block.binding
        concat content, block.binding
        concat '</div>', block.binding
      end

      # Buttons and links for REST actions.  Actions that change
      # state, i.e. save and delete, have buttons.  Other actions
      # have links.
      #
      # For visual feedback with colours and icons, save is seen
      # as a positive action; delete is negative.
      #
      # type = :new|:save|:cancel|:edit|:delete
      # TODO :all ?
      #
      # Options you can use are:
      #   :label - The label for the button or text for the link.
      #            Optional; defaults to capitalised purpose.
      #   :icon  - Whether or not to show an icon to the left of the label.
      #            Optional; icon will be shown unless :icon set to false.
      #   :url   - The URL to link to (only used in links).
      #            Optional; defaults to ''.
      def button(purpose = :save, options = {}, html_options = {})
        # TODO: DRY the :a and :button.
        element, icon, nature = case purpose
                                when :new    then [:a,      'add',        'positive']
                                when :save   then [:button, 'tick',       'positive']
                                when :cancel then [:a,      'arrow_undo', nil       ]
                                when :edit   then [:a,      'pencil',     nil       ]
                                when :delete then [:button, 'cross',      'negative']
                                end
        legend = ( (options[:icon] == false || options[:icon] == 'false') ?
                   '' :
                   "<img src='/images/icons/#{icon}.png' alt=''/> " ) +
                 (options[:label] || purpose.to_s.capitalize)

        html_options.merge!(:class => nature)
        if element == :button
          html_options.merge!(:type => 'submit')
        else
          html_options.merge!(:href => (options[:url] || ''))
        end

        # TODO: separate button and link construction and use
        # link_to to gain its functionality, e.g. :back?
        @template.content_tag(element.to_s,
                              legend,
                              html_options)
      end

      protected

      # Tag around content
      def self.content_tag_for( field_helper)
        case field_helper
        when 'text_area': 'div' # in general these contain markup so we need divs
        else
          'span'
        end
      end

      def method_missing(*args, &block)
        if args.first.to_s =~ /^(new|save|cancel|edit|delete)$/
          button args.shift, *args, &block
        else
          super
        end
      end
      
      # Tag around label + content
      def self.container_tag_for( field_helper)
        case field_helper
        when 'text_area': 'div' # content tag will be div so this can't be p
        else
          'p'
        end
      end

      def data_type_for(field_helper)
        case field_helper
        when 'text_field';     'text attribute'
        when 'text_area';      'text attribute'
        when 'password_field'; 'password attribute'
        when 'file_field';     'file attribute'
        when 'hidden_field';   'hidden attribute'
        when 'check_box';      'checkbox attribute'
        when 'radio_button';   'radio attribute'
        when 'select';         'select attribute'
        when 'date_select';    'select date attribute'
        when 'time_select';    'select time attribute'
        when 'country_select'; 'select country attribute'
        else ''
        end
      end

      def attributes_for(method, field_helper)
        {:class => data_type_for(field_helper)} unless data_type_for(field_helper).blank?
      end

      # Writes out a <label/> element for the given field.
      # Options:
      #  - :required: text to indicate that field is required.  Optional: if not given,
      #  field is not required.  If set to true instead of a string, default indicator
      #  text is '(required)'.
      #  - :label: text wrapped by the <label/>.  Optional (default is field's name).
      #  - :suffix: appended to the label.  Optional (default is ':').
      #  - :capitalize: false if any error message should not be capitalised,
      #    true otherwise.  Optional (default is true).
      def label_element(field, options = {}, html_options = {})
        return '' if options.has_key?(:label) && options[:label].nil?
        text = options.delete(:label) || field.to_s.humanize
        suffix = options.delete(:suffix) || label_suffix
        value = text + suffix
        if (required = mandatory?( field, options.delete(:required)))
          required = required_signifier if required == true
          value += " <em class='required'>#{required}</em>"
        end

        html_options.stringify_keys!
        html_options['for'] ||= "#{@object_name}_#{field}"

        if errors_for? field
          error_msg = @object.errors[field].to_a.to_sentence
          option_capitalize = options.delete(:capitalize) || capitalize_errors
          error_msg = error_msg.capitalize unless option_capitalize == 'false' or option_capitalize == false
          value += %Q( <span class="feedback">#{error_msg}.</span>)
        end

        @template.content_tag :label, value, html_options
      end
      
    end # BaseBuilder
    
    # This is the builder used when :no_controls => true
    class DivBuilder < BaseBuilder

      # Per-form configuration (overrides app-wide form configuration).
      # E.g. in a form itself:
      #
      #   - airbudd_form_for @member do |f|
      #     - f.required_signifier = '*'
      #     = f.text_field :name
      #     ...etc...
      #
      attr_writer *default_options.keys
      default_options.keys.each do |field|
        src = <<-END_SRC
          def #{field}
            @#{field} || default_options[:#{field}]
          end
        END_SRC
        class_eval src, __FILE__, __LINE__
      end

      protected

      def self.create_field_helper(field_helper)
        src = <<-END
          def #{field_helper}(method, options, html_options = {})
            opts = options.stringify_keys
            ActionView::Helpers::InstanceTag.new( @object.class.name.downcase, method, self, nil, options[:object]).send( :add_default_name_and_id, opts )
            content = @template.content_tag( #{content_tag_for( field_helper).inspect}, @object.send( method), :id => opts['id'], :class => 'value' )
            @template.content_tag( #{container_tag_for( field_helper).inspect},
                                  label_element(method, options, html_options) +
                                  content,
                                  attributes_for(method, '#{field_helper}') )
          end
        END
        class_eval src, __FILE__, __LINE__
      end

      def self.create_short_field_helper(field_helper)
        src = <<-END
          def #{field_helper}(method, options, html_options = {})
            opts = options.stringify_keys
            ActionView::Helpers::InstanceTag.new( @object.class.name.downcase, method, self, nil, options[:object]).send( :add_default_name_and_id, opts )
            content = @template.content_tag( #{content_tag_for( field_helper).inspect}, @object.send( method), :id => opts['id'], :class => 'value' )
            @template.content_tag( #{container_tag_for( field_helper).inspect},
                                  content +
                                  label_element(method, options, html_options),
                                  attributes_for(method, '#{field_helper}')
            )
          end
        END
        class_eval src, __FILE__, __LINE__
      end

      def self.create_collection_field_helper(field_helper)
        src = <<-END
          def #{field_helper}(method, choices, options, html_options = {})
            opts = options.stringify_keys
            ActionView::Helpers::InstanceTag.new( @object.class.name.downcase, method, self, nil, options[:object]).send( :add_default_name_and_id, opts )
            content = @template.content_tag( #{content_tag_for( field_helper).inspect}, link_to( method, @object.send(method.to_sym) ), :id => opts['id'], :class => 'value' )
            @template.content_tag( #{container_tag_for( field_helper).inspect},
                                  label_element(method, options, html_options) +
                                  content,
                                  attributes_for(method, '#{field_helper}')
            )
          end
        END
        class_eval src, __FILE__, __LINE__
      end

      %w( text_field text_area password_field file_field
          date_select time_select country_select ).each do |name|
        create_field_helper name
      end

      %w( check_box radio_button ).each do |name|
        create_short_field_helper name
      end

      %w( select ).each do |name|
        create_collection_field_helper name
      end

      # Don't ever display mandatory indicator when building :no_controls
      def mandatory?(method, override = nil)
        false
      end
      
      # Ignore errors when building :no_controls
      def errors_for?(method)
        nil
      end
      
    end # DivBuilder
    
    # This is the builder used when the :no_controls option != true
    class FormBuilder < BaseBuilder

      # App-wide form configuration.
      # E.g. in config/initializers/form_builder.rb:
      #
      #   AirBlade::AirBudd::FormBuilder.default_options[:required_signifier] = '*'
      #
      self.default_options = {
        :required_signifier => '(required)',
        :capitalize_errors  => true
      }
      
      # Per-form configuration (overrides app-wide form configuration).
      # E.g. in a form itself:
      #
      #   - airbudd_form_for @member do |f|
      #     - f.required_signifier = '*'
      #     = f.text_field :name
      #     ...etc...
      #
      attr_writer *default_options.keys
      default_options.keys.each do |field|
        src = <<-END_SRC
          def #{field}
            @#{field} || default_options[:#{field}]
          end
        END_SRC
        class_eval src, __FILE__, __LINE__
      end
      
      def read_only_text_field(method_for_text_field, method_for_hidden_field = nil, options = {}, html_options = {})
        method_for_hidden_field ||= method_for_text_field
        @template.content_tag('p',
                              label_element(method_for_text_field, options, html_options) +
                              hidden_field(method_for_hidden_field, options) +
                              @template.content_tag('span', object.send(method_for_text_field)) +
                              addendum_element(options) +
                              hint_element(options),
                              attributes_for(method_for_text_field, 'text_field')
        )
      end

      # Support for GeoTools.
      # http://opensource.airbladesoftware.com/trunk/plugins/geo_tools/
      def latitude_field(method, options = {}, html_options = {})
        @template.content_tag('p',
          label_element(method, options, html_options) + (
              vanilla_text_field("#{method}_degrees",       options.merge(:maxlength => 2)) + '&deg;'   +
              vanilla_text_field("#{method}_minutes",       options.merge(:maxlength => 2)) + '.'       +
              vanilla_text_field("#{method}_milli_minutes", options.merge(:maxlength => 3)) + '&prime;' +
              # Hmm, we pass the options in the html_options position.
              vanilla_select("#{method}_hemisphere", %w( N S ), {}, options)
            ) +
            hint_element(options),
          (errors_for?(method) ? {:class => 'error'} : {})
        )
      end

      # Support for GeoTools.
      # http://opensource.airbladesoftware.com/trunk/plugins/geo_tools/
      def longitude_field(method, options = {}, html_options = {})
        @template.content_tag('p',
          label_element(method, options, html_options) + (
              vanilla_text_field("#{method}_degrees",       options.merge(:maxlength => 3)) + '&deg;'   +
              vanilla_text_field("#{method}_minutes",       options.merge(:maxlength => 2)) + '.'       +
              vanilla_text_field("#{method}_milli_minutes", options.merge(:maxlength => 3)) + '&prime;' +
              # Hmm, we pass the options in the html_options position.
              vanilla_select("#{method}_hemisphere", %w( E W ), {}, options)
            ) +
            hint_element(options),
          (errors_for?(method) ? {:class => 'error'} : {})
        )
      end
      
      protected

      # Creates a glorified form field helper.  It takes a form helper's usual
      # arguments with an optional options hash:
      #
      # <%= form.text_field 'title',
      #                     :required => true,
      #                     :label    => "Article's Title",
      #                     :hint     => "Try not to use the letter 'e'." %>
      #
      # The code above generates the following HTML.  The :required entry in the hash
      # triggers the <em/> element and the :label overwrites the default field label,
      # 'title' in this case, with its value.  The stanza is wrapped in a <p/> element.
      #
      # <p class="text">
      #   <label for="article_title">Article's Title:
      #     <em class="required">(required)</em>
      #   </label>
      #   <input id="article_title" name="article[title]" type="text" value=""/>
      #   <span class="hint">Try not to use the letter 'e'.</span>
      # </p>
      #
      # If the field's value is invalid, the <p/> is marked so and a <span/> is added
      # with the (in)validation message:
      #
      # <p class="error text">
      #   <label for="article_title">Article's Title:
      #     <em class="required">(required)</em>
      #     <span class="feedback">can't be blank</span>
      #   </label>
      #   <input id="article_title" name="article[title]" type="text" value=""/>
      #   <span class="hint">Try not to use the letter 'e'.</span>
      # </p>
      #
      # You can also pass an :addendum option.  This generates a <span/> between the
      # <input/> and the hint.  Typically you would use this to show a small icon
      # for deleting the field.
      def self.create_field_helper(field_helper)
        src = <<-END
          def #{field_helper}(method, options, html_options = {})
            content = @template.content_tag( #{content_tag_for( field_helper).inspect}, super(method, options), :class => 'value')
            @template.content_tag( #{container_tag_for( field_helper).inspect},
                                  label_element(method, options, html_options) +
                                  content +
                                  addendum_element(options) +
                                  hint_element(options),
                                  attributes_for(method, '#{field_helper}') )
          end
        END
        class_eval src, __FILE__, __LINE__
      end

      def self.create_short_field_helper(field_helper)
        src = <<-END
          def #{field_helper}(method, options, html_options = {})
            content = @template.content_tag( #{content_tag_for( field_helper).inspect}, super(method, options), :class => 'value')
            @template.content_tag( #{container_tag_for( field_helper).inspect},
                                  content +
                                  label_element(method, options, html_options) +
                                  hint_element(options),
                                  attributes_for(method, '#{field_helper}')
            )
          end
        END
        class_eval src, __FILE__, __LINE__
      end

      # TODO: DRY this with self.create_field_helper above.
      def self.create_collection_field_helper(field_helper)
        src = <<-END
          def #{field_helper}(method, choices, options, html_options = {})
            content = @template.content_tag( #{content_tag_for( field_helper).inspect}, super(method, choices, options), :class => 'value')
            @template.content_tag( #{container_tag_for( field_helper).inspect},
                                  label_element(method, options, html_options) +
                                  content +
                                  addendum_element(options) +
                                  hint_element(options),
                                  attributes_for(method, '#{field_helper}')
            )
          end
        END
        class_eval src, __FILE__, __LINE__
      end

      # Beefs up the appropriate field helpers.
      %w( text_field text_area password_field file_field
          date_select time_select country_select ).each do |name|
        create_field_helper name
      end

      # Beefs up the appropriate field helpers.
      %w( check_box radio_button ).each do |name|
        create_short_field_helper name
      end

      # Beefs up the appropriate field helpers.
      %w( select ).each do |name|
        create_collection_field_helper name
      end

      def attributes_for(method, field_helper)
        result = super
        result[:class] = ( ((result || {})[:class] || '').split << 'error')*' ' if errors_for?(method)
        result
      end

      def mandatory?(method, override = nil)
        return override unless override.nil?
        # Leverage vendor/validation_reflection.rb
        if @object.class.respond_to? :reflect_on_validations_for
          @object.class.reflect_on_validations_for(method).any? { |val| val.macro == :validates_presence_of } 
        end
      end

      # Writes out a <span/> element with a hint for how to fill in a field.
      # Options:
      #  - :hint: text for the hint.  Optional.
      def hint_element(options = {})
        hint = options.delete :hint
        if hint
          @template.content_tag :span, hint, :class => 'hint'
        else
          ''
        end
      end

      # Writes out a <span/> element with something that follows a field.
      # Options:
      #  - :hint: text for the hint.  Optional.
      def addendum_element(options = {})
        addendum = options.delete :addendum
        if addendum
          @template.content_tag :span, addendum, :class => 'addendum'
        else
          ''
        end
      end

      def errors_for?(method)
        @object && @object.errors[method]
      end

      alias_method :vanilla_text_field,   :text_field
      alias_method :vanilla_select,       :select

    end
  end
end
