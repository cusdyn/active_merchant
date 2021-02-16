require 'test_helper'

class ConnexpayTest < Test::Unit::TestCase
  def setup
    @gateway = ConnexpayGateway.new(username: 'mtimmonsmerch', password: 'Connexpay2019')
    @credit_card = credit_card('5200000000000080',{verification_value: '998'})
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Transaction - Approved', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    )
  end

  def post_scrubbed
    %q(
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    )
  end

  def successful_purchase_response
    %(
    {
      "guid": "",
      "status": "Transaction - Approved",
      "type": "Default",
      "batchStatus": "Batch - Open",
      "timeStamp": "",
      "deviceGuid": "0b7a9536-9fcd-4074-a841-d47eef77b81b",
      "amount": 10.00,
      "activated": true,
      "tenderType": "Credit",
      "effectiveAmount": 10.00,
      "cardDataSource": "INTERNET",
      "batchGuid": "",
      "processorStatusCode": "A0000",
      "processorResponseMessage": "Success",
      "wasProcessed": true,
      "authCode": "",
      "refNumber": "",
      "customerReceipt": "",
      "generatedBy": "mtimmonsmerch",
      "card": {
        "first6": "520000",
        "first4": "5200",
        "last4": "0080",
        "cardHolderName": "Mike Timmons",
        "cardType": "Mastercard",
        "expirationDate": "2022-12",
        "guid": ""
      },
      "addressVerificationCode": "0",
      "addressVerificationResult": "Unavailable",
      "cvvVerificationResult": "Unavailable",
      "walletProvider": 0
    }
    )
  end

  def failed_purchase_response
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
