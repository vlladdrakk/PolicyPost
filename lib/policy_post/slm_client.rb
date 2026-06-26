require "net/http"
require "json"

module PolicyPost
  class SlmUnavailableError < StandardError; end
end

module PolicyPost::SlmClient
  module_function

  def default_client
    @default_client ||= SlmClient.new(
      base_url: ENV.fetch("SLM_BASE_URL", "http://localhost:8080/v1"),
      model: ENV.fetch("SLM_MODEL", "LFM2.5-1.2B-Instruct-BF16.gguf"),
      api_key: ENV.fetch("SLM_API_KEY", "dummy"),
      timeout: ENV.fetch("SLM_TIMEOUT", 120).to_i
    )
  end

  def default_client=(client)
    @default_client = client
  end

  def complete(prompt, system: nil, temperature: 0.7, client: nil)
    (client || default_client).complete(prompt, system: system, temperature: temperature)
  end

  class SlmClient
    def initialize(base_url:, model:, api_key:, timeout: 120)
      @base_url = base_url
      @model = model
      @api_key = api_key
      @timeout = timeout
    end

    def complete(prompt, system: nil, temperature: 0.7)
      uri = URI("#{@base_url}/chat/completions")
      messages = []
      messages << { role: "system", content: system } if system
      messages << { role: "user", content: prompt }

      body = {
        model: @model,
        messages: messages,
        temperature: temperature
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}"
      request.body = body.to_json

      response = http.request(request)
      result = JSON.parse(response.body)
      result.dig("choices", 0, "message", "content")&.strip
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
           Errno::EHOSTDOWN, Errno::ETIMEDOUT, SocketError,
           Net::OpenTimeout, Net::ReadTimeout, EOFError => e
      raise PolicyPost::SlmUnavailableError, "#{@base_url}: #{e.class}: #{e.message}"
    end
  end

  class FakeSlmClient
    def initialize(responses = [])
      @responses = responses.dup
      @call_count = 0
    end

    def complete(_prompt, system: nil, temperature: 0.7)
      raise "FakeSlmClient exhausted: no more canned responses" if @call_count >= @responses.length
      result = @responses[@call_count]
      @call_count += 1
      result
    end
  end
end
