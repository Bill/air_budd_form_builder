module AirBlade
  module AirBudd
    module FormHelper

      def airbudd_form_for(record_or_name_or_array, *args, &proc)
        options = args.detect { |argument| argument.is_a?(Hash) }
        no_controls = options.delete(:no_controls)
        builder = ( no_controls ? AirBlade::AirBudd::DivBuilder : AirBlade::AirBudd::FormBuilder )
        if options.nil?
          options = {:builder => builder}
          args << options
        end
        options[:builder] = builder unless options.nil?
        wrapper( no_controls, false, record_or_name_or_array, *args, &proc)
      end

      def airbudd_remote_form_for(record_or_name_or_array, *args, &proc)
        options = args.detect { |argument| argument.is_a?(Hash) }
        no_controls = options.delete(:no_controls)
        builder = ( no_controls ? AirBlade::AirBudd::DivBuilder : AirBlade::AirBudd::FormBuilder )
        if options.nil?
          options = {:builder => builder}
          args << options
        end
        options[:builder] = builder unless options.nil?
        wrapper( no_controls, true, record_or_name_or_array, *args, &proc)
      end

      def airbudd_fields_for(record_or_name_or_array, *args, &proc)
        options = args.detect { |argument| argument.is_a?(Hash) }
        builder = ( options.delete(:no_controls) ? 
          AirBlade::AirBudd::DivBuilder : AirBlade::AirBudd::FormBuilder )
        if options.nil?
          options = {:builder => builder}
          args << options
        end
        options[:builder] = builder unless options.nil?
        # notice: plain old Rails fields_for works fine here since we spec'd the builder and fields_for
        # doesn't spit out table tags (like form_for does)
        super
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
      
      # Guts copied from Rails 2.1.0 form_for. 
      # The purpose of this method is to let us wrap the content in a div and
      # to also make form tag optional
      def wrapper( no_controls, remote, record_or_name_or_array, *args, &proc)
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

        wrapper_start( no_controls, remote, options, object_name, &proc)
        fields_for(object_name, *(args << options), &proc)
        wrapper_end( no_controls, &proc)
      end

      def wrapper_start( no_controls, remote, options, object_name, &proc)
        concat("<div class='#{object_name}'>", proc.binding)
        url, html = options.delete(:url), options.delete(:html)
        unless no_controls
          if remote
            concat( form_remote_tag(options), proc.binding) # see Rails prototype_helper.rb
          else
            concat( form_tag(url || {}, html || {}), proc.binding) # see Rails form_helper.rb
          end
        end
      end

      def wrapper_end( no_controls, &proc)
        concat('</form>', proc.binding) unless no_controls
        concat('</div>', proc.binding)
      end
    end
  end
end
