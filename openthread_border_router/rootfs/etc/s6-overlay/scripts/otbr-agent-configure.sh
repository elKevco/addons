#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Configure OTBR depending on add-on settings
# ==============================================================================
# Fix: ot-ctl does not support OT_CLI_CONNECT_SOCKET env var.
# All ot-ctl calls must use the -I <interface> flag explicitly.
# Additionally added a socket readiness wait loop to avoid race condition.
# See: https://github.com/jmarcelomb/addons/issues/XXX

# Read the thread interface name to target the correct instance
thread_if="wpan0"
if [ -f /tmp/otbr-thread-interface ]; then
    thread_if=$(cat /tmp/otbr-thread-interface)
fi
export OT_CLI_CONNECT_SOCKET="/run/openthread-${thread_if}.sock"

if bashio::config.true 'disable_border_routing'; then
    bashio::log.info "Border routing is DISABLED on ${thread_if} - skipping TREL and NAT64 config"
    exit 0
fi

# Wait for the ot-ctl socket to become available (race condition fix)
for i in $(seq 1 30); do
    if [ -S "/run/openthread-${thread_if}.sock" ]; then
        bashio::log.info "OTBR socket ready on ${thread_if} (attempt ${i}/30)"
        break
    fi
    bashio::log.warning "Waiting for OTBR socket on ${thread_if} (attempt ${i}/30)..."
    sleep 1
done

# Enable TREL using explicit interface flag (-I) since ot-ctl ignores OT_CLI_CONNECT_SOCKET
ot-ctl -I "${thread_if}" trel enable

if bashio::config.true 'nat64'; then
    bashio::log.info "Enabling NAT64."
    ot-ctl -I "${thread_if}" nat64 enable
    ot-ctl -I "${thread_if}" dns server upstream enable
fi

if bashio::config.true 'beta'; then
    mdns_localhostname="$(hostname)-otbr"
    bashio::log.info "Setting OpenThread mDNS local hostname to ${mdns_localhostname}."
    ot-ctl -I "${thread_if}" mdns localhostname "${mdns_localhostname}"
    ot-ctl -I "${thread_if}" mdns enable
fi

# To avoid asymmetric link quality the TX power from the controller should not
# exceed that of what other Thread routers devices typically use.
ot-ctl -I "${thread_if}" txpower 6
