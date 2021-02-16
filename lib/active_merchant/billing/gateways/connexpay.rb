module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ConnexpayGateway < Gateway
      self.test_url = 'https://salesapi.connexpaydev.com/api/v1'
      self.live_url = 'https://salesapi.connexpay.com/api/v1'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.connexpay.com/'
      self.display_name = 'ConnexPay'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :username, :password)
        @username = options[:username]
        @password = options[:password]
        super
      end

      def headers(options = {})
        {
          'Content-Type' => 'application/json',
          'Authorization' => 'Basic ' + Base64.strict_encode64(@username.to_s + ':' + @password.to_s).strip,
        }
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_customer_data(post, options)

        post = create_post_for_auth_or_purchase(money, payment, options)
        commit(:post, 'BasicSale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit( :post, 'BasicAuth', post)
      end

      def create_post_for_auth_or_purchase(money, creditcard, options)
        post = {}
        post[:amount] = amount(money)
        post[:ConnexPayTransaction] = { ExpectedPayments: 0 }
        add_creditcard(post,creditcard)
        add_risk_data(post, options)
        post
      end

      def add_creditcard(post, creditcard)
        # Map creditcard object to ConnexPay Card object
          card = {
            CardNumber: creditcard.number,
            ExpirationDate: sprintf('%02d%02d', creditcard.year.to_s[-2, 2],creditcard.month),
            cvv2: creditcard.verification_value
          }
          post[:card] = card
      end


      def capture(money, authorization, options={})
        commit(:post, 'BasicCapture', post)
      end

      def refund(money, authorization, options={})
        commit(:post, 'BasicReturn', post)
      end

      def void(authorization, options={})
        commit( :post,'BasicVoid', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options)
      end

      def add_risk_data(post,  options)
        address = options[:billing_address] || {}

        risk = {
          Name: address[:name],
          BillingPhoneNumber: address[:phone],
          BillingAddress1: address[:address1],
          BillingAddress2: address[:address2],
          BillingCity: address[:city],
          BillingState: address[:state],
          BillingPostalCode: address[:zip],
          BillingCountryCode: address[:country],
          ProductDescription: options[:description],
          OrderNumber: options[:order_id],
          ProductType: options[:description],
          ProductPrice: post[:amount].to_f*100,
          ProductItem: options[:order_id]
        }

        post[:RiskData] = risk
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end


      def parse(body)
        return {} unless body

        JSON.parse(body)
      end

      def commit(action, resource, parameters)
        response = http_request(action, resource, parameters)
        success = !error?(response)

        Response.new(success,
                     (success ? response['status'] : response['status']),
                     response,
                     test: test?,
                     authorization: response['status'])
      end

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end

      def http_request(method, resource, parameters = {}, options = {})
        url = (test? ? self.test_url : self.live_url) + '/' + resource
        raw_response = nil
        begin
          raw_response = ssl_request(method, url, (parameters ? parameters.to_json : nil), headers(options))
          parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response_error(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def error?(response)
        response['error_code'] && !response['error_code'].blank?
      end

    end
  end
end
