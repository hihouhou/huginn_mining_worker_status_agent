module Agents
  class MiningWorkerStatusAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule '1h'

    description do
      <<-MD
      The mining worker status agent fetches worker status (Offline/Online/etc) and creates an event when it changes.

      `pool_url` needed for mining pool website (like https://clopool.pro )

      `wallet_address` needed for the wanted address

      `status_wanted` can be workersOnline, workersOffline or workersTotal

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
        'expected_receive_period_in_days' => '2',
        'status_wanted' => 'workersOnline'
      }
    end

    form_configurable :pool_url, type: :string
    form_configurable :wallet_address, type: :string
    form_configurable :status_wanted, type: :array, values: ['workersOnline', 'workersOffline', 'workersTotal']
    form_configurable :expected_receive_period_in_days, type: :string

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
      memory['last_status'].to_i > 0

      return false if recent_error_logs?
      
      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def check
      fetch
    end

    private

    def fetch
      uri = URI.parse(interpolated[:pool_url] + "/api/accounts/" + interpolated[:wallet_address])
      request = Net::HTTP::Get.new(uri)
    
      req_options = {
        use_ssl: uri.scheme == "https",
      }
    
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      notification_json = JSON.parse(response.body)
      
      payload = { interpolated[:status_wanted] => notification_json[interpolated[:status_wanted]] }
    
      log "fetch notification request status : #{response.code}"
    
      if payload.to_s != memory['last_status']
        memory['last_status'] = payload.to_s
        create_event payload: payload
      end
    end    
  end
end
