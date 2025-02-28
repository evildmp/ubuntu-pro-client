#!/bin/bash
set -e

# TODO remove TESTING sections for -proposed verification
# TESTING:
local_deb=$1

function install_old_version {
    name=$1
    series=$2
    old_version=$3
    PACKAGE=ubuntu-advantage-tools
    ARCH=amd64
    echo -e "\n-------------------------------------------"
    echo "** installing $old_version"
    echo "-------------------------------------------"
    package_url=$(curl -s https://launchpad.net/ubuntu/$series/$ARCH/$PACKAGE/$old_version | grep -o "http://launchpadlibrarian.net/.*/${PACKAGE}_${old_version}_${ARCH}.deb")
    lxc exec $name -- wget -nv -O ua.deb $package_url
    lxc exec $name -- dpkg -i ./ua.deb
    lxc exec $name -- apt-cache policy ubuntu-advantage-tools
    echo "-------------------------------------------"
}

function upgrade_to_proposed {
    name=$1
    verify=$2

    # TESTING:
    echo -e "\n-------------------------------------------"
    echo "** upgrading to 27.14 from local - VERIFY $verify"
    echo "-------------------------------------------"
    lxc file push $local_deb $name/tmp/uanew.deb
    lxc exec $name -- dpkg -i /tmp/uanew.deb
    lxc exec $name -- apt-cache policy ubuntu-advantage-tools
    echo "-------------------------------------------"
    return
    # END TESTING

    echo -e "\n-------------------------------------------"
    echo "** upgrading to 27.14 from proposed - VERIFY $verify"
    echo "-------------------------------------------"
    lxc exec $name -- sh -c "echo \"deb http://archive.ubuntu.com/ubuntu $series-proposed main\" | tee /etc/apt/sources.list.d/proposed.list"
    lxc exec $name -- apt-get update > /dev/null
    lxc exec $name -- apt-get install ubuntu-advantage-tools
    lxc exec $name -- apt-cache policy ubuntu-advantage-tools
    echo "-------------------------------------------"
}


function test_normal_upgrade {
    series=$1
    old_version=$2
    echo -e "\n\n###########################################"
    echo "## $series: $old_version -> 27.14: no changes to uaclient.conf"
    echo "###########################################"
    name=$(echo $series-$old_version | tr .~ -)

    echo -e "\n-------------------------------------------"
    echo "** launching container"
    echo "-------------------------------------------"
    lxc launch -q ubuntu-daily:$series $name
    sleep 5
    lxc exec $name -- apt-get update > /dev/null
    lxc exec $name -- apt-get install debsums -y > /dev/null
    echo "-------------------------------------------"

    install_old_version $name $series $old_version

    upgrade_to_proposed $name "NO CONFFILE PROMPT"

    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show no uaclient.conf.dpkg-bak"
    echo "-------------------------------------------"
    lxc exec $name -- sh -c "ls -al  /etc/ubuntu-advantage/uaclient.conf.dpkg-bak || true"
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show user config"
    echo "-------------------------------------------"
    lxc exec $name -- sh -c "ls -al /var/lib/ubuntu-advantage/user-config.json || true"
    lxc exec $name -- pro config show
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** debsums - VERIFY ALL OK"
    echo "-------------------------------------------"
    lxc exec $name -- debsums -e ubuntu-advantage-tools
    echo "-------------------------------------------"

    lxc delete --force $name
    echo "###########################################"
}

function test_apt_news_false_upgrade {
    series=$1
    old_version=$2
    echo -e "\n\n###########################################"
    echo "## $series: $old_version -> 27.14: ua_config changes preserved in new user-config"
    echo "###########################################"
    name=$(echo $series-$old_version | tr .~ -)

    echo -e "\n-------------------------------------------"
    echo "** launching container"
    echo "-------------------------------------------"
    lxc launch -q ubuntu-daily:$series $name
    sleep 5
    lxc exec $name -- apt-get update > /dev/null
    lxc exec $name -- apt-get install debsums -y > /dev/null
    echo "-------------------------------------------"

    install_old_version $name $series $old_version

    echo -e "\n-------------------------------------------"
    echo "** pro config set apt_news=false"
    echo "-------------------------------------------"
    lxc exec $name -- pro config set apt_news=false
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf
    echo "-------------------------------------------"

    upgrade_to_proposed $name "NO CONFFILE PROMPT"

    echo -e "\n-------------------------------------------"
    echo "** Backup file is gone after successful migration"
    echo "-------------------------------------------"
    lxc exec $name -- ls -la /etc/ubuntu-advantage/
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf.dpkg-bak"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf.dpkg-bak
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show user config"
    echo "-------------------------------------------"
    lxc exec $name -- cat /var/lib/ubuntu-advantage/user-config.json
    echo
    lxc exec $name -- pro config show
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** debsums - VERIFY ALL OK"
    echo "-------------------------------------------"
    lxc exec $name -- debsums -e ubuntu-advantage-tools
    echo "-------------------------------------------"

    lxc delete --force $name
    echo "###########################################"
}

function test_uaclient_conf_changes_upgrade {
    series=$1
    old_version=$2
    echo -e "\n\n###########################################"
    echo "## $series: $old_version -> 27.14: preserve uaclient.conf changes"
    echo "###########################################"
    name=$(echo $series-$old_version | tr .~ -)

    echo -e "\n-------------------------------------------"
    echo "** launching container"
    echo "-------------------------------------------"
    lxc launch -q ubuntu-daily:$series $name
    sleep 5
    lxc exec $name -- apt-get update > /dev/null
    echo "-------------------------------------------"

    install_old_version $name $series $old_version

    echo -e "\n-------------------------------------------"
    echo "** make changes to uaclient.conf root"
    echo "-------------------------------------------"
    lxc exec $name -- sed -i "s/debug/warning/" /etc/ubuntu-advantage/uaclient.conf
    lxc exec $name -- sh -c "echo 'features:' >> /etc/ubuntu-advantage/uaclient.conf"
    lxc exec $name -- sh -c "echo '  allow_beta: on' >> /etc/ubuntu-advantage/uaclient.conf"
    lxc exec $name -- sh -c "echo settings_overrides: {} >> /etc/ubuntu-advantage/uaclient.conf"
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show user config"
    echo "-------------------------------------------"
    lxc exec $name -- pro config show
    echo "-------------------------------------------"

    upgrade_to_proposed $name "NO CONFFILE PROMPT"

    echo -e "\n-------------------------------------------"
    echo "** Backup file is gone after successful migration"
    echo "-------------------------------------------"
    lxc exec $name -- ls -la /etc/ubuntu-advantage/
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf.dpkg-bak"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf.dpkg-bak
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show user config"
    echo "-------------------------------------------"
    lxc exec $name -- cat /var/lib/ubuntu-advantage/user-config.json
    echo
    lxc exec $name -- pro config show
    echo "-------------------------------------------"

    lxc delete --force $name
    echo "###########################################"
}

function test_migration_failure {
    series=$1
    old_version=$2
    echo -e "\n\n###########################################"
    echo "## $series: $old_version -> 27.14: migration failure"
    echo "###########################################"
    name=$(echo $series-$old_version | tr .~ -)

    echo -e "\n-------------------------------------------"
    echo "** launching container"
    echo "-------------------------------------------"
    lxc launch -q ubuntu-daily:$series $name
    sleep 5
    lxc exec $name -- apt-get update > /dev/null
    echo "-------------------------------------------"

    install_old_version $name $series $old_version

    echo -e "\n-------------------------------------------"
    echo "** mess up uaclient.conf to be invalid yaml"
    echo "-------------------------------------------"
    lxc exec $name -- sh -c "echo {{{ >> /etc/ubuntu-advantage/uaclient.conf"
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf
    echo "-------------------------------------------"

    upgrade_to_proposed $name "WARNING MESSAGE PRESENT AND NO CONFFILE PROMPT"

    echo -e "\n-------------------------------------------"
    echo "** Backup file is gone"
    echo "-------------------------------------------"
    lxc exec $name -- ls -la /etc/ubuntu-advantage/
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show uaclient.conf - backup was restored"
    echo "-------------------------------------------"
    lxc exec $name -- cat /etc/ubuntu-advantage/uaclient.conf
    echo "-------------------------------------------"
    echo -e "\n-------------------------------------------"
    echo "** Show user config"
    echo "-------------------------------------------"
    lxc exec $name -- sh -c "ls -al /var/lib/ubuntu-advantage/user-config.json || true"
    echo "-------------------------------------------"

    lxc delete --force $name
    echo "###########################################"
}

# xenial
test_normal_upgrade                 xenial 27.11.3~16.04.1
test_normal_upgrade                 xenial 27.13.1~16.04.1
test_apt_news_false_upgrade         xenial 27.11.3~16.04.1
test_apt_news_false_upgrade         xenial 27.13.1~16.04.1
test_uaclient_conf_changes_upgrade  xenial 27.11.3~16.04.1
test_uaclient_conf_changes_upgrade  xenial 27.13.1~16.04.1
test_migration_failure              xenial 27.11.3~16.04.1
test_migration_failure              xenial 27.13.1~16.04.1

# TODO: repeat for each release
