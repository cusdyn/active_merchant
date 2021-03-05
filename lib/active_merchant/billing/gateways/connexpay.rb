module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ConnexpayGateway < Gateway

      SUCCESS = 'Transaction - Approved'

      self.test_url = 'https://salesapi.connexpaydev.com/api/v1'
      self.live_url = 'https://salesapi.connexpay.com/api/v1'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.connexpay.com/'
      self.display_name = 'ConnexPay'

      # AM accepts/expects cents on the public method calls. For example $1.01 as 101.
      # Connexpay expects $1.01 so this sets the proper money format
      self.money_format = :dollars

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


      # Purchase and Authorize are same
      def purchase(money, payment, options={})
        post = create_post_for_auth_or_purchase(money, payment, options)
        commitAuthCapture(:post, 'BasicSale', post)
      end

      def authorize(money, payment, options={})
        post = create_post_for_auth_or_purchase(money, payment, options)
        commitAuthCapture(:post, 'BasicSale', post)
      end

      def create_post_for_auth_or_purchase(money, creditcard, options)
        post = {}
        post[:amount] = amount(money)

        #ConnexPay Expected Payments=0 is required for aquiring-only
        post[:ConnexPayTransaction] = { ExpectedPayments: 0 }
        add_orderinfo(post,options)
        add_creditcard(post,creditcard)
        add_risk_data(post, options)
        post
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

      # map AM standard options to ConnexPay's order specificity info
      def add_orderinfo(post,options)
        # map AM field to ConnexPay order identifier fields
        post[:OrderNumber]    = options[:invoice]
        post[:SequenceNumber] = options[:OrderId]
        post[:CustomerId]    = options[:description]
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
          ProductItem: options[:invoice]
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
                     authorization: authorization_string(response['guid'],response['orderNumber']))
      end

      def commitAuthCapture(action, resource, parameters)
        response = http_request(action, resource, parameters)
        success = !error?(response)

        rsp = mapToOrbitalResponse(response)
        successful = success?(response, resource)

         Response.new(true,response_message(response['status']),rsp,
                     {
                       authorization: authorization_string(response['guid'],response['orderNumber']),
                       cvv_result:   CVVResult.new(response['cvvVerificationCode']),
                       avs_result:   AVSResult.new({:code=> response['addressVerificationCode']}),
                       fraud_review: fraud_response(response['riskResponse']),
                       test: self.test?
                     })
      end

      def response_message(status)
        strArray = status.split()
        rsp = strArray[-1]
        rsp
      end

      def fraud_response(rsp)
        rtn = rsp
        rtn[:provider] = "Kount"
        rtn
      end

      def mapToOrbitalResponse(rin)
        card = rin['card']
        params = {}
        rout = {}
        #       params[:industry_type] = 'EC'
        #params[:message_type]  = 'AC'
        #params[:merchant_id] = rin['deviceGuid']
        #params[:card_brand] = card['cardType']
        #params[:status_msg] = rin['status']

        #rout[:authorization] = rin[:status]
        #rout[:params] = params
        rout
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

      def authorization_string(*args)
        args.compact.join(';')
      end

      def success?(response, message_type)
        if message_type.include?"BasicSale"
          response[:status].to_s.include?SUCCESS
        else
          false
        end
      end
    end

  end
end

