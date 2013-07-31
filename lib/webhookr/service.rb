module Webhookr
  class Service
    attr_reader :service_name

    def initialize(service_name, options = {})
      @service_name = (service_name || "").downcase
      @raw_payload = options[:payload]
      @request = options[:request]
      available?
      authenticated?
      validate_security_token(options[:security_token]) if configured_security_token
    end

    def process!
      Array.wrap(service_adapter.send(:process, @raw_payload)).each do |payload|
        callback(callback_class, payload)
      end
    end

    private

    def callback(object, payload)
      method = method_for(payload)
      object.send(method, payload) if object.respond_to?(method)
    end

    def method_for(payload)
      "on_" + payload.event_type
    end

    def callback_class
      callback = Webhookr.config[service_name].try(:callback)
      raise "No callback is configured for the service '#{service_name}'." if callback.nil?
      @call_back_class || callback.new
    end

    def configured_security_token
      Webhookr.config[service_name].try(:security_token)
    end

    def validate_security_token(token)
      raise Webhookr::InvalidSecurityTokenError if token.nil? || token != configured_security_token
    end

    def service_adapter
      raise NameError.new(%{Bad service name "#{service_name}"}) unless Webhookr.adapters[service_name]
      @service_adapter ||= Webhookr.adapters[service_name]
    end

    alias_method :available?, :service_adapter

    def authenticated?
      raise Webhookr::NotAuthenticatedError unless service_adapter.authenticated?(@request)
    end
  end
end
