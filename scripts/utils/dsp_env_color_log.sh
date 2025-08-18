#!/bin/bash

function log-error() {
    local RED="\033[0;31m"
    local NOCOL="\033[0m"

    echo -e "${RED}${@}${NOCOL}"
    return 1
}

function log-success() {
    local GREEN="\033[0;32m"
    local NOCOL="\033[0m"

    echo -e "${YELLOW}${@}${NOCOL}"
    return 0
}

function log-warn() {
    local YELLOW="\033[0;33m"
    local NOCOL="\033[0m"

    echo -e "${YELLOW}${@}${NOCOL}"
}

function log-info() {
    local BLUE="\033[0;34m"
    local NOCOL="\033[0m"

    echo -e "${BLUE}${@}${NOCOL}"
}
