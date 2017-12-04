require 'libvirt'
require 'fog/libvirt'
require 'log4r'
require 'pry'

module VagrantPlugins
  module ProviderLibvirt
    class Driver
      # store the connection at the process level
      #
      # possibly this should be a connection pool using the connection
      # settings as a key to allow per machine connection attributes
      # to be used.
      @@connection = nil
	  @@raw_connection = nil

      def initialize(machine)
        @logger = Log4r::Logger.new('vagrant_libvirt::driver')
        @machine = machine
      end
      
      def raw_connection
        return @@raw_connection if @@raw_connection
		@@raw_connection = 	Libvirt::open("qemu:///system")
		@@raw_connection
      end

      def connection
        # If already connected to libvirt, just use it and don't connect
        # again.
        return @@connection if @@connection

        # Get config options for libvirt provider.
        config = @machine.provider_config
        uri = config.uri

        conn_attr = {}
        conn_attr[:provider] = 'libvirt'
        conn_attr[:libvirt_uri] = uri
        conn_attr[:libvirt_username] = config.username if config.username
        conn_attr[:libvirt_password] = config.password if config.password

        # Setup command for retrieving IP address for newly created machine
        # with some MAC address. Get it from dnsmasq leases table
        ip_command = %q( awk "/$mac/ {print \$1}" /proc/net/arp )
        conn_attr[:libvirt_ip_command] = ip_command

        @logger.info("Connecting to Libvirt (#{uri}) ...")
        begin
          @@connection = Fog::Compute.new(conn_attr)
        rescue Fog::Errors::Error => e
          raise Errors::FogLibvirtConnectionError,
                error_message: e.message
        end

        @@connection
      end

      def get_domain(mid)
        begin
          domain = connection.servers.get(mid)
        rescue Libvirt::RetrieveError => e
          if e.libvirt_code == ProviderLibvirt::Util::ErrorCodes::VIR_ERR_NO_DOMAIN
            @logger.debug("machine #{mid} not found #{e}.")
            return nil
          else
            raise e
          end
        end

        domain
      end

      def create_snapshot(mid, snapshot_name)
		domain = raw_connection.lookup_domain_by_uuid(mid)
		domain.snapshot_create_xml("<domainsnapshot><name>#{snapshot_name}</name><description>running recorder agent</description></domainsnapshot>")
        # binding.pry
      end

      def list_snapshots(mid)
		domain = raw_connection.lookup_domain_by_uuid(mid)
		return domain.list_snapshots()
      end

      def created?(mid)
        domain = get_domain(mid)
        !domain.nil?
      end

      def get_ipaddress(machine)
        # Find the machine
        domain = get_domain(machine.id)

        if domain.nil?
          # The machine can't be found
          return nil
        end

        # Get IP address from arp table
        ip_address = nil
        begin
          domain.wait_for(2) do
            addresses.each_pair do |_type, ip|
              # Multiple leases are separated with a newline, return only
              # the most recent address
              ip_address = ip[0].split("\n").first unless ip[0].nil?
            end
            !ip_address.nil?
          end
        rescue Fog::Errors::TimeoutError
          @logger.info('Timeout at waiting for an ip address for machine %s' % machine.name)
        end

        unless ip_address
          @logger.info('No arp table entry found for machine %s' % machine.name)
          return nil
        end

        ip_address
      end

      def state(machine)
        # may be other error states with initial retreival we can't handle
        begin
          domain = get_domain(machine.id)
        rescue Libvirt::RetrieveError => e
          @logger.debug("Machine #{machine.id} not found #{e}.")
          return :not_created
        end

        # TODO: terminated no longer appears to be a valid fog state, remove?
        return :not_created if domain.nil? || domain.state.to_sym == :terminated

        domain.state.tr('-', '_').to_sym
      end
    end
  end
end
