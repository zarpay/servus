# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'a standard http error' do |error_class:, default_message:, http_status:|
  describe error_class do
    let(:error) { error_class.new }
    let(:custom_message) { 'Custom error message' }
    let(:custom_error) { error_class.new(custom_message) }

    it 'inherits from ServiceError' do
      expect(error_class).to be < Servus::Support::Errors::ServiceError
    end

    it 'has a default message' do
      expect(error_class::DEFAULT_MESSAGE).to eq(default_message)
    end

    it 'uses default message when none provided' do
      expect(error.message).to eq(default_message)
    end

    it 'accepts a custom message' do
      expect(custom_error.message).to eq(custom_message)
    end

    it "returns :#{http_status} for http_status" do
      expect(error.http_status).to eq(http_status)
    end

    it 'returns api_error hash with code and default message' do
      expect(error.api_error).to eq({ code: http_status, message: default_message })
    end

    it 'returns api_error hash with code and custom message' do
      expect(custom_error.api_error).to eq({ code: http_status, message: custom_message })
    end
  end
end

RSpec.describe Servus::Support::Errors do
  describe Servus::Support::Errors::ServiceError do
    let(:error) { described_class.new('error message') }

    it 'inherits from StandardError' do
      expect(described_class).to be < StandardError
    end

    it 'has a default message' do
      expect(described_class::DEFAULT_MESSAGE).to eq('An error occurred')
    end

    it 'has a message attribute' do
      expect(error.message).to eq('error message')
    end

    describe '#api_error' do
      it 'returns a default api error' do
        expect(described_class.new.api_error).to eq({ code: :bad_request, message: described_class::DEFAULT_MESSAGE })
      end

      it 'returns a custom api error' do
        expect(error.api_error).to eq({ code: :bad_request, message: 'error message' })
      end
    end
  end

  # 4xx Client Errors
  include_examples 'a standard http error', error_class: Servus::Support::Errors::MethodNotAllowedError,
                                            default_message: 'Method not allowed',
                                            http_status: :method_not_allowed

  include_examples 'a standard http error', error_class: Servus::Support::Errors::NotAcceptableError,
                                            default_message: 'Not acceptable',
                                            http_status: :not_acceptable

  include_examples 'a standard http error', error_class: Servus::Support::Errors::ProxyAuthenticationRequiredError,
                                            default_message: 'Proxy authentication required',
                                            http_status: :proxy_authentication_required

  include_examples 'a standard http error', error_class: Servus::Support::Errors::RequestTimeoutError,
                                            default_message: 'Request timeout',
                                            http_status: :request_timeout

  include_examples 'a standard http error', error_class: Servus::Support::Errors::ConflictError,
                                            default_message: 'Conflict',
                                            http_status: :conflict

  include_examples 'a standard http error', error_class: Servus::Support::Errors::GoneError,
                                            default_message: 'Gone',
                                            http_status: :gone

  include_examples 'a standard http error', error_class: Servus::Support::Errors::LengthRequiredError,
                                            default_message: 'Length required',
                                            http_status: :length_required

  include_examples 'a standard http error', error_class: Servus::Support::Errors::PreconditionFailedError,
                                            default_message: 'Precondition failed',
                                            http_status: :precondition_failed

  include_examples 'a standard http error', error_class: Servus::Support::Errors::PayloadTooLargeError,
                                            default_message: 'Payload too large',
                                            http_status: :payload_too_large

  include_examples 'a standard http error', error_class: Servus::Support::Errors::UriTooLongError,
                                            default_message: 'URI too long',
                                            http_status: :uri_too_long

  include_examples 'a standard http error', error_class: Servus::Support::Errors::UnsupportedMediaTypeError,
                                            default_message: 'Unsupported media type',
                                            http_status: :unsupported_media_type

  include_examples 'a standard http error', error_class: Servus::Support::Errors::RangeNotSatisfiableError,
                                            default_message: 'Range not satisfiable',
                                            http_status: :range_not_satisfiable

  include_examples 'a standard http error', error_class: Servus::Support::Errors::ExpectationFailedError,
                                            default_message: 'Expectation failed',
                                            http_status: :expectation_failed

  include_examples 'a standard http error', error_class: Servus::Support::Errors::ImATeapotError,
                                            default_message: "I'm a teapot",
                                            http_status: :im_a_teapot

  include_examples 'a standard http error', error_class: Servus::Support::Errors::MisdirectedRequestError,
                                            default_message: 'Misdirected request',
                                            http_status: :misdirected_request

  include_examples 'a standard http error', error_class: Servus::Support::Errors::UnprocessableContentError,
                                            default_message: 'Unprocessable content',
                                            http_status: :unprocessable_content

  include_examples 'a standard http error', error_class: Servus::Support::Errors::LockedError,
                                            default_message: 'Locked',
                                            http_status: :locked

  include_examples 'a standard http error', error_class: Servus::Support::Errors::FailedDependencyError,
                                            default_message: 'Failed dependency',
                                            http_status: :failed_dependency

  include_examples 'a standard http error', error_class: Servus::Support::Errors::TooEarlyError,
                                            default_message: 'Too early',
                                            http_status: :too_early

  include_examples 'a standard http error', error_class: Servus::Support::Errors::UpgradeRequiredError,
                                            default_message: 'Upgrade required',
                                            http_status: :upgrade_required

  include_examples 'a standard http error', error_class: Servus::Support::Errors::PreconditionRequiredError,
                                            default_message: 'Precondition required',
                                            http_status: :precondition_required

  include_examples 'a standard http error', error_class: Servus::Support::Errors::TooManyRequestsError,
                                            default_message: 'Too many requests',
                                            http_status: :too_many_requests

  include_examples 'a standard http error', error_class: Servus::Support::Errors::RequestHeaderFieldsTooLargeError,
                                            default_message: 'Request header fields too large',
                                            http_status: :request_header_fields_too_large

  include_examples 'a standard http error', error_class: Servus::Support::Errors::UnavailableForLegalReasonsError,
                                            default_message: 'Unavailable for legal reasons',
                                            http_status: :unavailable_for_legal_reasons

  # 5xx Server Errors
  include_examples 'a standard http error', error_class: Servus::Support::Errors::NotImplementedError,
                                            default_message: 'Not implemented',
                                            http_status: :not_implemented

  include_examples 'a standard http error', error_class: Servus::Support::Errors::BadGatewayError,
                                            default_message: 'Bad gateway',
                                            http_status: :bad_gateway

  include_examples 'a standard http error', error_class: Servus::Support::Errors::GatewayTimeoutError,
                                            default_message: 'Gateway timeout',
                                            http_status: :gateway_timeout

  include_examples 'a standard http error', error_class: Servus::Support::Errors::HttpVersionNotSupportedError,
                                            default_message: 'HTTP version not supported',
                                            http_status: :http_version_not_supported

  include_examples 'a standard http error', error_class: Servus::Support::Errors::VariantAlsoNegotiatesError,
                                            default_message: 'Variant also negotiates',
                                            http_status: :variant_also_negotiates

  include_examples 'a standard http error', error_class: Servus::Support::Errors::InsufficientStorageError,
                                            default_message: 'Insufficient storage',
                                            http_status: :insufficient_storage

  include_examples 'a standard http error', error_class: Servus::Support::Errors::LoopDetectedError,
                                            default_message: 'Loop detected',
                                            http_status: :loop_detected

  include_examples 'a standard http error', error_class: Servus::Support::Errors::NotExtendedError,
                                            default_message: 'Not extended',
                                            http_status: :not_extended

  include_examples 'a standard http error', error_class: Servus::Support::Errors::NetworkAuthenticationRequiredError,
                                            default_message: 'Network authentication required',
                                            http_status: :network_authentication_required
end
