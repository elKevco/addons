#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Configure OTBR depending on add-on settings
# ==============================================================================

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

ot-ctl trel enable

if bashio::config.true 'nat64'; then
    bashio::log.info "Enabling NAT64."
    ot-ctl nat64 enable
    ot-ctl dns server upstream enable
fi

if bashio::config.true 'beta'; then
    mdns_localhostname="$(hostname)-otbr"
    bashio::log.info "Setting OpenThread mDNS local hostname to ${mdns_localhostname}."
    ot-ctl mdns localhostname "${mdns_localhostname}"
    ot-ctl mdns enable
fi

# To avoid asymmetric link quality the TX power from the controller should not
# exceed that of what other Thread routers devices typically use.
ot-ctl txpower 6
