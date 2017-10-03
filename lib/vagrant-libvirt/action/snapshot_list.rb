module VagrantPlugins
  module ProviderLibvirt
    module Action
      class SnapshotList
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info(I18n.t("vagrant.actions.vm.snapshot.list", name: env[:snapshot_name]))
          env[:machine].provider.driver.list_snapshots(env[:machine].id, env[:snapshot_name])
          @app.call(env)
        end
      end
    end
  end
end
