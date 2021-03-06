# Fact:
#   lldp_neighbor_chassisid_<interface>
#   lldp_neighbor_mngaddr_ipv4_<interface>
#   lldp_neighbor_mngaddr_ipv6_<interface>
#   lldp_neighbor_mtu_<interface>
#   lldp_neighbor_portid_<interface>
#   lldp_neighbor_sysname_<interface>
#   lldp_neighbor_pvid_<interface>
#
# Purpose:
#   Return information about the host's LLDP neighbors.
#
# Resolution:
#   On hosts with the lldptool binary, send queries to the lldpad for each of
#   the host's Ethernet interfaces and parse the output.
#
# Caveats:
#   Assumes that the connected Ethernet switch is sending LLDPDUs, Open-LLDP
#   (lldpad) is running, and lldpad is configured to receive LLDPDUs on each
#   Ethernet interface.
#
# Authors:
#   Mike Arnold <mike@razorsedge.org>
#
# Copyright:
#   Copyright (C) 2012 Mike Arnold, unless otherwise noted.
# https://forge.puppetlabs.com/razorsedge/openlldp

require 'facter/util/macaddress'

# http://www.ruby-forum.com/topic/3418285#1040695
module Enumerable
  def grep_v(cond)
    select {|x| not cond === x}
  end
end

if Facter::Util::Resolution.which('lldptool')
  lldp = {
    # LLDP Name    Numeric value
    'chassisID'    => '1',
    'portID'       => '2',
    'sysName'      => '5',
    'mngAddr_ipv4' => '8',
    'mngAddr_ipv6' => '8',
    'PVID'         => '0x0080c201',
    'MTU'          => '0x00120f04',
  }

  # Remove interfaces that pollute the list (like lo and bond0).
  Facter.value('interfaces').split(/,/).grep_v(/^lo$|^bond[0-9]/).each do |interface|
    # Loop through the list of LLDP TLVs that we want to present as facts.
    lldp.each_pair do |key, value|
      Facter.add("lldp_neighbor_#{key}_#{interface}") do
        setcode do
          result = ""
          output = Facter::Util::Resolution.exec("sudo lldptool get-tlv -n -i #{interface} -V #{value} 2>/dev/null")
          if not output.nil?
            case key
            when 'sysName', 'MTU'
              output.split("\n").each do |line|
                result = $1 if line.match(/^\s+(.*)/)
              end
            when 'chassisID'
              output.split("\n").each do |line|
                ether = $1 if line.match(/MAC:\s+(.*)/)
                result = Facter::Util::Macaddress.standardize(ether)
              end
            when 'portID'
              output.split("\n").each do |line|
                result = $1 if line.match(/Ifname:\s+(.*)/)
              end
            when 'mngAddr_ipv4'
              output.split("\n").each do |line|
                result = $1 if line.match(/IPv4:\s+(.*)/)
              end
            when 'mngAddr_ipv6'
              output.split("\n").each do |line|
                result = $1 if line.match(/IPv6:\s+(.*)/)
              end
            when 'PVID'
              output.split("\n").each do |line|
                result = $1.to_i if line.match(/Info:\s+(.*)/)
              end
            else
              # case default
              result = nil
            end
          else
            # No output from lldptool
            result = nil
          end
          result
        end
      end
    end
  end
end
