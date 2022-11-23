#!/usr/bin/env bash

set -o errexit -o nounset

target="/var/vcap/all-releases/jobs-src/diego/rep/templates/rep.json.erb"
sentinel="${target}.patch_sentinel"
if [[ -f "${sentinel}" ]]; then
  if sha256sum --check "${sentinel}" ; then
    echo "Patch already applied. Skipping"
    exit 0
  fi
  echo "Sentinel mismatch, re-patching"
fi

# Don't share /var/vcap/packages between containers.
patch --verbose "${target}" <<'EOT'
--- /mnt/d/Temp/delete/kubecf_release/patches/rep.json.erb	2022-01-31 22:07:07.000000000 +0530
+++ /mnt/d/Temp/delete/kubecf_release/patches/rep.json-modified.erb	2022-11-23 20:43:44.368565900 +0530
@@ -58,7 +58,7 @@
     disk_mb: p("diego.executor.disk_capacity_mb").to_s,
     enable_consul_service_registration: p("enable_consul_service_registration"),
     enable_declarative_healthcheck: p("enable_declarative_healthcheck"),
-    declarative_healthcheck_path: "/var/vcap/packages/healthcheck",
+    declarative_healthcheck_path: "/var/vcap/data/shared-packages/healthcheck",
     enable_container_proxy: p("containers.proxy.enabled"),
     container_proxy_require_and_verify_client_certs: p("containers.proxy.require_and_verify_client_certificates"),
     container_proxy_trusted_ca_certs: p("containers.proxy.trusted_ca_certificates"),
@@ -68,7 +68,7 @@
     enable_unproxied_port_mappings: p("containers.proxy.enable_unproxied_port_mappings"),
     proxy_memory_allocation_mb: p("containers.proxy.additional_memory_allocation_mb"),
     proxy_enable_http2: p("containers.proxy.enable_http2"),
-    container_proxy_path: "/var/vcap/packages/proxy",
+    container_proxy_path: "/var/vcap/data/shared-packages/proxy",
     container_proxy_config_path: "/var/vcap/data/rep/shared/garden/proxy_config",
     evacuation_polling_interval: "#{p("diego.rep.evacuation_polling_interval_in_seconds")}s",
     evacuation_timeout: "#{p("diego.rep.evacuation_timeout_in_seconds")}s",
EOT

sha256sum "${target}" > "${sentinel}"