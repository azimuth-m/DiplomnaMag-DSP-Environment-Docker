#!/bin/bash

# Detect successfully source setenv,sh
[ -z ${G_DSP_ENV_ROOT} ]                                                                        && {
    echo "Environment setup shell \"setenv.sh\" file must be sourced first."
    return 1
}

# Handle file excution, as oppesd to sourcing
[ "${BASH_SOURCE[0]}" = "${0}" ]                                                                && {
    echo "${BASH_SOURCE[0]}"
    echo "${0}"
    echo "Execution of this script is not intended."
    echo "Environment setup shell \"setenv.sh\" file must be sourced first"
    exit 1
}

function dsp-env-build-docker-image() {
    local DOCKER_IMAGE_NAME
    local PATH_TO_HEXAGON_SDK_ROOT
    local HEXAGON_VER
    local AARCH64_CROSS_COMPILER_URL
    local AARCH64_CROSS_COMPILER_ASC_URL
    local SAMPLE_MEMCPY_REPO_SSH_URL

    local PATH_TO_TMP_DIR="${G_DSP_ENV_ROOT}/tmp"

    # Ensure that the tmp dir is cleaned up on exit (any return code value)
    trap 'rm -rf "${PATH_TO_TMP_DIR}"' RETURN

    local DOCKER_CONTEXT_DIR="${G_DSP_ENV_ROOT}"
    local USER_GROUPS


    # YAML PARSE ###################################################################################
    # Parse needed fields from config yaml. Pipefail prevents rc masking
    set -o pipefail
    yq-parse '.DSP_ENV_DOCKER_IMAGE_NAME'              'DOCKER_IMAGE_NAME'
    yq-parse '.DSP_ENV_PATH_TO_HEXAGON_SDK_ROOT'       'PATH_TO_HEXAGON_SDK_ROOT'
    yq-parse '.DSP_ENV_HEXAGON_VER'                    'HEXAGON_VER'
    yq-parse '.DSP_ENV_AARCH64_CROSS_COMPILER_URL'     'AARCH64_CROSS_COMPILER_URL'
    yq-parse '.DSP_ENV_AARCH64_CROSS_COMPILER_ASC_URL' 'AARCH64_CROSS_COMPILER_ASC_URL'
    yq-parse '.DSP_ENV_SAMPLE_MEMCPY_REPO_SSH_URL'     'SAMPLE_MEMCPY_REPO_SSH_URL'
    [ ${?} -ne 0 ]                                                                              && {
        log-error "In function ${FUNCNAME}(): Failed to parse ${G_DSP_ENV_PATH_TO_CONF_YAML}"
        return 1
    }
    # Enable rc masking again
    set +o pipefail

    # DOWNLOAD CROSS COMPILER ######################################################################
    # Create a temp dir to store downloaded compiler
    [ ! -d "${PATH_TO_TMP_DIR}" ]                                                               && {
        mkdir -p ${PATH_TO_TMP_DIR}                                                             || {
            log-error "In function ${FUNCNAME}(): Failed to create a temporary directory."
            return 1
        }
    }

    (
        cd ${PATH_TO_TMP_DIR}

        # Download cross compiler
        wget -c -O "$(basename ${AARCH64_CROSS_COMPILER_URL})"                                     \
                "${AARCH64_CROSS_COMPILER_URL}"                                                 || {
            log-error "In function ${FUNCNAME}(): `
                    `Failed to download cross-compiler. Cleaning up..."
            return 1
        }

        # Download cross compiler armor file
        wget -c -O "$(basename ${AARCH64_CROSS_COMPILER_ASC_URL})"                                 \
                "${AARCH64_CROSS_COMPILER_ASC_URL}"                                             || {
            log-error "In function ${FUNCNAME}(): `
                    `Failed to download cross compiler armor file. Cleaning up..."
            return 1
        }

        # Verify downloaded cross compiler.
        md5sum -c "$(basename ${AARCH64_CROSS_COMPILER_ASC_URL})" &> /dev/null                  || {
            log-error "In function ${FUNCNAME}(): `
                    `Failed to verify cross-compiler."
            return 1
        }
    )

    # SETUP HEXAGON SDK ############################################################################
    # In order to ommit a copy of HexagonSDK to a Docker build context directory, a workaround is
    # used to bind it to a directory that is already there. Unfortunately, the mount bind requires
    # sudo privilages. Softlinking does not work for directories.
    # This is a limitation of the Docker build
    log-info "Copying HexagonSDK into docker context directory..."
    rsync -a                                                                                       \
            ${PATH_TO_HEXAGON_SDK_ROOT}                                                            \
            ${PATH_TO_TMP_DIR}                                                                  || {
        log-error "In function ${FUNCNAME}(): `
                `Failed to bind HexagonSDK root directory to a docker context directory."
        return 1
    }

    git -C ${PATH_TO_TMP_DIR} clone ${SAMPLE_MEMCPY_REPO_SSH_URL}                               || {
        log-error "In function ${FUNCNAME}(): `
                `Failed to clone sample memcpy repo: ${SAMPLE_MEMCPY_REPO_SSH_URL}"
        return 1
    }

    # DOCKER BUILD #################################################################################
    USER_GROUPS=$(getent group $(id -g ${USER}) | cut -d ':' -f 1)
    docker build                                                                                   \
            --build-arg ARG_DSP_ENV_HOST_USER_ID="$(id -u ${USER})"                                \
            --build-arg ARG_DSP_ENV_HOST_GROUP_ID="$(id -g ${USER})"                               \
            --build-arg ARG_DSP_ENV_HOST_USER="${USER}"                                            \
            --build-arg ARG_DSP_ENV_HOST_GROUP="${USER_GROUPS}"                                    \
            --build-arg ARG_DSP_ENV_ARM_TOOLCHAIN_ARCHIVE_NAME="$(basename `                       \
                    `${AARCH64_CROSS_COMPILER_URL})"                                               \
            --build-arg ARG_DSP_ENV_HEXAGON_TOOLCHAIN_DIRECTORY_NAME="$(basename `
                    `${PATH_TO_HEXAGON_SDK_ROOT})"                                                 \
            --build-arg ARG_DSP_ENV_HEXAGON_VER="${HEXAGON_VER}"                                   \
            --build-arg ARG_DSP_ENV_TMP_DIR_BASENAME="$(basename ${PATH_TO_TMP_DIR})"              \
            --build-arg ARG_DSP_ENV_MEMCPY_REPO_DIRECTORY_NAME="$(basename `
                    `${SAMPLE_MEMCPY_REPO_SSH_URL} .git)"                                          \
            -f "${G_DSP_ENV_ROOT}/Dockerfile"                                                      \
            --progress=plain                                                                       \
            --target "dsp-env"                                                                     \
            "${DOCKER_CONTEXT_DIR}" -t "${DOCKER_IMAGE_NAME}"                                   || {
        log-error "In function ${FUNCNAME}(): `
                `Failed to build docker image"
        return 1
    }
    # rm -rf ${PATH_TO_TMP_DIR}
    return 0
}

function dsp-env-run-docker-container() {
    local DOCKER_IMAGE_NAME
    local DOCKER_CONTAINER_NAME

    # YAML PARSE ###################################################################################
    set -o pipefail
    yq-parse '.DSP_ENV_DOCKER_IMAGE_NAME'          'DOCKER_IMAGE_NAME'
    yq-parse '.DSP_ENV_DOCKER_CONTAINER_NAME'      'DOCKER_CONTAINER_NAME'
    yq-parse '.DSP_ENV_SAMPLE_MEMCPY_REPO_SSH_URL' 'SAMPLE_MEMCPY_REPO'
    [ ${?} -ne 0 ]                                                                              && {
        log-error "In function ${FUNCNAME}(): Failed to parse ${G_DSP_ENV_PATH_TO_CONF_YAML}"
        return 1
    }
    set +o pipefail

    # DOCKER RUN ###################################################################################
    docker run                                                                                     \
            -v /etc/timezone:/etc/timezone:ro                                                      \
            -v /etc/localtime:/etc/localtime:ro                                                    \
            -v /dev/bus/usb:/dev/bus/usb:ro                                                        \
            -it -d --privileged                                                                    \
            -h ${DOCKER_CONTAINER_NAME}                                                            \
            --user ${USER}                                                                         \
            --name ${DOCKER_CONTAINER_NAME}                                                        \
            ${DOCKER_IMAGE_NAME}                                                                && {
        log-success "Docker container started sucessfully."
        log-info "USR:PWD == ${USER}:1234"
    }                                                                                           || {
        log-error "In function ${FUNCNAME}(): `
                `Failed to run docker container"
        return 1
    }

    # Propagate ssh and gitconfig to container
    [ -d "/home/${USER}/.ssh/" ]                                                                && {
        docker cp /home/${USER}/.ssh/                                                              \
                ${DOCKER_CONTAINER_NAME}:/home/${USER}/                                         || {
            log-warn "In function ${FUNCNAME}(): docker cp for /home/${USER}/.ssh failed."
        }
    }

    [ -f "/home/${USER}/.gitconfig" ]                                                           && {
        docker cp /home/${USER}/.gitconfig                                                         \
                ${DOCKER_CONTAINER_NAME}:/home/${USER}/.gitconfig                               || {
            log-warn "In function ${FUNCNAME}(): docker cp for /home/${USER}/.gitconfig failed."
        }
    }

    [ -f "/etc/gitconfig" ]                                                                     && {
        docker cp /etc/gitconfig ${DOCKER_CONTAINER_NAME}:/etc/gitconfig                        || {
            log-warn "In function ${FUNCNAME}(): docker cp for /etc/gitconfig failed."
        }
    }
}

log-info "#################################### DOCKER ####################################"
log-warn "dsp-env-build-docker-image"
echo -e "    Builds a docker image, with neded files to develop for target Hexagon DSP\n"

log-warn "dsp-env-run-docker-container"
echo -e "    Runs a docker container, in privilaged mode, with usb devices mounted and \n`
        `    .ssh and .gitconfig of current user propagated."
