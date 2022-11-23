#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

target="/var/vcap/all-releases/jobs-src/silk/silk-cni/templates/cni-wrapper-plugin.conflist.erb"
sentinel="${target}.patch_sentinel"
if [[ -f "${sentinel}" ]]; then
  if sha256sum --check "${sentinel}" ; then
    echo "Patch already applied. Skipping"
    exit 0
  fi
  echo "Sentinel mismatch, re-patching"
fi

# Resolve DNS Servers passed via the `dns_servers` property if any is a hostname
# instead of an IP address.
patch --verbose "${target}" <<'EOT'
@@ -2,6 +2,7 @@
 <%=
   require 'ipaddr'
   require 'json'
+  require 'resolv'
 
   def compute_mtu
     vxlan_overhead = 50
@@ -13,6 +14,15 @@
     end
   end
 
+  def get_ipaddress(ip, var_name)
+    if (var_name == 'dns_servers')
+      if !(ip =~ Regexp.union([Resolv::IPv4::Regex, Resolv::IPv6::Regex]))
+        return Resolv.getaddress ip
+      end
+    end
+    return IPAddr.new ip
+  end
+
   # this method is here to check for leading 0s
   def parse_ips (ips, var_name)
     ips.map {|ip| ip.split(":")[0]}.each do |ip|
@@ -23,7 +33,7 @@
   def parse_ip (ip, var_name)
     unless ip.empty?
         begin 
-          parsed = IPAddr.new ip
+          parsed = get_ipaddress ip, var_name
         rescue  => e
           raise "Invalid #{var_name} '#{ip}': #{e}"
         end
@@ -64,6 +74,13 @@
   parse_ips(p('host_tcp_services'), 'host_tcp_services')
   parse_ips(p('host_udp_services'), 'host_udp_services')
 
+  dns_servers = p('dns_servers').map do |dns_server|
+    if !(dns_server =~ Regexp.union([Resolv::IPv4::Regex, Resolv::IPv6::Regex]))
+      Resolv.getaddress dns_server
+    else
+      dns_server
+    end
+  end
 
   toRender = {
     'name' => 'cni-wrapper',
@@ -85,7 +102,7 @@
       'ingress_tag' => 'ffff0000',
       'vtep_name' => 'silk-vtep',
       'policy_agent_force_poll_address' => '127.0.0.1:' + link('vpa').p('force_policy_poll_cycle_port').to_s,
-      'dns_servers' => p('dns_servers'),
+      'dns_servers' => dns_servers,
       'host_tcp_services' => p('host_tcp_services'),
       'host_udp_services' => p('host_udp_services'),
       'deny_networks' => {
EOT

sha256sum "${target}" > "${sentinel}"