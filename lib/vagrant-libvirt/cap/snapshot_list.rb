require 'pry'

module VagrantPlugins
  module ProviderLibvirt
    module Cap
      module SnapshotList
        def self.snapshot_list(machine)
            # binding.pry
            return machine.provider.driver.list_snapshots(machine.id)
        end
      end
    end
  end
end
