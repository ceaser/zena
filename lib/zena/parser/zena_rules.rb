module Zena
  module Parser
    module ZenaRules
      # FIXME: remove all this when rubyless is in place !
      def start(mode)
        super
        if @method =~ /^\[(.*)\]$/
          # do='[text]
          @method = 'show'
          @params[:attr_or_date] = $1
        elsif @method =~ /^\{(.*)\}$/
          # do='{text}'
          @method = 'zazen'
          @params[:attr] = $1
        elsif @method =~ /\A(\w+)\s+(\w+)\s+(.+)$/
          # 'pages where title ...'
          @params[:select] = @method
          @method = 'context'
        end
      end
    end # ZenaRules
  end # Parser
end # Zena