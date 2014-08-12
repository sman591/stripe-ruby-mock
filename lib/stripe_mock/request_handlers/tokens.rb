module StripeMock
  module RequestHandlers
    module Tokens

      def Tokens.included(klass)
        klass.add_handler 'post /v1/tokens',      :create_token
        klass.add_handler 'get /v1/tokens/(.*)',  :get_token
      end

      def create_token(route, method_url, params, headers)
        if params[:customer].nil? && params[:card].nil?
          raise Stripe::InvalidRequestError.new('You must supply either a card, customer, or bank account to create a token.', nil, 400)
        end

        if params[:card]
          # "Sanitize" card number
          params[:card][:fingerprint] = StripeMock::Util.fingerprint(params[:card][:number])
          params[:card][:last4] = params[:card][:number][-4,4]
          customer_card = params[:card]
        else
          customer = customers[params[:customer]]
          assert_existance :customer, params[:customer], customer
          customer_card = get_customer_card(customer, customer[:default_card])
        end

        token_id = generate_card_token(customer_card)
        card = @card_tokens[token_id]

        Data.mock_token(params.merge :id => token_id, :card => card)
      end

      def get_token(route, method_url, params, headers)
        route =~ method_url
        # A Stripe token can be either a bank token or a card token
        bank_or_card = @bank_tokens[$1] || @card_tokens[$1]
        assert_existance :token, $1, bank_or_card

        if bank_or_card[:object] == 'card'
          Data.mock_token(:id => $1, :card => bank_or_card)
        elsif bank_or_card[:object] == 'bank_account'
          Data.mock_token(:id => $1, :bank_account => bank_or_card)
        end
      end
    end
  end
end