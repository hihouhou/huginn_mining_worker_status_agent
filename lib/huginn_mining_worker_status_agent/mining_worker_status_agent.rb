module Agents
  class MiningWorkerStatusAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The mining worker status agent fetches worker status (Offline/Online/etc) and creates an event when it changes.

      `pool_url` needed for mining pool website (like https://clopool.pro )

      `debug` is used to verbose mode.

      `check_hashrate` is used to create event if global/workker hashrate is null.

      `wallet_address` needed for the wanted address

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "workersOnline": 3
          }
    MD

    def default_options
      {
        'wallet_address' => '',
        'pool_url' => '',
        'debug' => 'false',
        'check_hashrate' => 'false',
        'expected_receive_period_in_days' => '2'
      }
    end

    form_configurable :pool_url, type: :string
    form_configurable :wallet_address, type: :string
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :check_hashrate, type: :boolean

    def validate_options
      unless options['wallet_address'].present?
        errors.add(:base, "wallet_address is a required field")
      end

      unless options['pool_url'].present?
        errors.add(:base, "pool_url is a required field")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def fetch
      domain = URI.parse(interpolated[:pool_url]).host.split(".")[-2,2].join(".")
      case domain
      when "nanopool.org"
        url_path = '/api/v1/user/'
      else
        log "invalid domain!"
      end
      uri = URI.parse(interpolated[:pool_url] + url_path + interpolated[:wallet_address])
      request = Net::HTTP::Get.new(uri)
    
      req_options = {
        use_ssl: uri.scheme == "https",
      }
    
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log "request  status : #{response.code}"

      if interpolated['debug'] == 'true'
        log "response.body"
        log response.body
      end

      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log " global hashrate = #{payload['data']['hashrate']}"
      end

      if interpolated['check_hashrate'] == 'true'
        if payload['data']['hashrate'] == '0.0'
          create_event :payload => { 'poll' => interpolated[:pool_url], 'wallet' => interpolated[:wallet_address], 'status' => "hashrate is 0", 'hashrate' => payload['data']['hashrate'] }
        end
        payload["data"]["workers"].each do |worker|
          if interpolated['debug'] == 'true'
            log "#{worker['id']} hashrate = #{worker['hashrate']}"
          end
          if worker["hashrate"] == '0.0'
            create_event :payload => { 'poll' => interpolated[:pool_url], 'wallet' => interpolated[:wallet_address], 'status' => "hashrate is 0", 'hashrate' => payload['data']['hashrate'], 'worker' => worker["id"] }
          end
        end
      end
    end    
  end
end
