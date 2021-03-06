require 'hawkular/inventory/inventory_api'
require 'hawkular/alerts/alerts_api'
require 'hawkular/tokens/tokens_api'
require 'hawkular/operations/operations_api'
require 'hawkular/prometheus/prometheus_api'
require 'hawkular/base_client'

module Hawkular
  class Client
    def initialize(hash)
      hash[:credentials] ||= {}
      hash[:options] ||= {}

      fail Hawkular::ArgumentError, 'no parameter ":entrypoint" given' if hash[:entrypoint].nil?

      @state = hash
    end

    def respond_to_missing?(method_name, include_private = false)
      delegate_client = client_for_method(method_name)
      return super if delegate_client.nil?

      method = submethod_name_for(method_name)
      return super unless delegate_client.respond_to?(method)

      true
    end

    def method_missing(name, *args, &block)
      super unless respond_to?(name)
      client_for_method(name).__send__(submethod_name_for(name), *args, &block)
    end

    def inventory
      @inventory ||= Inventory::Client.new("#{@state[:entrypoint]}/hawkular/inventory",
                                           @state[:credentials],
                                           @state[:options])
    end

    def alerts
      @alerts ||= Alerts::Client.new("#{@state[:entrypoint]}/hawkular/alerts",
                                     @state[:credentials],
                                     @state[:options])
    end

    # adds a way to explicitly open the new web socket connection (the default is to recycle it)
    # @param open_new [Boolean] if true, opens the new websocket connection
    def operations(open_new = false)
      @operations = init_operations_client if open_new
      @operations ||= init_operations_client
    end

    def tokens
      @tokens ||= Token::Client.new(@state[:entrypoint],
                                    @state[:credentials],
                                    @state[:options])
    end

    def prometheus
      @prometheus ||= Prometheus::Client.new(@state[:entrypoint],
                                             @state[:credentials],
                                             @state[:options])
    end

    private

    # this is in a dedicated method, because constructor opens the websocket connection to make the handshake
    def init_operations_client
      Operations::Client.new(entrypoint: @state[:entrypoint],
                             credentials: @state[:credentials],
                             options: @state[:options])
    end

    def client_for_method(method_name)
      case method_name
      when /^inventory_/ then inventory
      when /^alerts_/ then alerts
      when /^operations_/ then operations
      when /^tokens_/ then tokens
      when /^prometheus_/ then prometheus
      end
    end

    def submethod_name_for(method_name)
      method_name.to_s.sub(/^[^_]+_/, '')
    end
  end
end
