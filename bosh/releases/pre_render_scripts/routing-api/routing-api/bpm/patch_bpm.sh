#!/usr/bin/env bash

# This patch changes the BPM command to not use spec.ip because the
# quarks-operator implements process management very differently from
# BOSH: BPM is rendered from a completely different container (and
# therefore has no chance of having a valid spec.ip).
#
# We have no idea how we can implement the change in an upstream-
# compatible way: we hack around things by changing the POD_IP
# environment variable via an ops file [1], which wouldn't make any
# sense in the BOSH VM world.
#
# [1] chart/assets/operations/instance_groups/routing-api.yaml
#
# Result: The patch is extremely specific to kubecf, and cannot be
# upstreamed.

set -o errexit -o nounset

target="/var/vcap/all-releases/jobs-src/routing/routing-api/templates/bpm.yml.erb"
sentinel="${target}.patch_sentinel"
if [[ -f "${sentinel}" ]]; then
  if sha256sum --check "${sentinel}" ; then
    echo "Patch already applied. Skipping"
    exit 0
  fi
  echo "Sentinel mismatch, re-patching"
fi

patch --verbose "${target}" <<'EOT'
@@ -14,7 +14,7 @@
         "-timeFormat",
         "rfc3339",
         "-ip",
-        spec.ip,
+        "$(POD_IP)",
       ],
       "hooks" => {
         "pre_start" => "/var/vcap/jobs/routing-api/bin/bpm-pre-start"
@@ -31,5 +31,7 @@
   bpm['processes'][0]['env'].merge!({"GODEBUG" => "x509ignoreCN=0"})
 end

+bpm['processes'][0]['env'].merge!({"POD_IP" => "0.0.0.0"})
+
 YAML.dump(bpm)
 %>
EOT

sha256sum "${target}" > "${sentinel}"
