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
@@ -282,16 +282,6 @@
     if !cert_pair.is_a?(Hash) || !cert_pair.key?('cert_chain') || !cert_pair.key?('private_key')
       raise 'must provide cert_chain and private_key with tls_pem'
     end
-
-    cert = OpenSSL::X509::Certificate.new cert_pair['cert_chain']
-    has_san = cert.extensions.map { |ext|
-      x509ext = OpenSSL::X509::Extension.new ext
-      x509ext.oid == "2.5.29.17" || x509ext.oid == "subjectAltName" # https://oidref.com/2.5.29.17
-    }.reduce(:|)
-
-    if ! p('golang.x509ignoreCN') and ! has_san
-      raise "tls_pem[#{i}].cert_chain must include a subjectAltName extension"
-    end
   }

   params['tls_pem'] = p('router.tls_pem')
EOT

sha256sum "${target}" > "${sentinel}"