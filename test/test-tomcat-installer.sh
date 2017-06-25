set -e
# set -x

source ../tomcat-installer.sh


function file_clean() {
    source /dev/stdin <<< "${tomcat_installer_init}"

    file_exists /opt/tomcat && sudo rm /opt/tomcat
    dir_exists /opt/apache-tomcat-8.5.15 && sudo rm -rf /opt/apache-tomcat-8.5.15
    dir_exists /opt/repo && sudo rm -rf /opt/repo

    file_exists /etc/sudoers.d/tomcat && sudo rm /etc/sudoers.d/tomcat

    return 0
}

function user_clean() {
    source /dev/stdin <<< "${tomcat_installer_init}"

    user_exists "${tomcat_installer_install_user}" || sudo userdel "${tomcat_installer_install_user}"
    user_exists "${tomcat_installer_tomcat_admin_user}" || sudo userdel "${tomcat_installer_tomcat_admin_user}"
    user_exists "${tomcat_installer_tc_admin_user}" || sudo userdel "${tomcat_installer_tc_admin_user}"
    user_exists "${tomcat_installer_tomcat_service_user}" || sudo userdel "${tomcat_installer_tomcat_service_user}"

    group_exists "${tomcat_installer_tomcat_group}"  || sudo groupdel "${tomcat_installer_tomcat_group}"
    group_exists "${tomcat_installer_install_user}"  || sudo groupdel "${tomcat_installer_install_user}"
    group_exists "${tomcat_installer_tomcat_admin_user}" || sudo groupdel "${tomcat_installer_tomcat_admin_user}"
    group_exists "${tomcat_installer_tc_admin_user}" || sudo groupdel "${tomcat_installer_tc_admin_user}"
    group_exists "${tomcat_installer_tomcat_service_user}" || sudo groupdel "${tomcat_installer_tomcat_service_user}"

    return 0
}


function test_tomcat_installer() {

    source /dev/stdin <<< "${tomcat_installer_init}"

#    tomcat_installer -h
#    tomcat_installer create_users
    tomcat_installer create_folders
    tomcat_installer download_local ~/shared
    tomcat_installer install
    tomcat_installer create_instance /opt/Talend/6.3.1/tac
}

file_clean

#user_clean

test_tomcat_installer
