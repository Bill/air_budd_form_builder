module AirBlade
  module AirBudd
    module FormHelper

      def airbudd_form_for(record_or_name_or_array, *args, &proc)
        x_form_for( false, record_or_name_or_array, *args, &proc )
      end

      def airbudd_remote_form_for(record_or_name_or_array, *args, &proc)
        x_form_for( true, record_or_name_or_array, *args, &proc )
      end

      def airbudd_fields_for(record_or_name_or_array, *args, &proc)
        # Well we don't do very well unles we use Procs instead of blocks, hence the Proc and lambda
        with_fields_for_options( lambda { | controls, scaffold, record_or_name_or_array, args, original_callers_proc |
            # careful! don't call super with our original arguments (call w/ modified ones)
            fields_for record_or_name_or_array, *args, &original_callers_proc.binding
        }, record_or_name_or_array, args, Proc.new( &proc ) )
      end

      # Displays a link visually consistent with AirBudd form links.
      # TODO: complete this.  See README.
      # TODO: DRY with FormBuilder#button implementation.
      def link_to_form(purpose, options = {}, html_options = nil)
        icon = case purpose
               when :new    then 'add'
               when :edit   then 'pencil'
               when :delete then 'cross'  # TODO: delete should be a button, not a link
               when :cancel then 'arrow_undo'
               end
        if options.kind_of? String
          url = options
        else
          url = options.delete :url
          label = options.delete :label
        end
        label ||= purpose.to_s.capitalize
        legend = ( icon.nil? ?
                   '' :
                   "<img src='/images/icons/#{icon}.png' alt=''></img> " ) + label
        
        '<div class="buttons">' +
        link_to(legend, (url || options), html_options) +
        '</div>'
      end
      
      protected
      
      def x_form_for( is_remote, record_or_name_or_array, *args, &proc)
        # can't call a method w/ two blocks--one's gotta be a Proc
        with_fields_for_options( lambda{ | controls, scaffold, record_or_name_or_array, args, original_callers_proc |
          wrapper( controls, scaffold, is_remote, record_or_name_or_array, *args, &original_callers_proc.binding)
        }, record_or_name_or_array, args, Proc.new( &proc ) )
      end
      
      # Options processing for form_for, fields_for etc. is complicated. This method
      # isolates those complications. NB we take a two proc parameters. direct_callers_proc
      # is from the direct caller and original_callers_proc is from the original caller
      def with_fields_for_options( direct_callers_proc, record_or_name_or_array, args, original_callers_proc)
        options = args.detect { |argument| argument.is_a?(Hash) }
        if options.nil? # if caller didn't send options, append our own Hash
          options = {}
          args << options
        end
        options.reverse_merge! :controls => true, :scaffold => true # defaults
        controls = options.delete(:controls)
        scaffold = options.delete(:scaffold)
        builder = ( controls ? AirBlade::AirBudd::FormBuilder : AirBlade::AirBudd::DivBuilder)
        builder = ( returning( Class.new( builder ) ) { |c| 
          c.wrapper_class = AirBlade::AirBudd::EmptyWrapper } ) unless scaffold
        options[:builder] = builder
        direct_callers_proc.call controls, scaffold, record_or_name_or_array, args, original_callers_proc
      end
      
      # Guts copied from Rails 2.1.0 form_for. 
      # The purpose of this method is to let us wrap the content in a div and
      # to also make form tag optional
      def wrapper( controls, scaffold, is_remote, record_or_name_or_array, *args, &proc)
        raise ArgumentError, "Missing block" unless block_given?

        options = args.extract_options!

        case record_or_name_or_array
        when String, Symbol
          object_name = record_or_name_or_array
        when Array
          object = record_or_name_or_array.last
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          apply_form_for_options!(record_or_name_or_array, options)
          args.unshift object
        else
          object = record_or_name_or_array
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          apply_form_for_options!([object], options)
          args.unshift object
        end

        wrapper_start( controls, scaffold, is_remote, options, object_name, &proc)
        fields_for(object_name, *(args << options), &proc)
        wrapper_end( controls, scaffold, &proc)
      end

      def wrapper_start( controls, scaffold, is_remote, options, object_name, &proc)
        concat("<div class='#{object_name}#{controls ? ' draft' : ' published' }'>", proc.binding) if scaffold
        url, html = options.delete(:url), options.delete(:html)
        if controls
          if is_remote
            concat( form_remote_tag(options), proc.binding) # see Rails prototype_helper.rb
          else
            concat( form_tag(url || {}, html || {}), proc.binding) # see Rails form_helper.rb
          end
        end
      end

      def wrapper_end( controls, scaffold, &proc)
        concat('</form>', proc.binding) if controls
        concat('</div>', proc.binding) if scaffold
      end
    end
  end
end
