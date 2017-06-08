set -e
set -x


define tomcat_installer_init <<'EOF'
    local tomcat_installer_tomcat_version="${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    local tomcat_installer_tomcat_user="${TOMCAT_INSTALLER_TOMCAT_USER:-${tomcat_installer_tomcat_user:-tomcat}}"
    local tomcat_installer_tomcat_group="${TOMCAT_INSTALLER_TOMCAT_GROUP:-${tomcat_installer_tomcat_group:-tomcat}}"
    local tomcat_installer_tomcat_dir="${TOMCAT_INSTALLER_TOMCAT_DIR:-${tomcat_installer_tomcat_dir:-/opt}}"
EOF

declare -A tomcat_installer_context=(
    ["tomcat_version"]="${TOMCAT_INSTALLER_TOMCAT_VERSION:-${tomcat_installer_tomcat_version:-8.5.15}}"
    ["tomcat_user"]="${TOMCAT_INSTALLER_TOMCAT_USER:-${tomcat_installer_tomcat_user:-tomcat}}"
    ["tomcat_group"]="${TOMCAT_INSTALLER_TOMCAT_GROUP:-${tomcat_installer_tomcat_group:-tomcat}}"
    ["tomcat_dir"]="${TOMCAT_INSTALLER_TOMCAT_DIR:-${tomcat_installer_tomcat_dir:-/opt}}"
    )

function create_tomcat_user() {
    sudo groupadd "${tomcat_installer_tomcat_group}"
    sudo useradd -s /bin/false -g "${tomcat_installer_tomcat_group}" "${tomcat_installer_tomcat_user}"
}

function install_tomcat() {
    target_dir="/opt"
    tomcat_dir="${target_dir}/apache-tomcat-${tomcatVersion}"
    tomcat_tgz="apache-tomcat-${tomcatVersion}.tar.gz"

    wget "http://apache.osuosl.org/tomcat/tomcat-8/v${tomcatVersion}/bin/apache-tomcat-${tomcatVersion}.tar.gz"

    sudo tar -xzf "${tomcat_tgz}" --directory "${target_dir}"
    # sudo chown -R tomcat:tomcat "${tomcat_dir}"

    sudo ln -s "${tomcat_dir}" "${target_dir}/tomcat"
    sudo chown -h tomcat:tomcat "${target_dir}/tomcat"

    # grant permissions to tomcat
    sudo chgrp -R tomcat "${tomcat_dir}/conf"
    sudo chown ec2-user "${tomcat_dir}/conf"
    sudo chmod g+rwx "${tomcat_dir}/conf"
    sudo chmod g+r "${tomcat_dir}/conf/*"
    sudo chown -R tomcat:tomcat "${tomcat_dir}/work/" "${tomcat_dir}/temp/" "${tomcat_dir}/logs/"
    sudo chown root "${tomcat_dir}/conf"
}

create_tomcat_user
install_tomcat
