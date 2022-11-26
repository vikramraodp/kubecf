#!/usr/bin/env bash

# This patch disables the check for existence of subjectAltName extension
# in the tls certificate
# Seems like the current stemcell is unable to handle OpenSSL
# therefore the present check needs to be removed.
#
#
# [1] chart/assets/operations/instance_groups/router.yaml
#
# Result: The patch is extremely specific to kubecf, and cannot be
# upstreamed.

set -o errexit -o nounset

target="/var/vcap/all-releases/jobs-src/routing/gorouter/templates/gorouter.yml.erb"
sentinel="${target}.patch_sentinel"
if [[ -f "${sentinel}" ]]; then
  if sha256sum --check "${sentinel}" ; then
    echo "Patch already applied. Skipping"
    exit 0
  fi
  echo "Sentinel mismatch, re-patching"
fi

patch --verbose "${target}" <<'EOT'
@@ -1,5 +1,7 @@
 ---
 <%=
+require 'openssl'
+
 def property_or_link(description, property, link_path, link_name=nil, optional=false)
   link_name ||= link_path.split('.').first
   if_p(property) do |prop|
EOT

sha256sum "${target}" > "${sentinel}"