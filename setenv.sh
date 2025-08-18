#!/bin/bash

[ "${BASH_SOURCE[0]}" = "${0}" ]                                                                && {
    echo "${BASH_SOURCE[0]}"
    echo "${0}"
    echo -e "Execution of this script is not intended.\nSource the script, using \"source `
            `${BASH_SOURCE[0]}\""
    exit 1
}

export G_DSP_ENV_ROOT="$(cd "$(dirname ${BASH_SOURCE[0]})" &> /dev/null && pwd)"
export G_DSP_ENV_PATH_TO_CONF_YAML="${G_DSP_ENV_ROOT}/dsp_env_config.yaml"

source ${G_DSP_ENV_ROOT}/scripts/utils/dsp_env_color_log.sh
for SCRIPT in ${G_DSP_ENV_ROOT}/scripts/*/*; do
    [ -f "${SCRIPT}" ]                                                                          && {
        source "${SCRIPT}"
    }
done
