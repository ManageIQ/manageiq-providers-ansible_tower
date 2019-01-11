module ManageIQ::Providers::AnsibleTower::Shared::Inventory::Collector::TargetCollection
  def connection
    @connection ||= manager.connect
  end

  # def inventories
  #
  # end
end
