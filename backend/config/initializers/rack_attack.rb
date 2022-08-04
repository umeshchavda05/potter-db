class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new # defaults to Rails.cache

  safelist('allow from potter db root domain', &:db_domain?)

  throttle("requests by ip", limit: 5, period: 1.minute) do |request|
    request.ip if request.path.include?('/v1')
  end

  Rack::Attack.throttled_responder = lambda do |request|
    now = Time.zone.now
    match_data = request.env['rack.attack.match_data']
    headers = {
      'RateLimit-Limit' => "#{match_data[:limit]} requests / #{match_data[:period]} seconds",
      'RateLimit-Remaining' => '0',
      'RateLimit-Reset' => (now + (match_data[:period] - (now.to_i % match_data[:period]))).iso8601
    }

    status = 429

    [status, headers, [
      {
        errors: [
          status: status,
          title: "To many requests!",
          detail: "API rate limit exceeded for #{request.env['rack.attack.match_discriminator']}."
        ]
      }.to_json
    ]]
  end

  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _request_id, payload|
    rack_logger ||= ActiveSupport::TaggedLogging.new(Logger.new($stdout))
    rack_logger.info(
      [
        "[#{payload[:request].env['rack.attack.match_type']}]",
        "[#{payload[:request].env['rack.attack.matched']}]",
        "[#{payload[:request].env['rack.attack.match_discriminator']}]",
        "[#{payload[:request].env['rack.attack.throttle_data']}]"
      ].join(' ')
    )
  end
end

class Rack::Attack::Request < ::Rack::Request
  def localhost?
    ip == "127.0.0.1"
  end

  def db_domain?
    puts url, host_with_port, host, base_url, domain
    if Rails.env.development?
      localhost?
    else
      base_url == domain
    end
  end
end
