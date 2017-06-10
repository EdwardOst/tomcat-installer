set -e
set -x

tomcat_installer_script_path=$(readlink -e "${BASH_SOURCE[0]}")
tomcat_installer_script_dir="${tomcat_installer_script_path%/*}"

tomcat_installer_util_path=$(readlink -e "${tomcat_installer_script_dir}/util/util.sh")
source "${tomcat_installer_util_path}"

tomcat_installer_file_path=$(readlink -e "${tomcat_installer_script_dir}/util/file-util.sh")
source "${tomcat_installer_file_path}"

tomcat_installer_parse_args_path=$(readlink -e "${tomcat_installer_script_dir}/util/parse-args.sh")
source "${tomcat_installer_parse_args_path}"

tomcat_installer_scope_context_path=$(readlink -e "${tomcat_installer_script_dir}/util/scope-context.sh")
source "${tomcat_installer_scope_context_path}"

define tomcat_installer_init <<'EOF'
    local tomcat_installer_tomcat_version="${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    local tomcat_installer_tomcat_user="${TOMCAT_INSTALLER_TOMCAT_USER:-${tomcat_installer_tomcat_user:-tomcat}}"
    local tomcat_installer_tomcat_group="${TOMCAT_INSTALLER_TOMCAT_GROUP:-${tomcat_installer_tomcat_group:-tomcat}}"
    local tomcat_installer_repo_dir="${TOMCAT_INSTALLER_REPO_DIR:-${tomcat_installer_repo_dir:-/opt/repo/tomcat}}"
    local tomcat_installer_target_dir="${TOMCAT_INSTALLER_TARGET_DIR:-${tomcat_installer_target_dir:-/opt}}"
    local tomcat_installer_mirror="${TOMCAT_INSTALLER_MIRROR:-${tomcat_installer_mirror:-apache.osuosl.org}}"
    local tomcat_installer_tomcat_dir="${TOMCAT_INSTALLER_TARGET_DIR:-${tomcat_installer_target_dir:-/opt}}/apache-tomcat-${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    local tomcat_installer_tomcat_tgz_file="${TOMCAT_INSTALLER_TOMCAT_TGZ_FILE:-${tomcat_installer_tomcat_tgz_file:-apache-tomcat-${tomcat_installer_tomcat_version}.tar.gz}}"
EOF

declare -A tomcat_installer_context=(
    ["tomcat_version"]="${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    ["tomcat_user"]="${TOMCAT_INSTALLER_TOMCAT_USER:-${tomcat_installer_tomcat_user:-tomcat}}"
    ["tomcat_group"]="${TOMCAT_INSTALLER_TOMCAT_GROUP:-${tomcat_installer_tomcat_group:-tomcat}}"
    ["repo_dir"]="${TOMCAT_INSTALLER_REPO_DIR:-${tomcat_installer_repo_dir:-/opt/repo/tomcat}}"
    ["target_dir"]="${TOMCAT_INSTALLER_TARGET_DIR:-${tomcat_installer_target_dir:-/opt}}"
    ["mirror"]="${TOMCAT_INSTALLER_MIRROR:-${tomcat_installer_mirror:-apache.osuosl.org}}"
    ["tomcat_dir"]="${TOMCAT_INSTALLER_TARGET_DIR:-${tomcat_installer_target_dir:-/opt}}/apache-tomcat-${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    )
#    ["tomcat_tgz_file"]="${TOMCAT_INSTALLER_TOMCAT_TGZ_FILE:-${tomcat_installer_tomcat_tgz_file:-apache-tomcat-${tomcat_installer_tomcat_version}.tar.gz}}"

function tomcat_installer_help() {
    cat <<-EOF
	install tomcat

	constraints:
	    script must be run with sufficient privileges to do create folders and chown for target directories and files.
	    Directories and files will be created with <tomcat_user> and <tomcat_group> configurations.

	usage:
	    tomcat-installer [options] <command> [command-options]

	    options:
	        -h help
	        -c specify an alternative configuration as an associative array

	    subcommands:
	        download
	        install
	        uninstall
	        help

	    download
	        tomcat_installer download [-v tomcat_version] [-u tomcat_user] [-g tomcat_group] [-r repo_dir]

	    install
	        tomcat_installer install [-r repo_dir] [-t target_dir]

	    uninstall
	        tomcat_installer uninstall [-t target_dir]

	EOF
}

function tomcat_installer_create_user() {
    id -ng  "${tomcat_installer_tomcat_group}" || sudo groupadd "${tomcat_installer_tomcat_group}"
    id -nu "${tomcat_installer_tomcat_user}" || sudo useradd -s /bin/false -g "${tomcat_installer_tomcat_group}" "${tomcat_installer_tomcat_user}"
}

function tomcat_installer_download() {
    local tomcat_major_version="${tomcat_installer_tomcat_version:0:1}"
    local tomcat_major_folder="tomcat-${tomcat_major_version}"

    create_user_directory "${tomcat_installer_repo_dir}"

    wget --no-clobber \
         --directory-prefix="${tomcat_installer_repo_dir}" \
         "http://${tomcat_installer_mirror}/tomcat/${tomcat_major_folder}/v${tomcat_installer_tomcat_version}/bin/${tomcat_installer_tomcat_tgz_file}"
}

function tomcat_installer_install() {

    tomcat_installer_create_user

    # create tomcat directory
#    create_user_directory "${tomcat_installer_tomcat_dir}" "${tomcat_installer_tomcat_user}" "${tomcat_installer_tomcat_group}"
    create_user_directory "${tomcat_installer_tomcat_dir}" 

    # unzip tomcat file
    tar -xzf "${tomcat_installer_repo_dir}/${tomcat_installer_tomcat_tgz_file}" --directory "${tomcat_installer_target_dir}"

    # set owner to tomcat
    # catalina_home files should be owned by an administrative user, possibly without a login
    # catalina_home administrative user can belong to its own group
    # catalina_home service user will run the service
    # catalina_home service user should belong to a service group as well
    # privileges should be rw for the administrative user owner
    # privileges should be ro for the service group
    # privileges should be none for other
    # catalina_home work, temp, and logs directory owned by service user
    #
    # catalina_base owned by an instance administrative account, possibly without a login
    # catalina_base administrative user can belong to its own group
    # catalina_base service user will run the service
    # catalina_base service user should belong to the catalina_home service group 
    # catalina base files should use castalina_home service group since the service will need ro from catalina_home

    # create symbolic link to tomcat directory
    ln -s "${tomcat_installer_tomcat_dir}" "${tomcat_installer_target_dir}/tomcat"
    sudo chown -h "${tomcat_installer_tomcat_user}:${tomcat_installer_tomcat_group}" "${tomcat_installer_target_dir}/tomcat"

    # grant permissions on work, temp, and logs to service user
    sudo chown -R "${tomcat_installer_tomcat_user}:${tomcat_installer_tomcat_group}" \
                  "${tomcat_installer_tomcat_dir}/work/" \
                  "${tomcat_installer_tomcat_dir}/temp/" \
                  "${tomcat_installer_tomcat_dir}/logs/"

    # this may only be necessary for Talend since it modifies files in conf dir
    sudo chgrp -R "${tomcat_installer_tomcat_group}" "${tomcat_installer_tomcat_dir}/conf"
    sudo chmod g+rwx "${tomcat_installer_tomcat_dir}/conf"
    sudo chmod g+r "${tomcat_installer_tomcat_dir}/conf/*"
}


function tomcat_installer() {

    declare -A tomcat_installer_options=(
                          ["-c"]="tomcat_installer_config"
                          ["--config"]="tomcat_installer_config"
                          ["-v"]="tomcat_installer_tomcat_version"
                          ["--version"]="tomcat_installer_tomcat_version"
                          ["-u"]="tomcat_installer_tomcat_user"
                          ["--user"]="tomcat_installer_tomcat_user"
                          ["-g"]="tomcat_installer_tomcat_group"
                          ["--group"]="tomcat_installer_tomcat_group"
                          ["-m"]="tomcat_installer_mirror"
                          ["-mirror"]="tomcat_installer_mirror"
                          ["-r"]="tomcat_installer_repo_dir"
                          ["--repo_dir"]="tomcat_installer_repo_dir"
                          ["-t"]="tomcat_installer_target_dir"
                          ["--target"]="tomcat_installer_target_dir"
                         )

    declare -A tomcat_installer_exec_options=(
                          ["-c"]="load_config"
                          ["--config"]="load_config"
                         )

    declare -A tomcat_installer_args

    declare -A tomcat_installer_subcommands=(
                                            ["download"]="tomcat_installer_download"
                                            ["install"]="tomcat_installer_install"
                                            ["uninstall"]="tomcat_installer_uninstall"
                                            ["help"]="tomcat_installer_help"
                                          )

    declare -A tomcat_installer_descriptions=(
                          ["-c"]="tomcat_installer_config"
                          ["--config"]="tomcat_installer_config"
                          ["-v"]="tomcat_installer_tomcat_version"
                          ["--version"]="tomcat_installer_tomcat_version"
                          ["-u"]="tomcat_installer_tomcat_user"
                          ["--user"]="tomcat_installer_tomcat_user"
                          ["-g"]="tomcat_installer_tomcat_group"
                          ["--group"]="tomcat_installer_tomcat_group"
                          ["-m"]="tomcat_installer_mirror"
                          ["-mirror"]="tomcat_installer_mirror"
                          ["-r"]="tomcat_installer_repo_dir"
                          ["--repo_dir"]="tomcat_installer_repo_dir"
                          ["-t"]="tomcat_installer_target_dir"
                          ["--target"]="tomcat_installer_target_dir"
                          ["download"]="Download Apache Tomcat to local repository"
                          ["install"]="Install Apache Tomcat"
                          ["uninstall"]="Remove Apache Tomcat"
                         )

    local optindex
    local -a tomcat_installer_command

    source /dev/stdin <<<"${tomcat_installer_init}"
    load_context

    parse_args tomcat_installer_command \
               optindex \
               tomcat_installer_options \
               tomcat_installer_exec_options \
               tomcat_installer_args \
               tomcat_installer_subcommands \
               tomcat_installer_descriptions \
               "${@}"
    shift "${optindex}"
    [ "${#tomcat_installer_command[@]}" == 0 ] && tomcat_installer_help && return 0

    [ -n "${DEBUG_LOG}" ] && echo_scope

    "${tomcat_installer_command[@]}"

}
