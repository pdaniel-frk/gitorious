module ActionView
  module TemplateHandlers
    class ERB < TemplateHandler
      include Compilable

      ##
      # :singleton-method:
      # Specify trim mode for the ERB compiler. Defaults to '-'.
      # See ERb documentation for suitable values.
      cattr_accessor :erb_trim_mode
      self.erb_trim_mode = '-'

      def compile(template)
        ::ERB.new("<% __in_erb_template=true %>#{template.source}", nil, erb_trim_mode, '@output_buffer').src
      end
    end
  end
end
