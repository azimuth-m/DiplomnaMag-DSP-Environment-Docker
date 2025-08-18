#!/bin/bash

#   ${1} [in]  - Field to parse
#   ${2} [out] - Extracted data from filed
function yq-parse() {
    local    YAML_FIELD_NAME=${1}
    local -n YAML_FIELD_DATA=${2}

    [ -z "${YAML_FIELD_NAME}" ]                                                                 && {
        log-error "YAML field name is mandatory as a first argument."
        return 1
    }

    [ ${#} -ne 2 ] && {
        log-error "Incorrect usage. ${FUNCNAME} accepts two arguments."
        return 1
    }

    # Check if yq is installed on system
    which yq &> /dev/null
    [ ${?} -ne 0 ]                                                                              && {
        log-error "Missing yq package"
        return 1
    }

    YAML_FIELD_DATA=$(                                                                             \
            yq "${YAML_FIELD_NAME}"                                                                \
                ${G_DSP_ENV_PATH_TO_CONF_YAML} 2> /dev/null | tr -d '"')
    [ ${?} -ne 0 ]                                                                              && {
        log-error "Failed to parse \"${YAML_FIELD_NAME}\""
        return 1
    }
    return 0
}
