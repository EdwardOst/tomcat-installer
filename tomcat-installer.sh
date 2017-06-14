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
    local tomcat_installer_install_user="${TOMCAT_INSTALLER_INSTALL_USER:-${tomcat_installer_install_user:-talend}}"
    local tomcat_installer_tomcat_admin_user="${TOMCAT_INSTALLER_TOMCAT_ADMIN_USER:-${tomcat_installer_tomcat_admin_user:-tomcat_admin}}"
    local tomcat_installer_tc_admin_user="${TOMCAT_INSTALLER_TC_ADMIN_USER:-${tomcat_installer_tc_admin_user:-tc_admin}}"
    local tomcat_installer_tomcat_service_user="${TOMCAT_INSTALLER_TOMCAT_SERVICE_USER:-${tomcat_installer_tomcat_service_user:-tomcat}}"
    local tomcat_installer_tomcat_group="${TOMCAT_INSTALLER_TOMCAT_GROUP:-${tomcat_installer_tomcat_group:-tomcat}}"
    local tomcat_installer_repo_dir="${TOMCAT_INSTALLER_REPO_DIR:-${tomcat_installer_repo_dir:-/opt/repo/tomcat}}"
    local tomcat_installer_target_dir="${TOMCAT_INSTALLER_TARGET_DIR:-${tomcat_installer_target_dir:-/opt}}"
    local tomcat_installer_mirror="${TOMCAT_INSTALLER_MIRROR:-${tomcat_installer_mirror:-apache.osuosl.org}}"
    local tomcat_installer_tomcat_dir="${TOMCAT_INSTALLER_TARGET_DIR:-${tomcat_installer_target_dir:-/opt}}/apache-tomcat-${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    local tomcat_installer_tomcat_tgz_file="${TOMCAT_INSTALLER_TOMCAT_TGZ_FILE:-${tomcat_installer_tomcat_tgz_file:-apache-tomcat-${tomcat_installer_tomcat_version}.tar.gz}}"
    local tomcat_installer_umask="${TOMCAT_INSTALLER_UMASK:-${tomcat_installer_umask:-037}}"
EOF

declare -A tomcat_installer_context=(
    ["tomcat_version"]="${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    ["tomcat_installer_user"]="${TOMCAT_INSTALLER_INSTALL_USER:-${tomcat_installer_install_user:-tomcat_installer}}"
    ["tomcat_admin_user"]="${TOMCAT_INSTALLER_TOMCAT_ADMIN_USER:-${tomcat_installer_tomcat_admin_user:-tomcat_admin}}"
    ["tc_admin_user"]="${TOMCAT_INSTALLER_TC_ADMIN_USER:-${tomcat_installer_tc_admin_user:-tc_admin}}"
    ["tomcat_service_user"]="${TOMCAT_INSTALLER_TOMCAT_SERVICE_USER:-${tomcat_installer_tomcat_service_user:-tomcat}}"
    ["tomcat_group"]="${TOMCAT_INSTALLER_TOMCAT_GROUP:-${tomcat_installer_tomcat_group:-tomcat}}"
    ["repo_dir"]="${TOMCAT_INSTALLER_REPO_DIR:-${tomcat_installer_repo_dir:-/opt/repo/tomcat}}"
    ["target_dir"]="${TOMCAT_INSTALLER_TARGET_DIR:-${tomcat_installer_target_dir:-/opt}}"
    ["mirror"]="${TOMCAT_INSTALLER_MIRROR:-${tomcat_installer_mirror:-apache.osuosl.org}}"
    ["tomcat_dir"]="${TOMCAT_INSTALLER_TARGET_DIR:-${tomcat_installer_target_dir:-/opt}}/apache-tomcat-${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    ["tomcat_umask"]="${TOMCAT_INSTALLER_UMASK:-${tomcat_installer_umask:-037}}"
    )
#    ["tomcat_tgz_file"]="${TOMCAT_INSTALLER_TOMCAT_TGZ_FILE:-${tomcat_installer_tomcat_tgz_file:-apache-tomcat-${tomcat_installer_tomcat_version}.tar.gz}}"


function tomcat_installer_help() {
    cat <<-EOF
	install tomcat

	constraints:
	    script must be run with sufficient privileges to do create folders and chown for target directories and files.
	    Directories and files will be created with <tomcat_service_user> and <tomcat_group> configurations.

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
	        tomcat_installer download [-v tomcat_version] [-u tomcat_service_user] [-g tomcat_group] [-r repo_dir]

	    install
	        tomcat_installer install [-r repo_dir] [-t target_dir]

	    uninstall
	        tomcat_installer uninstall [-t target_dir]

	EOF
}


function group_exists() {
    [ "${#}" -lt 1 ] && echo "ERROR: usage: group_exists <group_name>" && return 1
    grep "${1}" /etc/group
    return "${?}"
}


function tomcat_installer_create_users() {

    group_exists "${tomcat_installer_tomcat_group}"  || sudo groupadd "${tomcat_installer_tomcat_group}"
    group_exists "${tomcat_installer_install_user}"  || sudo groupadd "${tomcat_installer_install_user}"
    group_exists "${tomcat_installer_tomcat_admin_user}" || sudo groupadd "${tomcat_installer_tomcat_admin_user}"
    group_exists "${tomcat_installer_tc_admin_user}" || sudo groupadd "${tomcat_installer_tc_admin_user}"

    id -nu "${tomcat_installer_install_user}" || sudo useradd -s /usr/sbin/nologin -g "${tomcat_installer_install_user}" "${tomcat_installer_install_user}"
    id -nu "${tomcat_installer_tomcat_admin_user}" || sudo useradd -s /usr/sbin/nologin -g "${tomcat_installer_tomcat_admin_user}" "${tomcat_installer_tomcat_admin_user}"
    id -nu "${tomcat_installer_tc_admin_user}" || sudo useradd -s /usr/sbin/nologin -g "${tomcat_installer_tc_admin_user}" "${tomcat_installer_tc_admin_user}"
    id -nu "${tomcat_installer_tomcat_service_user}" || sudo useradd -s /usr/sbin/nologin -g "${tomcat_installer_tomcat_service_user}" "${tomcat_installer_tomcat_service_user}"

    # all users belong to tomcat group
    sudo usermod -a -G "${tomcat_installer_tomcat_group}" "${tomcat_installer_install_user}"
    sudo usermod -a -G "${tomcat_installer_tomcat_group}" "${tomcat_installer_tomcat_admin_user}"
    sudo usermod -a -G "${tomcat_installer_tomcat_group}" "${tomcat_installer_tc_admin_user}"

    # install user belongs to all admin groups
    sudo usermod -a -G "${tomcat_installer_tomcat_admin_user}" "${tomcat_installer_install_user}"
    sudo usermod -a -G "${tomcat_installer_tomcat_tc_admin_user}" "${tomcat_installer_install_user}"

    sudo tee -a /etc/sudoers.d/tomcat <<-EOF
	# members of tomcat_admin group can sudo to tomcat_admin user
	%${tomcat_installer_tomcat_admin_user}	ALL=(${tomcat_installer_tomcat_admin_user}) ALL

	# members of tomcat instance admin group can sudo to tomcat instance admin
	%${tomcat_installer_tc_admin_user}	ALL=(${tomcat_installer_tc_admin_user}) ALL

	# members of tomcat installer group can sudo to tomcat admin and tomcat instance admin without a password
	%${tomcat_installer_install_user}	ALL=(${tomcat_installer_tomcat_admin_user},${tomcat_installer_tc_admin_user}) NOPASSWD: ALL
	EOF

}


function tomcat_installer_create_folders() {
    create_user_directory "${tomcat_installer_repo_dir}" "${tomcat_installer_tomcat_admin_user}" "${tomcat_installer_tomcat_group}"
    create_user_directory "${tomcat_installer_tomcat_dir}" "${tomcat_installer_tomcat_admin_user}" "${tomcat_installer_tomcat_group}"

    # create symbolic link to tomcat directory
    if [ ! -e "${tomcat_installer_target_dir}/tomcat" ]; then
        sudo ln -s "${tomcat_installer_tomcat_dir}" "${tomcat_installer_target_dir}/tomcat"
        sudo chown -h "${tomcat_installer_tomcat_admin_user}:${tomcat_installer_tomcat_group}" "${tomcat_installer_target_dir}/tomcat"
    fi
}

function tomcat_installer_download() {
    local tomcat_major_version="${tomcat_installer_tomcat_version:0:1}"
    local tomcat_major_folder="tomcat-${tomcat_major_version}"

    sudo -u "${tomcat_installer_tomcat_admin_user}" \
         wget --no-clobber \
         --directory-prefix="${tomcat_installer_repo_dir}" \
         "http://${tomcat_installer_mirror}/tomcat/${tomcat_major_folder}/v${tomcat_installer_tomcat_version}/bin/${tomcat_installer_tomcat_tgz_file}"

    #chmod -R 740 "${tomcat_installer_repo_dir}"
    #chmod 750 $(find "${tomcat_installer_repo_dir}" -type d)
    #sudo chown -R "${tomcat_installer_tomcat_admin_user}:${tomcat_installer_tomcat_group}" "${tomcat_installer_repo_dir}"
}

function tomcat_installer_install() {

    # catalina_home files should be owned by an administrative user
    # catalina_home files should belong to tomcat group
    # privileges should be rw for the administrative user owner
    # privileges should be ro for the tomcat group
    # privileges should be none for other
    # administrative group members should be allowed to su to adminstrative account
    #
    # catalina_base files should be owned by an instance administrative account
    # catalina_base files should belong to tomcat group
    # privileges should be rw for the instance administrative user owner
    # privileges should be ro for the tomcat group
    # privileges should be none for other
    # instance administrative group members should be allowed to su to instance adminstrative account
    #
    # conf directory is rwx for owner, none for group, and none for other
    # all other directories are rwx for owner, r-x for group, and none for other
    #
    # catalina_base service user will run the service
    # catalina_base service user should belong to the tomcat group since it will need ro access to catalina_home and catalina_base files
    # catalina_base work, temp, and logs directory owned by service user

    # unzip tomcat file
    sudo -u "${tomcat_installer_tomcat_admin_user}" -g "${tomcat_installer_tomcat_group}" \
    tar -xzpf "${tomcat_installer_repo_dir}/${tomcat_installer_tomcat_tgz_file}" --directory "${tomcat_installer_target_dir}"

    # grant permissions on work, temp, and logs to service user
    sudo chown -R "${tomcat_installer_tomcat_service_user}:${tomcat_installer_tomcat_group}" \
                  "${tomcat_installer_tomcat_dir}/work/" \
                  "${tomcat_installer_tomcat_dir}/temp/" \
                  "${tomcat_installer_tomcat_dir}/logs/"

#    debugLog "add tomcat-users for manager"
#    cp -n "${tomcat_installer_base_dir}/conf/tomcat-users.xml" "${tomcat_installer_base_dir}/conf/tomcat-users.xml.orig"
#    cat "${tomcat_installer_base_dir}/conf/tomcat-users.xml.orig" | sed -e "s/^\(<\/tomcat-users>\)//" > "${tomcat_installer_base_dir}/conf/tomcat-users.xml"
#    cat >> "${tomcat_installer_base_dir}/conf/tomcat-users.xml" <<-EOF
#	<user username="tadmin" password="tadmin" roles="manager-gui,admin-gui"/>
#	</tomcat-users>
#	EOF

}


function tomcat_installer_create_instance_folders() {
    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" mkdir "${tomcat_installer_base_dir}/bin"
    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" mkdir "${tomcat_installer_base_dir}/lib"
    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" mkdir "${tomcat_installer_base_dir}/conf"
    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" mkdir "${tomcat_installer_base_dir}/conf/policy.d"
    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" mkdir "${tomcat_installer_base_dir}/webapps"

    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" mkdir "${tomcat_installer_base_dir}/work"
    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" mkdir "${tomcat_installer_base_dir}/temp"
    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" mkdir "${tomcat_installer_base_dir}/logs"
}

export -f tomcat_installer_create_instance_folders


# tomcat_installer_create_instance
#
# create a tomcat instance following catalina_base conventions.
#
function tomcat_installer_create_instance() {

    [ "${#}" -lt 1 ] && echo "ERROR: usage: tomcat_create_instance <base_dir>" && return 1

    local tomcat_installer_base_dir="${1}"

    create_user_directory "${tomcat_installer_base_dir}" \
                          "${tomcat_installer_tc_admin_user}" \
                          "${tomcat_installer_tomcat_group}"

#    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" 
    tomcat_installer_create_instance_folders

    debugLog "copy conf settings"
    sudo -u "${tomcat_installer_tc_admin_user}" -g "${tomcat_installer_tomcat_group}" cp "${tomcat_installer_tomcat_dir}/conf/*" "${tomcat_installer_base_dir}/conf"

    debugLog "set up policy directory with logical link to default policy"
    sudo -u "${tomcat_installer_tc_admin_user}" ln -s "${tomcat_installer_base_dir}/conf/catalina.policy" "${tomcat_installer_base_dir}/conf/policy.d/catalina.policy"
}



function tomcat_installer() {

    declare -A tomcat_installer_options=(
                          ["-c"]="tomcat_installer_config"
                          ["--config"]="tomcat_installer_config"
                          ["-v"]="tomcat_installer_tomcat_version"
                          ["--version"]="tomcat_installer_tomcat_version"
                          ["-u"]="tomcat_installer_tomcat_service_user"
                          ["--user"]="tomcat_installer_tomcat_service_user"
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
                                            ["help"]="tomcat_installer_help"
                                            ["download"]="tomcat_installer_download"
                                            ["create_users"]="tomcat_installer_create_users"
                                            ["create_folders"]="tomcat_installer_create_folders"
                                            ["install"]="tomcat_installer_install"
                                            ["uninstall"]="tomcat_installer_uninstall"
                                            ["create_instance"]="tomcat_installer_create_instance"
                                          )

    declare -A tomcat_installer_descriptions=(
                          ["-c"]="tomcat_installer_config"
                          ["--config"]="tomcat_installer_config"
                          ["-v"]="tomcat_installer_tomcat_version"
                          ["--version"]="tomcat_installer_tomcat_version"
                          ["-u"]="tomcat_installer_tomcat_service_user"
                          ["--user"]="tomcat_installer_tomcat_service_user"
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

    umask "${tomcat_installer_umask}"

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

    "${tomcat_installer_command[@]}" "${@}"

}

