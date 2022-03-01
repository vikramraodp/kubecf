#!/usr/bin/env bash

set -o errexit -o nounset

release="credhub"
job="credhub"
target="/var/vcap/all-releases/jobs-src/${release}/${job}/job.MF"

sentinel="${target}.patch_sentinel"
if [[ -f "${sentinel}" ]]; then
  if sha256sum --check "${sentinel}" ; then
    echo "Patch already applied. Skipping"
    exit 0
  fi
  echo "Sentinel mismatch, re-patching"
fi

patch --verbose "${target}" <<'EOT'
@@ -76,11 +76,6 @@
   - credhub.data_storage.type
   - credhub.data_storage.username

-consumes:
-- name: postgres
-  type: database
-  optional: true
-
 properties:
   credhub.connection-timeout:
     description: "The maximum amount of time the server will wait for the client to make their request after connecting before the connection is closed"
EOT

sha256sum "${target}" > "${sentinel}"