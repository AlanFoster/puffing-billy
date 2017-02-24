require 'forwardable'

module Billy
  class RequestHandler
    extend Forwardable
    include Handler

    def_delegators :stub_handler, :stub

    def handlers
      @handlers ||= { stubs: StubHandler.new,
                      cache: CacheHandler.new,
                      proxy: ProxyHandler.new }
    end

    def handle_request(method, url, headers, body)
      Billy.log(:info, "puffing-billy: REQUEST #{method} for '#{url}'")

      # Process the handlers by order of importance
      [:stubs, :cache, :proxy].each do |key|
        if (response = handlers[key].handle_request(method, url, headers, body))
          Billy.log(:info, "puffing-billy: #{key} successfully handled #{method} for '#{url}'")
          return response
        end
        Billy.log(:info, "puffing-billy: #{key} did not handle #{method} for '#{url}'")
      end

      body_msg = Billy.config.cache_request_body_methods.include?(method) ? " with body '#{body}'" : ''
      Billy.log(:info, "puffing-billy: NOT HANDLED #{method} for '#{url}'")
      { error: "Connection to #{url}#{body_msg} not cached and new http connections are disabled" }
    end

    def handles_request?(method, url, headers, body)
      [:stubs, :cache, :proxy].each do |key|
        if handlers[key].handles_request?(method, url, headers, body)
          Billy.log(:info, "puffing-billy: #{key} HANDLES #{method} for '#{url}'")
          return true
        end
      end

      false
    end

    def reset
      handlers.each_value(&:reset)
    end

    def reset_stubs
      handlers[:stubs].reset
    end

    def reset_cache
      handlers[:cache].reset
    end

    def restore_cache
      warn '[DEPRECATION] `restore_cache` is deprecated as cache files are dynamically checked. Use `reset_cache` if you just want to clear the cache.'
      reset_cache
    end

    private

    def stub_handler
      handlers[:stubs]
    end
  end
end
