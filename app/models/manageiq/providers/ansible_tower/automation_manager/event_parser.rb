module ManageIQ::Providers::AnsibleTower::AutomationManager::EventParser
  def self.source
    "ANSIBLETOWER"
  end

  def event_to_hash(event, ems_id)
    filtered_event_data = event.dup.tap do |data|
      if (changes_hash = data[:full_data]["changes"])
        changes_hash["extra_vars"] = '[FILTERED]' if changes_hash["extra_vars"]
      end
    end

    {
      :event_type => "#{event['object1']}_#{event['operation']}",
      :source     => "#{self.source}",
      :timestamp  => event['timestamp'],
      :full_data  => filtered_event_data,
      :ems_id     => ems_id
    }
  end
end
