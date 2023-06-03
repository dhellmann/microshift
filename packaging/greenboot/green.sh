#!/usr/bin/env bash

set -e

# Source the MicroShift health check functions library
# shellcheck source=packaging/greenboot/functions.sh
source /usr/share/microshift/functions/greenboot.sh

HEALTH=healthy

mkdir -p /var/lib/microshift-backups

boot=$(tr -d '-' < /proc/sys/kernel/random/boot_id)
deploy=$(get_ostree_deployment_id)

echo "recording ${HEALTH} status for boot ${boot} from deployment ${deploy}"

jq \
    --null-input \
    --arg health "${HEALTH}" \
    --arg deploy "${deploy}" \
    --arg boot "${boot}" \
    '{ "health": $health, "deployment_id": $deploy, "boot_id": $boot }' > /var/lib/microshift-backups/health.json
