FROM ubuntu:noble AS dsp-env

# Arguments passed via docker build
ARG ARG_DSP_ENV_HOST_USER_ID
ARG ARG_DSP_ENV_HOST_USER
ARG ARG_DSP_ENV_HOST_GROUP_ID
ARG ARG_DSP_ENV_HOST_GROUP

ARG ARG_DSP_ENV_ARM_TOOLCHAIN_ARCHIVE_NAME
ARG ARG_DSP_ENV_HEXAGON_TOOLCHAIN_DIRECTORY_NAME
ARG ARG_DSP_ENV_HEXAGON_VER
ARG ARG_DSP_ENV_TMP_DIR_BASENAME
ARG ARG_DSP_ENV_MEMCPY_REPO_DIRECTORY_NAME

# Environment variables
ENV DSP_ENV_BASE_DIR=/home/${ARG_DSP_ENV_HOST_USER}/dspenv
ENV DSP_ENV_PATH_TO_SDK_DIR=${DSP_ENV_BASE_DIR}/sdk
ENV DSP_ENV_PATH_TO_GCC_ARM=${DSP_ENV_PATH_TO_SDK_DIR}/gccarm
ENV DSP_ENV_PATH_TO_HEXAGON=${DSP_ENV_PATH_TO_SDK_DIR}/hexagon
ENV DSP_ENV_HEXAGON_VER=${ARG_DSP_ENV_HEXAGON_VER}
ENV DSP_ENV_PATH_TO_SRC=${DSP_ENV_BASE_DIR}/src
ENV DSP_ENV_MEMCPY_SRC_DIR=${DSP_ENV_PATH_TO_SRC}/memcpy_src
ENV DSP_ENV_INSTALL_DIR=${DSP_ENV_BASE_DIR}/install

# Force reuse of existing group
RUN if getent group ${ARG_DSP_ENV_HOST_GROUP_ID}; then                                             \
        groupmod -n                                                                                \
            ${ARG_DSP_ENV_HOST_GROUP}                                                              \
            $(getent group ${ARG_DSP_ENV_HOST_GROUP_ID} | cut -d: -f1);                            \
    else                                                                                           \
        groupadd --gid ${ARG_DSP_ENV_HOST_GROUP_ID} ${ARG_DSP_ENV_HOST_GROUP};                     \
    fi                                                                                          && \
                                                                                                   \
    # Modify existing user
    if id -u ${ARG_DSP_ENV_HOST_USER_ID} >/dev/null 2>&1; then                                     \
        usermod -l ${ARG_DSP_ENV_HOST_USER}                                                        \
               -d /home/${ARG_DSP_ENV_HOST_USER}                                                   \
               -m $(getent passwd ${ARG_DSP_ENV_HOST_USER_ID} | cut -d: -f1)                    && \
        groupmod -n ${ARG_DSP_ENV_HOST_GROUP}                                                      \
                 $(getent group ${ARG_DSP_ENV_HOST_GROUP_ID} | cut -d: -f1);                       \
    else                                                                                           \
        groupadd -g ${ARG_DSP_ENV_HOST_GROUP_ID} ${ARG_DSP_ENV_HOST_GROUP}                      && \
        useradd -m                                                                                 \
               -u ${ARG_DSP_ENV_HOST_USER_ID}                                                      \
               -g ${ARG_DSP_ENV_HOST_GROUP}                                                        \
               -s /bin/bash                                                                        \
               ${ARG_DSP_ENV_HOST_USER};                                                           \
    fi                                                                                          && \
    echo ${ARG_DSP_ENV_HOST_USER}:1234 | chpasswd                                               && \
                                                                                                   \
    # Create a base directory and directory to host toolchains (arm, hexagon)
    mkdir -p ${DSP_ENV_BASE_DIR}                                                                && \
            chown ${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP} ${DSP_ENV_BASE_DIR}        && \
    mkdir -p ${DSP_ENV_PATH_TO_SDK_DIR}                                                         && \
            chown ${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP} ${DSP_ENV_PATH_TO_SDK_DIR} && \
    mkdir -p ${DSP_ENV_PATH_TO_GCC_ARM}                                                         && \
            chown ${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP} ${DSP_ENV_PATH_TO_GCC_ARM} && \
    mkdir -p ${DSP_ENV_PATH_TO_HEXAGON}                                                         && \
        chown ${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP} ${DSP_ENV_PATH_TO_HEXAGON}     && \
    mkdir -p ${DSP_ENV_PATH_TO_SRC}                                                             && \
        chown ${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP} ${DSP_ENV_PATH_TO_SRC}         && \
    mkdir -p ${DSP_ENV_MEMCPY_SRC_DIR}                                                          && \
            chown ${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP} ${DSP_ENV_MEMCPY_SRC_DIR}  && \
                                                                                                   \
    # Get needed packages
    apt update                                                                                  && \
    apt install sudo python3 python-is-python3 vim android-tools-adb android-tools-fastboot        \
    git curl wget git xz-utils build-essential libncurses6 unzip lsb-release cmake clang -y

# Switch to non-root user
USER ${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP}

# Copy gcc-arm archive to sdk directory
COPY --chown=${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP}                                    \
    ${ARG_DSP_ENV_TMP_DIR_BASENAME}/${ARG_DSP_ENV_ARM_TOOLCHAIN_ARCHIVE_NAME}                      \
    ${DSP_ENV_PATH_TO_GCC_ARM}

# Copy hexagon sdk to sdk directory
COPY --chown=${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP}                                    \
    ${ARG_DSP_ENV_TMP_DIR_BASENAME}/${ARG_DSP_ENV_HEXAGON_TOOLCHAIN_DIRECTORY_NAME}                \
    ${DSP_ENV_PATH_TO_HEXAGON}

# Copy the contents of the DSP Memcpy repo to src directory
COPY --chown=${ARG_DSP_ENV_HOST_USER}:${ARG_DSP_ENV_HOST_GROUP}                                    \
    ${ARG_DSP_ENV_TMP_DIR_BASENAME}/${ARG_DSP_ENV_MEMCPY_REPO_DIRECTORY_NAME}                      \
    ${DSP_ENV_MEMCPY_SRC_DIR}

RUN tar xfv                                                                                        \
    ${DSP_ENV_PATH_TO_GCC_ARM}/${ARG_DSP_ENV_ARM_TOOLCHAIN_ARCHIVE_NAME}                           \
    --directory=${DSP_ENV_PATH_TO_GCC_ARM}                                                      && \
                                                                                                   \
    # Source color print script
    echo ". ${DSP_ENV_MEMCPY_SRC_DIR}/scripts/dsp_env_color_log.sh"                                \
        >> /home/${ARG_DSP_ENV_HOST_USER}/.bashrc                                               && \
                                                                                                   \
    # Source other scripts
    echo 'for SCRIPT in $(find "${DSP_ENV_MEMCPY_SRC_DIR}" -type f -name "*.sh"); do'              \
         >> /home/${ARG_DSP_ENV_HOST_USER}/.bashrc                                              && \
    echo '    [ -f "${SCRIPT}" ] && . "${SCRIPT}"'                                                 \
         >> /home/${ARG_DSP_ENV_HOST_USER}/.bashrc                                              && \
    echo 'done'                                                                                    \
         >> /home/${ARG_DSP_ENV_HOST_USER}/.bashrc                                              && \
    echo '. ${DSP_ENV_PATH_TO_HEXAGON}/setup_sdk_env.source'                                                                                    \
         >> /home/${ARG_DSP_ENV_HOST_USER}/.bashrc
