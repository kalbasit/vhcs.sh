#!/usr/bin/env bash
#
#   vim:ft=sh:fenc=UTF-8:ts=4:sts=4:sw=4:expandtab:foldmethod=marker:foldlevel=0:
#
#   This script will assist you on installing VHCS on your system
#
#   This script has been tested on Ubuntu Breezy Badger (5.10), Dapper Drake (6.06),
#   Gutsy Gibbon (7.10), Debian Sarge (3.1) and Debian Etch (4.0).
#
#   Copyright (c) 2005-2008 Wael Nasreddine <wael.nasreddine@sabayonlinux.org>
#   Copyright (c) 2008      Armadillo <armadillo@penguinfriends.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, 
#   USA.
#

### global options ###
VERSION="1.3.1"
wget="/usr/bin/wget"
apt="/usr/bin/apt-get -y --force-yes install"
update="/usr/bin/apt-get update"
upgrade="/usr/bin/apt-get upgrade"
remove="/usr/bin/apt-get remove -y --force-yes"
updateinetd="/usr/sbin/update-inetd"
updatercd="/usr/sbin/update-rc.d"
apache="/etc/init.d/apache2"
a2enmod="/usr/sbin/a2enmod"
dostats="/etc/awstats/dostats"
bind="/etc/init.d/bind9"
clear="/usr/bin/clear"
vhcs_daemon="vhcs2_daemon"
vhcs_network="vhcs2_network"
url="http://wael.nasreddine.com/Projects/vhcs/"
base_dir="/tmp/vhcs_install/"
log="/root/vhcs-log-`date +%s`.txt"
backup_dir="/root/backup/`date +%d-%m-%y-%H-%M`/"
breezy_sources_list="${url}apt_sources/breezy"
dapper_sources_list="${url}apt_sources/dapper"
gutsy_sources_list="${url}apt_sources/gutsy"
amavisd_conf="${url}amavisd.conf"
vhcs2_package="vhcs2-2.4.7.1.tar.bz2"
# Common patches.
patches=( japenese-lang.patch pma-2.11.2.2.patch various-patches.patch )
if [ ! -z "${SF_MIRROR}" ]; then
    sf_mirror="${SF_MIRROR}"
else
    sf_mirror="switch"
fi
vhcs2_inflating_command="tar -xjf"
vhcs2_folder_name="./vhcs2-2.4.7.1"
VHCS_VERSION="2.4.7.1"
tmp_dir="vhcs-2.4.7.1"
if [ "$VHCS_NO_COLORS" != "YES" ]
then
    COLOROFF="\033[1;0m"
    GREENCOLOR="\033[1;32m"
    REDCOLOR="\033[1;31m" 
    LILACCOLOR="\033[1;35m" 
    YELLOWCOLOR="\033[1;33m"
    BLUECOLOR="\033[1;34m"
    WHITECOLOR="\033[1;37m"
    CYANCOLOR="\033[1;36m"
else
    COLOROFF=""
    GREENCOLOR=""
    REDCOLOR=""
    LILACCOLOR=""
    YELLOWCOLOR=""
    BLUECOLOR=""
    WHITECOLOR=""
    CYANCOLOR=""
fi

### exporting Global Variables ###
#export log

### functions ###

handle_interrupt()
{
    ### This function will handle the Ctrl+C Command to restore sources.list and put the color up to normal
    echo -e "${YELLOWCOLOR}Exiting...${COLOROFF}"
    quit_script 1
}

check_errs()
{
  if [ "${1}" -gt "1" ]; then
    echo -e "${REDCOLOR}ERROR # ${1} : ${2}"
    exit ${1}
  fi
}

press_key()
{
    if [ "$VHCS_NO_QUESTIONS" != "YES" ]
    then
        echo -e "${CYANCOLOR}"
        echo -e "Press Enter to continue ${COLOROFF}"
        read enter
    fi
}

# Function copied from Phoenix Linux makepkg script
# Copyright 2006, Wael Nasreddine
isdigit ()
{
    [ $# -eq 1 ] || return 1

    case $1 in
        *[!0-9]*) return 1;;
        *) return 0;;
    esac
}

# Function borrowed and modified from Phoenix Linux makepkg script
# Copyright 2006, Wael Nasreddine
Ppatch() {
    if [ "${#patches[@]}" -eq 0 ]; then
        echo -e "${YELLOWCOLOR}No patches to apply, skipping...${COLOROFF}"
        return 0
    fi
    [ -z "${1}" ] && return 1
    local pdir="${1}"
    local patch
    mkdir -p ${base_dir}/patches
    cd $pdir
    for patch in ${patches[@]}; do
        [ ! -e ${base_dir}/patches/${patch} ] && \
            wget -P ${base_dir}/patches ${url}/patches/${patch}
        # determine how we're gonna apply the patch
        local p=$(echo $patch | sed -e "s@.*\.\(patch\|diff\)\.\([0-9]*\).*@\2@g")
        # make sure the p is a digit
        if ! isdigit "$p"; then
            p=1
        fi
        cmd="patch -Np${p}" 
        echo -e "${YELLOWCOLOR}Applying patch ${patch} using ${cmd} command${BLUECOLOR}"
        ${cmd} --no-backup-if-mismatch -i ${base_dir}/patches/$patch
        echo -e "${COLOROFF}"
    done
}

force_press_key()
{
    echo -e "${CYANCOLOR}"
    echo -e "Press Enter to continue ${COLOROFF}"
    read enter
}

press_key_error()
{
    if [ "$VHCS_NO_QUESTIONS" != "YES" ]
    then
        echo -e "${CYANCOLOR}"
        echo -e "Do you or did you see any errors in the previous task?"
        echo -e "if not it is safe to continue so press Enter"
        echo -e "but if you did/do then you may want to Press Ctrl + C to examen the issue"
        echo -e "but also pressing any key wouldn't harm as if something critical happened the script will halt"
        read enter
    fi
}

print_header()
{
  len=`echo ${header_to_print} | wc -c`
  len=`expr $len - 1`
  prefix="----"
  while [ $len != 0 ]
    do
      prefix="${prefix}-"
      len=`expr $len - 1`
  done
    ${clear}
  echo -e "\t\t\t ${LILACCOLOR}+${prefix}+"${COLOROFF}
  echo -e "\t\t\t ${LILACCOLOR}|${COLOROFF}  ${GREENCOLOR}${header_to_print}${COLOROFF}  ${LILACCOLOR}|${COLOROFF}"
  echo -e "\t\t\t ${LILACCOLOR}+${prefix}+"${COLOROFF}
}

ask_about_clamav_spamassassin()
{
    ### Ask about installing Clamav and Spam Assassin
    ### Thanks to Puuhis
    ### Taken from http://vhcs.net/new/modules/newbb/viewtopic.php?topic_id=3162
    header_to_print="Clamav and Spam Assassin"
    print_header
    echo -e "${CYANCOLOR}Do you want to install Clamav and Spam Assassin? [y/n]"
    read install_clamav_spamassassin
    if [  "${install_clamav_spamassassin}" == "y" ]
    then
        install_clamav_spamassassin
    fi
}

prepare_system()
{
    ### let's see which distribution we are installing on?
    header_to_print="Checking Distribution name"
    print_header
    echo -e "${BLUECOLOR}"
    if cat /etc/issue | grep "Ubuntu 5.10 \"Breezy Badger\"";
    ### Installing on Breezy Badger
    then
        echo -e "${YELLOWCOLOR}Installing on Ubuntu Breezy Badger (5.10)"
        
        ### checking repository
        echo -e "${CYANCOLOR}Have you enabled universe and multiverse repository in sources.list? [y/n]"
        read accept
        if [ "${accept}" == "n" ]
        then
            if ! test -e /etc/apt/sources.list_vhcs_backup
              then
                echo -e "${YELLOWCOLOR}Copying Breezy Badger Sources.list"
                press_key
                echo -e "${BLUECOLOR}"
                if ! test -e ${base_dir}breezy; then ${wget} -P ${base_dir} ${breezy_sources_list}; else echo -e "${YELLOWCOLOR}Sources.list already downloaded, no need to re-download it"; fi
                mv /etc/apt/sources.list /etc/apt/sources.list_vhcs_backup
                cp ${base_dir}breezy /etc/apt/sources.list
            else #the script already been run
                echo -e ""
                echo -e "${YELLOWCOLOR}the Sources.list file already been changed (the script has been ran before?)"
                echo -e "no need to replace the file again"
            fi
        fi
    
        ### defining variables
        install_packages="ssh postfix proftpd-mysql courier-authdaemon courier-base \
                          courier-imap courier-maildrop courier-pop libberkeleydb-perl \
                          libcrypt-blowfish-perl libcrypt-cbc-perl libcrypt-passwdmd5-perl \
                          libdate-calc-perl libdate-manip-perl libdbd-mysql-perl libdbi-perl \
                          libio-stringy-perl libmail-sendmail-perl libmailtools-perl libmd5-perl \
                          libmime-perl libnet-dns-perl libnet-netmask-perl libnet-perl \
                          libnet-smtp-server-perl libperl5.8 libsnmp-session-perl \
                          libterm-readkey-perl libtimedate-perl perl perl-base perl-modules \
                          bind9 diff gzip iptables libmcrypt4 mysql-client-4.1 mysql-common \
                          mysql-server-4.1 patch php4 php4-mcrypt php4-mysql php4-pear procmail \
                          tar original-awk libterm-readpassword-perl libsasl2-modules libsasl2 \
                          sasl2-bin apache2 apache2-common apache2-mpm-prefork libapache2-mod-php4 \
                          bzip2 build-essential php4-gd"
        remove_packages="lpr nfs-common portmap pcmcia-cs pppoe pppoeconf ppp pppconfig apache-common apache"
        patches=( ${patches[@]} )
         
    ### Not on Ubuntu Breezy Badger (5.10)? let's check if its Ubuntu Dapper Drake (6.06)
    elif cat /etc/issue | grep "Ubuntu 6.06";
    ### Installing on Dapper Drake
    then
        echo -e "${YELLOWCOLOR}Installing on Ubuntu Dapper Drake (6.06)"
        
        ### checking repository
        echo -e "${CYANCOLOR}Have you enabled universe and multiverse repository in sources.list? [y/n]"
        read accept
        if [ "${accept}" == "n" ]
        then
            if ! test -e /etc/apt/sources.list_vhcs_backup
              then
                echo -e "${YELLOWCOLOR}Copying Dapper Drake Sources.list"
                press_key
                echo -e "${BLUECOLOR}"
                if ! test -e ${base_dir}dapper; then ${wget} -P ${base_dir} ${dapper_sources_list}; else echo -e "${YELLOWCOLOR}Sources.list already downloaded, no need to re-download it"; fi
                mv /etc/apt/sources.list /etc/apt/sources.list_vhcs_backup
                cp ${base_dir}dapper /etc/apt/sources.list
            else #the script already been run
                echo -e ""
                echo -e "${YELLOWCOLOR}the Sources.list file already been changed (the script has been ran before?)"
                echo -e "no need to replace the file again"
            fi
        fi
    
        ### defining variables
        install_packages="ssh postfix proftpd-mysql courier-authdaemon courier-base courier-imap-ssl \
                          courier-imap courier-maildrop courier-pop libberkeleydb-perl courier-pop-ssl \
                          libcrypt-blowfish-perl libcrypt-cbc-perl libcrypt-passwdmd5-perl \
                          libdate-calc-perl libdate-manip-perl libdbd-mysql-perl libdbi-perl \
                          libio-stringy-perl libmail-sendmail-perl libmailtools-perl libmd5-perl \
                          libmime-perl libnet-dns-perl libnet-netmask-perl libnet-perl \
                          libnet-smtp-server-perl libperl5.8 libsnmp-session-perl \
                          libterm-readkey-perl libtimedate-perl perl perl-base perl-modules \
                          bind9 diff gzip iptables libmcrypt4 mysql-client-4.1 mysql-common \
                          mysql-server-4.1 patch php4 php4-mcrypt php4-mysql php4-pear procmail \
                          tar original-awk libterm-readpassword-perl libsasl2-modules libsasl2 \
                          sasl2-bin apache2 apache2-common apache2-mpm-prefork libapache2-mod-php4 \
                          bzip2 build-essential php4-gd"
        remove_packages="lpr nfs-common portmap pcmcia-cs pppoe pppoeconf ppp pppconfig apache-common apache"
        patches=( ${patches[@]} new-libcrypt-cbc.patch )
    
        
    ### Not on Ubuntu Dapper Drake (6.06)? let's check if its Ubuntu Gutsy Gibbon (7.10)
    elif cat /etc/issue | grep "Ubuntu 7.10";
    ### Installing on Dapper Drake
    then
        echo -e "${YELLOWCOLOR}Installing on Ubuntu Gutsy Gibbon (7.10)"
        
        ### checking repository
        echo -e "${CYANCOLOR}Have you enabled universe and multiverse repository in sources.list? [y/n]"
        read accept
        if [ "${accept}" == "n" ]
        then
            if ! test -e /etc/apt/sources.list_vhcs_backup
              then
                echo -e "${YELLOWCOLOR}Copying Gutsy Gibbon Sources.list"
                press_key
                echo -e "${BLUECOLOR}"
                if ! test -e ${base_dir}gutsy; then ${wget} -P ${base_dir} ${gutsy_sources_list}; else echo -e "${YELLOWCOLOR}Sources.list already downloaded, no need to re-download it"; fi
                mv /etc/apt/sources.list /etc/apt/sources.list_vhcs_backup
                cp ${base_dir}gutsy /etc/apt/sources.list
            else #the script already been run
                echo -e ""
                echo -e "${YELLOWCOLOR}the Sources.list file already been changed (the script has been ran before?)"
                echo -e "no need to replace the file again"
            fi
        fi
    
        ### defining variables
        install_packages="ssh postfix proftpd-mysql courier-authdaemon courier-base courier-imap-ssl \
                          courier-imap courier-maildrop courier-pop libberkeleydb-perl courier-pop-ssl \
                          libcrypt-blowfish-perl libcrypt-cbc-perl libcrypt-passwdmd5-perl \
                          libdate-calc-perl libdate-manip-perl libdbd-mysql-perl libdbi-perl \
                          libio-stringy-perl libmail-sendmail-perl libmailtools-perl libmd5-perl \
                          libmime-perl libnet-dns-perl libnet-netmask-perl \
                          libnet-smtp-server-perl libperl5.8 libsnmp-session-perl \
                          libterm-readkey-perl libtimedate-perl perl perl-base perl-modules \
                          bind9 diff gzip iptables libmcrypt4 mysql-client-5.0 mysql-common \
                          mysql-server-5.0 patch php5 php5-gd php5-mcrypt php5-mysql php-pear procmail \
                          tar original-awk libterm-readpassword-perl libsasl2-modules libsasl2-2 \
                          sasl2-bin apache2 apache2.2-common apache2-mpm-prefork libapache2-mod-php5 \
                          bzip2 build-essential"
        remove_packages="lpr nfs-common portmap pcmcia-cs pppoe pppoeconf ppp pppconfig apache-common apache"
        patches=( ${patches[@]} new-libcrypt-cbc.patch )
        
        echo -e "${YELLOWCOLOR}CAUTION!!! NOW THE SYMLINK OF SH WE'LL BE DELETED AND SET TO THE BASH. IT WILL BE RESETTED AFTER THE INSTALLATION OF VHCS IS COMPLETE!!!"
        
        rm /bin/sh
        
        ln -s /bin/bash /bin/sh
    
    
    ### Not on Ubuntu Gutsy Gibbon (7.10)? let's check if its Debian Sarge (3.1)
    elif cat /etc/issue |grep "Debian GNU/Linux 3.1";
    ### Installing on debian sarge
    then 
        echo -e "${YELLOWCOLOR}Installing on Debian Sarge (3.1)"
        press_key
        
        #echo -e "Copying Sarge Sources.list"
        #echo -e "${BLUECOLOR}"
        #${wget} -P ${base_dir} ${sarge_sources_list}
        #cp /etc/apt/sources.list /etc/apt/sources.list_vhcs_backup
        #cp ${base_dir}sources.list_sarge /etc/apt/sources.list
        
        ### defining variables
        install_packages="ssh postfix postfix-tls proftpd-mysql courier-authdaemon courier-base courier-imap-ssl \
                          courier-imap courier-maildrop courier-pop libberkeleydb-perl courier-pop-ssl \
                          libcrypt-blowfish-perl libcrypt-cbc-perl libcrypt-passwdmd5-perl \
                          libdate-calc-perl libdate-manip-perl libdbd-mysql-perl libdbi-perl \
                          libio-stringy-perl libmail-sendmail-perl libmailtools-perl libmd5-perl \
                          libmime-perl libnet-dns-perl libnet-netmask-perl libnet-perl \
                          libnet-smtp-server-perl libperl5.8 libsnmp-session-perl \
                          libterm-readkey-perl libtimedate-perl perl perl-base perl-modules \
                          bind9 diff gzip iptables libmcrypt4 mysql-client-4.1 mysql-common-4.1 \
                          mysql-server-4.1 patch php4 php4-mcrypt php4-mysql php4-pear procmail \
                          tar original-awk libterm-readpassword-perl libsasl2-modules libsasl2 \
                          sasl2-bin apache2 apache2-common apache2-mpm-prefork libapache2-mod-php4 \
                          bzip2 php4-gd"
        remove_packages="lpr nfs-common portmap pcmcia-cs pppoe pppoeconf ppp pppconfig apache-common apache"
        patches=( ${patches[@]} )

    ### Not on Debian Sarge (3.1)? let's check if its Debian Etch (4.0)
    elif cat /etc/issue |grep "Debian GNU/Linux 4.0";
    ### Installing on Debian Etch
    then 
        echo -e "${YELLOWCOLOR}Installing on Debian Etch (4.0)"
        press_key
        
        #echo -e "Copying Etch Sources.list"
        #echo -e "${BLUECOLOR}"
        #${wget} -P ${base_dir} ${etch_sources_list}
        #cp /etc/apt/sources.list /etc/apt/sources.list_vhcs_backup
        #cp ${base_dir}sources.list_etch /etc/apt/sources.list
        
        ### defining variables
        install_packages="ssh postfix proftpd-mysql courier-authdaemon courier-base courier-imap-ssl\
                          courier-imap courier-maildrop courier-pop courier-pop-ssl libberkeleydb-perl \
                          libcrypt-blowfish-perl libcrypt-cbc-perl libcrypt-passwdmd5-perl \
                          libdate-calc-perl libdate-manip-perl libdbd-mysql-perl libdbi-perl \
                          libio-stringy-perl libmail-sendmail-perl libmailtools-perl libmd5-perl \
                          libmime-perl libnet-dns-perl libnet-netmask-perl \
                          libnet-smtp-server-perl libperl5.8 libsnmp-session-perl \
                          libterm-readkey-perl libtimedate-perl perl perl-base perl-modules \
                          bind9 diff gzip iptables libmcrypt4 mysql-client-5.0 mysql-common \
                          mysql-server-5.0 patch php5 php5-mcrypt php5-mysql php-pear procmail \
                          tar original-awk libterm-readpassword-perl libsasl2-modules libsasl2 \
                          sasl2-bin apache2 apache2.2-common apache2-mpm-prefork libapache2-mod-php5 \
                          bzip2 php5-gd g++ make"
        remove_packages="lpr nfs-common portmap pcmcia-cs pppoe pppoeconf ppp pppconfig apache-common apache"
        patches=( ${patches[@]} new-libcrypt-cbc.patch )

    ### Not on Breezy nor on Debian Sarge nor Debian Etch :o, aborting then
    else echo -e "${YELLOWCOLOR}This distro is not supported by this script. This script is designed for, and will only work on, Ubuntu Breezy Badger (5.10), Ubuntu Dapper Drake (6.06), Debian sarge (3.1) and Debian Etch (4.0)"
    exit 1
    fi
    press_key_error

    ### making Temp directories, going to that directory
    header_to_print="Beginning Installation Now"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "the installation progress can be slow, depends on your connection, to download all required packages"
    echo -e "never press Ctrl + C, never restart your computer..."
    echo -e "please be patient............"
    press_key
    header_to_print="Making Temporary Directories"
    print_header
    press_key
    echo -e "${BLUECOLOR}"
    rm -rf ${base_dir}vhcs_tmp
    echo -e "${YELLOWCOLOR}making ${base_dir}vhcs_tmp/install"
    echo -e "${BLUECOLOR}"
    mkdir -p ${base_dir}vhcs_tmp/install
    press_key_error

    ### let's update the apt repo
    header_to_print="Updating apt cache"
    print_header
    press_key
    echo -e "${BLUECOLOR}"
    ${update}
    check_errs $? "There was an error in apt-get update.${COLOROFF}"
    press_key_error
    
    ### let's upgrade the system
    header_to_print="Upgrading the system"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "During this step the system will be updated, it will ask you to continue or not, most users want to continue at this step, but for some reasons you may want to skip this step (preserve current kernel, etc..."
    echo -e "You have the choice to continue or to skip it"
    press_key
    echo -e "${BLUECOLOR}"
    ${upgrade}
    check_errs $? "There was an error in apt-get upgrade.${COLOROFF}"
    press_key_error

    ### let's remove unneeded packages
    header_to_print="Removing Uneeded Packages"
    print_header
    press_key
    echo -e "${YELLOWCOLOR}removing unneeded packages..."
    echo -e "${BLUECOLOR}"
    ${remove} ${remove_packages}
    check_errs $? "There was an error removing uneeded packages.${COLOROFF}"
    press_key_error

    ### let's update-inetd
    header_to_print="Removing Some Packages from startup if they exist"
    print_header
    press_key
    echo -e "${YELLOWCOLOR}Removing daytime..."
    echo -e "${BLUECOLOR}"
    ${updateinetd} --remove daytime
    echo -e "${YELLOWCOLOR}Removing telnet..."
    echo -e "${BLUECOLOR}"
    ${updateinetd} --remove telnet
    echo -e "${YELLOWCOLOR}Removing time..."
    echo -e "${BLUECOLOR}"
    ${updateinetd} --remove time
    echo -e "${YELLOWCOLOR}Removing finger..."
    echo -e "${BLUECOLOR}"
    ${updateinetd} --remove finger
    echo -e "${YELLOWCOLOR}Removing talk..."
    echo -e "${BLUECOLOR}"
    ${updateinetd} --remove talk
    echo -e "${YELLOWCOLOR}Removing ntalk..."
    echo -e "${BLUECOLOR}"
    ${updateinetd} --remove ntalk
    echo -e "${YELLOWCOLOR}Removing ftp..."
    echo -e "${BLUECOLOR}"
    ${updateinetd} --remove ftp
    echo -e "${YELLOWCOLOR}Removing discard"
    echo -e "${BLUECOLOR}"
    ${updateinetd} --remove discard
    check_errs $? "There was an error updating inetd.${COLOROFF}"
    press_key_error

    ### let's install required packages
    header_to_print="Installing Required Packages"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "Read the below text carefully, I advise you to note them down on a piece of paper"
    echo -e "${REDCOLOR}"
    echo -e "When you get to the Courier screen, select no to web directories."
    echo -e "When you get to the Postfix screen, select internet site and then type root for mail if asked. If you setup correctly your distribution on install, your domain should be already on screen. Select no to force sync updates if asked, select standalone."
    echo -e "When you get to the ProFTPd screen, Select Standalone."
    echo -e "${COLOROFF}"
    force_press_key
    echo -e "${BLUECOLOR}"
    ${apt} ${install_packages} 
    check_errs $? "There was an error installing required packages.${COLOROFF}"
    press_key_error
}

install_vhcs()
{
    ### Downloading VHCS
    header_to_print="Downloading VHCS2 Archive"
    print_header
    press_key
    echo -e "${BLUECOLOR}"
    if ! test -e ${base_dir}${vhcs2_package}; then ${wget} -P  ${base_dir} http://${sf_mirror}.dl.sourceforge.net/sourceforge/vhcs/${vhcs2_package}; else echo -e "${YELLOWCOLOR}VHCS already downloaded"; fi
    press_key_error
    

    ### Untaring VHCS
    header_to_print="Untaring VHCS Archive"
    print_header
    press_key
    echo -e "${BLUECOLOR}"
    ${vhcs2_inflating_command} ${base_dir}${vhcs2_package} -C ${base_dir}vhcs_tmp/install

    ### Applying patches
    Ppatch "${base_dir}vhcs_tmp/install/${vhcs2_folder_name}"

    check_errs $? "There was an error making directories, getting tarball and inflating it.${COLOROFF}"
    press_key_error

    ### let's install VHCS and put it in place
    header_to_print="Compiling/Installing VHCS2"
    print_header
    press_key
    echo -e "${BLUECOLOR}"
    {
        cd ${base_dir}vhcs_tmp/install/${vhcs2_folder_name}
        make install
    }
    
    cp -R /tmp/${tmp_dir}/etc/* /etc
    cp -R /tmp/${tmp_dir}/var/* /var
    cp -R /tmp/${tmp_dir}/usr/* /usr
    check_errs $? "There was an error installing VHCS.${COLOROFF}"
    press_key_error
    
    ### let's change mysql password
    header_to_print="Setting up Mysql Password"
    print_header
    echo -e "${CYANCOLOR}Do you want to change the mysql root password? [y/n]"
    read change_mysql_pass
    if [  ${change_mysql_pass} = y ]
    ### Let's change the password then
    then
        echo -e "${YELLOWCOLOR}We will change MySQL root password please enter password (use only alpha-numeric characters)"
        read pass
        ${clear}
        echo -e "please enter your old password"
        echo -e "If you have not changed your MySQL password outside this script, just hit enter."
        echo -e "${BLUECOLOR}"
        mysqladmin -u root -p password ${pass}
        press_key_error
        check_errs $? "There was an error changing the password.${COLOROFF}"
    ### Password Changing aborted
    else
        echo -e "${YELLOWCOLOR}ignoring mysql root password changing..."
        press_key
    fi
    
    ### let's run VHCS install engine
    header_to_print="Running VHCS Install Engine"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "I will run vhcs2-setup now..."
    echo -e "please fill the required information..."
    press_key
    echo -e "${BLUECOLOR}"
    /var/www/vhcs2/engine/setup/vhcs2-setup
    check_errs $? "There was an error installing VHCS.${COLOROFF}"
    press_key_error
    
    ### let's write some configuration entries
    header_to_print="Write Configuration Files"
    print_header
    press_key
    echo -e "${BLUECOLOR}"
    
    if [ -f "/etc/php4/apache2/php.ini" ]
        then
        echo -e "Detected PHP4... patching php.ini"
        if ! cat /etc/php4/apache2/php.ini | grep "extension=mcrypt.so"; then echo -e "extension=mcrypt.so" >> /etc/php4/apache2/php.ini; fi
        if ! cat /etc/php4/apache2/php.ini | grep "extension=mysql.so"; then echo -e "extension=mysql.so" >> /etc/php4/apache2/php.ini; fi
    elif [ -f "/etc/php5/apache2/php.ini" ]
        then
        echo -e "Detected PHP5... patching php.ini"
        if ! cat /etc/php5/apache2/php.ini | grep "extension=mcrypt.so"; then echo -e "extension=mcrypt.so" >> /etc/php5/apache2/php.ini; fi
        if ! cat /etc/php5/apache2/php.ini | grep "extension=mysql.so"; then echo -e "extension=mysql.so" >> /etc/php5/apache2/php.ini; fi
    fi
    
    # Not needed with VHCS >= 2.6.4.2
    #if ! cat /etc/apache2/httpd.conf | grep "Include /etc/apache2/sites-available/vhcs2.conf"; then echo -e "Include /etc/apache2/sites-available/vhcs2.conf" >> /etc/apache2/httpd.conf; fi
    check_errs $? "There was an error writing some configuration entries.${COLOROFF}"
    press_key_error
    
    ### let's restart apache
    header_to_print="Restarting Apache"
    print_header
    press_key
    echo -e "${BLUECOLOR}"
    restart_apache
    
    if grep "Debian GNU/Linux 4.0" /etc/issue || grep "Debian GNU/Linux 3.1" /etc/issue || grep "Ubuntu 6.06" /etc/issue || grep "Ubuntu 7.10" /etc/issue;
        then
        ### copying proftpd.conf to /etc/proftpd/
        echo -e "${BLUECOLOR}"
        echo -e "Copying proftpd.conf to \"/etc/proftpd/\""
        cp /etc/proftpd.conf /etc/proftpd/proftpd.conf
        echo -e "Restarting ProFTPd..."
        /etc/init.d/proftpd restart
        echo -e "${REDCOLOR}CAUTION!!! Please check MANUALLY AFTER THE INSTALLATION if the {HOST_NAME} on line 6 and {DATABASE_NAME}, {DATABASE_HOST}, {DATABASE_USER}, {DATABASE_PASS} on line 117 in /etc/proftpd/proftpd.conf have successfully been replaced by the VHCS-Setup. If not, replace them with the correct entries you entered at the beginning auf the VHCS-Setup and restart Proftpd!"
    fi
    
    if grep "Ubuntu 7.10" /etc/issue;
        then
        echo -e "${YELLOWCOLOR}THE SYMLINK OF SH WILL NOW BE SET BACK TO THE _DASH_!!!"
        mv /bin/sh /bin/sh.old
        
        ln -s /bin/dash /bin/sh
    fi
    
    check_errs $? "There was an error restarting apache.${COLOROFF}"
    press_key_error

    ### finally let's make services runnable at boot
    header_to_print="Adding Daemon to rc*.d"
    print_header
    press_key
    echo -e "${BLUECOLOR}"
    ${updatercd} ${vhcs_daemon} defaults
    ${updatercd} ${vhcs_network} defaults
    check_errs $? "There was an error updating rc.d.${COLOROFF}"
    press_key_error

    ### restoring user sources.list
    header_to_print="Restoring user's source.list"
    print_header
    press_key
    if test -e /etc/apt/sources.list_vhcs_backup
    then
        echo -e "${BLUECOLOR}"
        mv /etc/apt/sources.list_vhcs_backup /etc/apt/sources.list
        ${update}
    fi
    check_errs $? "There was an error restoring user's sources.list${COLOROFF}"
    press_key_error

    ### Done
    header_to_print="Congratulations"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "Congratulations, VHCS installation is done."
    echo -e "Visit http://127.0.0.1/vhcs2/ if you got vhcs page then everything was correct."
    echo -e "if not, please email us with the details at wael.nasreddine@sabayonlinux.org or armadillo@penguinfriends.org"
    echo -e ""
    echo -e "Visit ${url} for more information and for Tips & Tricks"
  press_key
    
    ### Let's go back to the Main Menu
    main_menu
}

install_clamav_spamassassin()
{
    header_to_print="Clamav and Spam Assassin Installation"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "Clamav and Spam Assassin are Anti virus and spam killer that will be integrated"
    echo -e "with postfix, so users will never receive mails with virus, and Spam mails will be"
    echo -e "Prefixed with ***SPAM***"
    echo -e ""
    echo -e "${CYANCOLOR}This will Install Clamav and Spam Assassin, continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then

        ### Let's Install it :D
        header_to_print="Clamav and Spam Assassin Installation"
        print_header
        echo -e "${YELLOWCOLOR}"
        echo -e "I will install Clamav and Spam Assassin for you"
        echo -e "You may want to visit the topic about this subject on vhcs.net located at:"
        echo -e "http://vhcs.net/new/modules/newbb/viewtopic.php?topic_id=3162"
        press_key
        echo -e "${BLUECOLOR}"
        ${apt} clamav clamav-daemon amavisd-new spamassassin
        if ! test -e ${base_dir}${amavisd_conf}; then ${wget} -P ${base_dir} ${amavisd_conf}; else echo -e "amavisd.conf already downloaded, no need to re-download it"; fi
        cp ${base_dir}amavisd.conf /etc/amavis/amavisd.conf
        mkdir /var/mail/virus
        chown -R amavis:amavis /var/mail/virus
        gpasswd -a clamav amavis
        /etc/init.d/clamav-daemon restart
        /etc/init.d/amavis restart
        if ! cat /etc/postfix/main.cf | grep "#added for clamav and spamassassin by vhcs installation script made by Wael Nasreddine"
        then
            echo "#added for clamav and spamassassin by vhcs installation script made by Wael Nasreddine" >> /etc/postfix/main.cf
            echo "content_filter = smtp-amavis:[127.0.0.1]:10024" >> /etc/postfix/main.cf
        fi
    
        if ! cat /etc/vhcs2/postfix/main.cf  | grep "#added for clamav and spamassassin by vhcs installation script made by Wael Nasreddine"
        then
            echo "#added for clamav and spamassassin by vhcs installation script made by Wael Nasreddine" >> /etc/vhcs2/postfix/main.cf 
            echo "content_filter = smtp-amavis:[127.0.0.1]:10024" >> /etc/vhcs2/postfix/main.cf
        fi
    
        if ! cat /etc/postfix/master.cf | grep "#added for clamav and spamassassin by vhcs installation script made by Wael Nasreddine"
        then
            echo "#added for clamav and spamassassin by vhcs installation script made by Wael Nasreddine" >> /etc/postfix/master.cf
            echo "smtp-amavis unix -      -       n     -       2  smtp" >> /etc/postfix/master.cf
            echo "    -o smtp_data_done_timeout=1200" >> /etc/postfix/master.cf
            echo "    -o smtp_send_xforward_command=yes" >> /etc/postfix/master.cf
            echo "    -o disable_dns_lookups=yes" >> /etc/postfix/master.cf
            echo "localhost:10025 inet    n       -       n       -       -       smtpd -o content_filter= -o mynetworks=127.0.0.0/8 -o smtpd_recipient_restrictions=permit_mynetworks,reject" >> /etc/postfix/master.cf
        fi
        
        if ! cat /etc/vhcs2/postfix/master.cf | grep "#added for clamav and spamassassin by vhcs installation script made by Wael Nasreddine"
        then
            echo "#added for clamav and spamassassin by vhcs installation script made by Wael Nasreddine" >> /etc/vhcs2/postfix/master.cf
            echo "smtp-amavis unix -      -       n     -       2  smtp" >> /etc/vhcs2/postfix/master.cf
            echo "    -o smtp_data_done_timeout=1200" >> /etc/vhcs2/postfix/master.cf
            echo "    -o smtp_send_xforward_command=yes" >> /etc/vhcs2/postfix/master.cf
            echo "    -o disable_dns_lookups=yes" >> /etc/vhcs2/postfix/master.cf
            echo "localhost:10025 inet    n       -       n       -       -       smtpd -o content_filter= -o mynetworks=127.0.0.0/8 -o smtpd_recipient_restrictions=permit_mynetworks,reject" >> /etc/vhcs2/postfix/master.cf
        fi
        /etc/init.d/postfix restart
    
        ### Checking sources.list entry
        if ! cat /etc/apt/sources.list | grep "deb http://ftp2.de.debian.org/debian-volatile sarge/volatile main" && cat /etc/issue |grep "Debian GNU/Linux 3.1"
        then
            echo "#added for ClamAV and Spamassassin by vhcs installation script made by Armadillo" >> /etc/apt/sources.list
            echo "deb http://ftp2.de.debian.org/debian-volatile sarge/volatile main" >> /etc/apt/sources.list
            ${update}
        elif ! cat /etc/apt/sources.list | grep "deb http://ftp2.de.debian.org/debian-volatile etch/volatile main" && cat /etc/issue |grep "Debian GNU/Linux 4.0"
        then
            echo "#added for ClamAV and Spamassassin by vhcs installation script made by Armadillo" >> /etc/apt/sources.list
            echo "deb http://ftp2.de.debian.org/debian-volatile sarge/volatile main" >> /etc/apt/sources.list
            ${update}
        fi
    
        press_key_error
        
        ### Done
        header_to_print="Congratulations"
        print_header
        echo -e "${YELLOWCOLOR}"
        echo -e "Congratulations, Clamav and Spam Assassin Successfully Installed."
        echo -e ""
        echo -e "Visit ${url} for more information and for Tips & Tricks"
        press_key
    
        ### Let's go back to the Hacks Menu
        hacks_menu
    elif [ "$continue_or_not" == "n" ]
    then
        hacks_menu
    else # None selected
        install_clamav_spamassassin
    fi
}

vhcs()
{
    prepare_system
    install_vhcs
}

main_menu()
{
    ### Let's see what our precious user wants to do ###
    header_to_print="Main Menu"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "Please Choose what to install"
    echo -e "Note: Whatever you choose to install either from here or on the hacks menu, you will get back here when it's done"
    echo -e "${CYANCOLOR}"
    echo -e "1) VHCS ${VHCS_VERSION}"
    echo -e "2) Update VHCS 2.4.7 -> 2.4.7.1"
    echo -e ""
    echo -e "Type m To Go to the Hacks Menu"
    echo -e "Type q to Quit the script"
    read install_option
    if [ "$install_option" == "q" ]
    then
        quit_script
    elif [ "$install_option" == "1" ]
    then
        vhcs
    elif [ "$install_option" == "2" ]
    then
        vhcs_2_4_7__2_4_7_1
    elif [ "$install_option" == "m" ]
    then
        hacks_menu
    else # None Selected
        main_menu
    fi
}
vhcs_2_4_7__2_4_7_1()
{
    header_to_print="Update VHCS 2.4.7 to 2.4.7.1"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "This will update your VHCS 2.4.7 to VHCS 2.4.7.1"
    echo -e "${CYANCOLOR}Do you want to continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then
        # Backuping files
        echo -e "${YELLOWCOLOR}Creating Backup Files ...${BLUECOLOR}"
        if ! test -e ${backup_dir}.dont_detele; then touch ${backup_dir}.dont_delete;fi
        temp_dir="${backup_dir}vhcs_2.4.7_to_vhcs_2.4.7.1/"
        mkdir -p ${temp_dir}
        cp /etc/vhcs2/vhcs2.conf ${temp_dir}
        cp /etc/postfix/master.cf ${temp_dir}
        #Move files/directories that needs to be deleted/replaced
        mv /var/www/vhcs2/gui ${temp_dir}
        mv /var/www/vhcs2/engine ${temp_dir}
        mv /etc/vhcs2/postfix/working/aliases ${temp_dir}
        mv /var/www/vhcs2/engine/setup/vhcs2-cfg-subst ${temp_dir}
    
        # Let's begin the update process now
        echo -e "${YELLOWCOLOR}Stoping VHCS2 Daemon ... ${BLUECOLOR}$(/etc/init.d/vhcs2_daemon stop)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/vhcs2.conf ... ${BLUECOLOR}$(sed -i -e "s/.*BuildDate =.*/BuildDate = 03.01.2006/g" -e "s/.*Version =.*/Version = 2.4.7.1/g" -e "s/.*VHCS_LICENSE =.*/VHCS_LICENSE = VHCS<sup>\&reg;<\/sup> Pro v2.4.7.1<br>build: 2006-01-03<br>Spartacus/g" /etc/vhcs2/vhcs2.conf)${YELLOWCOLOR} Done ..."
        echo -e "${YELLOWCOLOR}Patching /etc/postfix/master.cf ... ${BLUECOLOR}$(sed -i -e "s/\(.*vhcs2-arpl unix.*pipe\) flags=D/\1 flags=O/g" /etc/postfix/master.cf)${YELLOWCOLOR} Done ..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/crontab/working/crontab.conf ... ${BLUECOLOR}$(sed -i -e "s/\(.*\)\/var\/www\/vhcs2\/engine\/tools\/vhcs2-backup-all yes\(.*\)/\1\/var\/www\/vhcs2\/engine\/backup\/vhcs2-backup-all yes\2/g" /etc/vhcs2/crontab/working/crontab.conf)${YELLOWCOLOR} Done ..."
        echo -e "${YELLOWCOLOR}Adding new Crontab ... ${BLUECOLOR}$(crontab /etc/vhcs2/crontab/working/crontab.conf)${YELLOWCOLOR} Done..."

        if ! test -e ${base_dir}${vhcs2_package}; then ${wget} -P  ${base_dir} http://${sf_mirror}.dl.sourceforge.net/sourceforge/vhcs/${vhcs2_package}; else echo -e "${YELLOWCOLOR}VHCS already downloaded"; fi
        if ! test -e ${base_dir}2_4_7__2_4_7_1; then ${wget} -P ${base_dir} ${url}2_4_7__2_4_7_1; fi
        echo -e "${YELLOWCOLOR}Untaring VHCS Archive...${BLUECOLOR}"
        ${vhcs2_inflating_command} ${base_dir}${vhcs2_package} -C ${base_dir}
        cp -a ${base_dir}${vhcs2_folder_name}/engine/ /var/www/vhcs2/
        cp -a ${base_dir}${vhcs2_folder_name}/gui/ /var/www/vhcs2/
        cp ${temp_dir}engine/vhcs2-db-keys.pl /var/www/vhcs2/engine/vhcs2-db-keys.pl
        cp ${temp_dir}engine/vhcs2-db-keys.pl /var/www/vhcs2/engine/messager/vhcs2-db-keys.pl
        cp ${temp_dir}gui/include/vhcs2-db-keys.php /var/www/vhcs2/gui/include/vhcs2-db-keys.php
        # Finishing gui/engine update by setting correct permissions
        /var/www/vhcs2/engine/setup/set-engine-permissions.sh
        /var/www/vhcs2/engine/setup/set-gui-permissions.sh
        ask_mysql_pass
        echo -e "${YELLOWCOLOR}Adding new language files to the database ... ${BLUECOLOR}"
        mysql -u root --password="${mysql_password}" vhcs2 < ${base_dir}${vhcs2_folder_name}/configs/database/languages.sql
        echo -e "${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Putting mails in change state ... ${BLUECOLOR}"
        mysql -u root --password="${mysql_password}" < ${base_dir}2_4_7__2_4_7_1
        echo -e "${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Running /var/www/vhcs2/engine/vhcs2-rqst-mngr ... ${BLUECOLOR}$(/var/www/vhcs2/engine/vhcs2-rqst-mngr)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Starting VHCS2 Daemon ... ${BLUECOLOR}$(/etc/init.d/vhcs2_daemon start)${YELLOWCOLOR} Done..."
        press_key_error
        ### Done
        header_to_print="Congratulations"
        print_header
        echo -e "${YELLOWCOLOR}"
        echo -e "Congratulations, VHCS has been succesfully updated to 2.4.7.1 from 2.4.7."
        echo -e "a Backup of all replaced/Changed files can be found at ${temp_dir}"
        echo -e "Visit http://127.0.0.1/vhcs2/ if you got vhcs page then everything was correct."
        echo -e "if not, please email us with the details at wael.nasreddine@sabayonlinux.org or armadillo@penguinfriends.org"
        echo -e ""
        echo -e "Visit ${url} for more information and for Tips & Tricks"
      press_key
    
        ### Let's go back to the Main Menu
        main_menu
    elif [ "$continue_or_not" == "n" ]
    then
        main_menu
    else # None selected
        vhcs_2_4_7__2_4_7_1
    fi
}


    
 
hacks_menu()
{
    ### Let's see what our precious user wants to do ###
    header_to_print="Hacks Menu"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "Please Choose what to install, to get info about the hack please select it"
    echo -e "${REDCOLOR}Note: If you don't have VHCS installed then DO NOT use any of the below Hacks, go back to the main menu and install VHCS first"
    echo -e "The below hacks are taken from http://vhcs.puuhis.net/index.php/Hacks"
    echo -e "I am not responsible for any mess caused by the below hacks, you have been warned!!!"
    echo -e "${CYANCOLOR}"
    echo -e "1) Clamav and Spam Assassin"
    echo -e "2) Install and integrate Awstats"
    echo -e "3) Activate/Desactivate Copying User Logs"
    echo -e "4) Add SPF Record"
    echo -e "5) Temporary address to domains"
    echo -e "6) Activate/Desactivate Debug mode"
    echo -e ""
    echo -e "Type m to Go back to the Main Menu"
    echo -e "Type q to Quit the script"
    read install_option
    if [ "$install_option" == "q" ]
    then
        quit_script
    elif [ "$install_option" == "1" ]
    then
        install_clamav_spamassassin
    elif [ "$install_option" == "2" ]
    then
        install_awstats
    elif [ "$install_option" == "3" ]
    then
        activate_desactivate_logs_copying
    elif [ "$install_option" == "4" ]
    then
        add_spf_record
    elif [ "$install_option" == "5" ]
    then
        temporary_address_to_domains
    elif [ "$install_option" == "6" ]
    then
        activate_desactivate_debug_mode
    elif [ "$install_option" == "m" ]
    then
        main_menu
    else # None Selected
        hacks_menu
    fi
}

install_awstats()
{
    header_to_print="Install and Integrate Awstats"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "This hack will Install and integrate awstats with vhcs2, you can view statistics using www.yourmaindmain.tld/stats/"
    echo -e "${CYANCOLOR}Do you want to continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then
        # Backuping files
        echo -e "${YELLOWCOLOR}Creating Backup Files ...${BLUECOLOR}"
        if ! test -e ${backup_dir}.dont_detele; then touch ${backup_dir}.dont_delete;fi
        temp_dir="${backup_dir}awstats_hack/"
        mkdir -p ${temp_dir}
        cp /etc/vhcs2/apache/parts/dmn_entry.tpl ${temp_dir}
        cp /etc/vhcs2/apache/parts/als_entry.tpl ${temp_dir}
        cp /etc/apache2/sites-available/vhcs2.conf ${temp_dir}
        cp /etc/vhcs2/crontab/crontab.conf ${temp_dir}
        
        # Applying the hack
        ${apt} awstats libapache2-mod-auth-mysql
        ${a2enmod} auth_mysql
        if ! test -e ${base_dir}awstats.model.conf; then ${wget} -P ${base_dir} ${url}awstats.model.conf; fi
        cp ${base_dir}awstats.model.conf /etc/awstats
        if ! test -e ${base_dir}dostats; then ${wget} -P ${base_dir} ${url}dostats; fi
        cp ${base_dir}dostats /etc/awstats
        chmod 755 /etc/awstats/dostats
        cp /usr/share/doc/awstats/examples/awstats_updateall.pl /usr/sbin/awstats_updateall.pl
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/dmn_entry.tpl ... ${BLUECOLOR}$(sed -i -e "s/\(.*Alias \/errors.*\)/\1\n    Redirect \/stats http:\/\/{DMN_NAME}\/awstats\/awstats.pl/g" /etc/vhcs2/apache/parts/dmn_entry.tpl)${YELLOWCOLOR} Done ..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/als_entry.tpl ... ${BLUECOLOR}$(sed -i -e "s/\(.*Alias \/errors.*\)/\1\n    Redirect \/stats http:\/\/{DMN_NAME}\/awstats\/awstats.pl/g" /etc/vhcs2/apache/parts/als_entry.tpl)${YELLOWCOLOR} Done ..."
        echo -e "${YELLOWCOLOR}Patching /etc/apache2/sites-available/vhcs2.conf ... ${BLUECOLOR}$(sed -i -e "s/\(# Default GUI\)/# awstats modifications\n#\n\nAlias \/awstatscss \"\/usr\/share\/doc\/awstats\/examples\/css\/\"\nAlias \/awstats-icon \"\/usr\/share\/awstats\/icon\/\"\nAlias \/awstatsicons \"\/usr\/share\/awstats\/icon\/\"\nScriptAlias \/awstats\/ \"\/usr\/lib\/cgi-bin\/\"\n\n<Directory \/usr\/share\/awstats>\nOptions None\nAllowOverride None\nOrder allow,deny\nAllow from all\n<\/Directory>\n\n<Directory \/usr\/lib\/cgi-bin>\nOptions None\nAllowOverride AuthConfig\nOrder allow,deny\nAllow from all\n<\/Directory>\n\n#\n\1/g" /etc/apache2/sites-available/vhcs2.conf)${YELLOWCOLOR} Done ..."
        echo -e "${BLUECOLOR}"
        cp /etc/apache2/sites-available/vhcs2.conf /etc/vhcs2/apache/working/
        if ! test -e ${base_dir}vhcs2_awstats; then ${wget} -P ${base_dir} ${url}vhcs2_awstats; fi
        regenerate_configs    
        mysql -u root --password="${mysql_password}" < ${base_dir}vhcs2_awstats
        if ! test -e /usr/lib/cgi-bin/.htaccess
        then
            touch /usr/lib/cgi-bin/.htaccess
        else
            echo "" >> /usr/lib/cgi-bin/.htaccess
        fi
        echo -e "AuthName                        \"AWStats\"\nAuthType                        Basic\nAuthMySQL_Host                  localhost\nAuthMySQL_DB                    vhcs2\nAuthMySQL_Password_Table        admin\nAuthMySQL_User                  vhcs2_awstats\nAuthMySQL_Password              vhcs2\nAuthMySQL_Username_Field        admin_name\nAuthMySQL_Password_Field        admin_pass\nAuthMySQL_Encryption_Types      Crypt_DES Crypt_MD5 Crypt MySQL PHP_MD5\nrequire valid-user" >> /usr/lib/cgi-bin/.htaccess

        #Patching crontab
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/crontab/working/crontab.conf ...${BLUECOLOR}$(sed -i -e "s/\(.*backup task START.*\)/0 4 * * * \/etc\/awstats\/dostats \&> \/var\/log\/vhcs2\/vhcs2-awstats.log\n\n\1/g" /etc/vhcs2/crontab/working/crontab.conf)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Adding new Crontab ... ${BLUECOLOR}$(crontab /etc/vhcs2/crontab/working/crontab.conf)${YELLOWCOLOR} Done..."

        #restart apache
        restart_apache

        #running dostats
        ${dostats}

        echo -e "${YELLOWCOLOR}Successfully Applied"
        echo -e "Visit http://www.yourdomain.com/stats/ for statistics"
        echo -e "a backup if the patched files has been created under ${temp_dir}"
        press_key_error
        hacks_menu
    elif [ "$continue_or_not" == "n" ]
    then
        hacks_menu
    else # None selected
        install_awstats
    fi
}

temporary_address_to_domains()
{
    header_to_print="Temporary Address To Domains"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "This hack will enable temporary access to domains using www.yourmaindmain.tld/~domain.tld"
    echo -e "${CYANCOLOR}Do you want to continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then
        # Backuping files
        echo -e "${YELLOWCOLOR}Creating Backup Files ...${BLUECOLOR}"
        if ! test -e ${backup_dir}.dont_detele; then touch ${backup_dir}.dont_delete;fi
        temp_dir="${backup_dir}temporary_access_hack/"
        mkdir -p ${temp_dir}
        cp /etc/apache2/mods-available/userdir.conf    ${temp_dir}

        # Applying the hack
        echo -e "${BLUECOLOR}"
        rm /etc/apache2/mods-available/userdir.conf
        rm /etc/apache2/mods-enabled/userdir.*

        echo -e "${CYANCOLOR}Please enter your IP Address"
        read ip_address
        echo -e "${CYANCOLOR}Please enter your main domain in format domain.tld"
        echo -e "${REDCOLOR}NOTE: You must enter your domain as domain.tld do not include www nor any sub-domain, please only domain.tld${CYANCOLOR}"
        read main_domain
        echo -e "${BLUECOLOR}"
        if ! test -e ${base_dir}userdir_conf; then ${wget} -P ${base_dir} ${url}userdir_conf; fi
        sed -i -e "s/IP_ADDRESS/${ip_address}/g" -e "s/DOMAIN_NAME/${main_domain}/g" ${base_dir}userdir_conf
        cp ${base_dir}userdir_conf /etc/apache2/mods-available/userdir.conf
        ln -s /etc/apache2/mods-available/userdir.* /etc/apache2/mods-enabled/
        if ! cat /var/cache/bind/${main_domain}.db | grep "users.${main_domain}"
        then
            # Patching main domain now
            cp /var/cache/bind/${main_domain}.db ${temp_dir}
            echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/bind/parts/db_e.tpl ... ${BLUECOLOR}$(sed -i -e "s/^\(www.*\)/\1\nusers.${main_domain} IN A ${ip_address}/g" /var/cache/bind/${main_domain}.db)${YELLOWCOLOR} Done ..." 
        fi
        restart_bind
        restart_apache
        echo -e "${YELLOWCOLOR}Successfully Applied"
        echo -e "a backup if the patched files has been created under ${temp_dir}"
        press_key_error
        hacks_menu
    elif [ "$continue_or_not" == "n" ]
    then
        hacks_menu
    else # None selected
        temporary_address_to_domains
    fi
}

restart_bind()
{
    ${bind} restart
}

restart_apache()
{
    ${apache} restart
}

add_spf_record()
{
    header_to_print="Add SPF Record"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "${CYANCOLOR}This hack will add an SPF record to your domains, continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then
        # Backuping files
        echo -e "${YELLOWCOLOR}Creating Backup Files ...${BLUECOLOR}"
        if ! test -e ${backup_dir}.dont_detele; then touch ${backup_dir}.dont_delete;fi
        temp_dir="${backup_dir}add_spf_hack/"
        mkdir -p ${temp_dir}
        cp /etc/vhcs2/bind/parts/db_e.tpl ${temp_dir}

        # Applying the hack
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/bind/parts/db_e.tpl ... ${BLUECOLOR}$(sed -i -e "s/\(ns.*IN.*A.*{DMN_IP}\)/\1\n{DMN_NAME}. IN TXT \"v=spf1 a mx ip4:{DMN_IP} ~all\"/g" /etc/vhcs2/bind/parts/db_e.tpl)${YELLOWCOLOR} Done ..."
        regenerate_configs
        restart_bind
        restart_apache
        echo -e "${YELLOWCOLOR}Successfully Applied"
        echo -e "a backup if the patched files has been created under ${temp_dir}"
        press_key_error
        hacks_menu
    elif [ "$continue_or_not" == "n" ]
    then
        hacks_menu
    else # None selected
        add_spf_record
    fi
}

activate_desactivate_logs_copying()
{
    ### This function activate/desactivate degug mode ###
    header_to_print="Activate/Desactivate Logs Copying"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "This hack will activate/desactivated Logs copying for users, normally users have their own error and traffic log"
    echo -e "in /var/www/virtual/domain.tld/logs/, If you desactivate it, the logs will no longer be copied"
    echo -e "It is activated by default on newly installed VHCS"
    echo -e ""
    echo -e "Please select what to do from the below menu"
    echo -e "${CYANCOLOR}"
    echo -e "1) Desactivate Logs Copying"
    echo -e "2) Activate Logs Copying"
    echo -e ""
    echo -e "Type m to Go back to the Hacks Menu"
    echo -e "Type q to Quit the script"
    read install_option
    if [ "$install_option" == "q" ]
    then
        quit_script
    elif [ "$install_option" == "1" ]
        then
        desactivate_logs_copying
    elif [ "$install_option" == "2" ]
        then
        activate_logs_copying
    elif [ "$install_option" == "m" ]
        then
        hacks_menu
    else
        activate_desactivate_debug_mode
    fi
}

desactivate_logs_copying()
{
    header_to_print="Desactivate Logs Copying"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "${CYANCOLOR}This will disable logs copying, continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then
        ### Desactivating Logs Copying

        # Backuping files
        echo -e "${YELLOWCOLOR}Creating Backup Files ...${BLUECOLOR}"
        if ! test -e ${backup_dir}.dont_detele; then touch ${backup_dir}.dont_delete;fi
        temp_dir="${backup_dir}logs_copying_hack/"
        mkdir -p ${temp_dir}
        cp /etc/vhcs2/apache/parts/dmn_entry.tpl ${temp_dir}
        cp /etc/vhcs2/apache/parts/sub_entry.tpl ${temp_dir}
        cp /etc/vhcs2/apache/parts/als_entry.tpl ${temp_dir}
        cp /etc/vhcs2/crontab/working/crontab.conf ${temp_dir}

        # Applying the hack
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/dmn_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^\([^#].*ErrorLog.*\)/#\1/g" /etc/vhcs2/apache/parts/dmn_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/sub_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^\([^#].*ErrorLog.*\)/#\1/g" /etc/vhcs2/apache/parts/sub_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/als_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^\([^#].*ErrorLog.*\)/#\1/g" /etc/vhcs2/apache/parts/als_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/dmn_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^\([^#].*TransferLog.*\)/#\1/g" /etc/vhcs2/apache/parts/dmn_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/sub_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^\([^#].*TransferLog.*\)/#\1/g" /etc/vhcs2/apache/parts/sub_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/als_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^\([^#].*TransferLog.*\)/#\1/g" /etc/vhcs2/apache/parts/als_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/crontab/working/crontab.conf ...${BLUECOLOR}$(sed -i -e "s/^\([^#].*vhcs2-httpd-logs-mngr.*\)/#\1/g" /etc/vhcs2/crontab/working/crontab.conf)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Adding new Crontab ... ${BLUECOLOR}$(crontab /etc/vhcs2/crontab/working/crontab.conf)${YELLOWCOLOR} Done..."
        echo -e "${BLUECOLOR}"
        regenerate_configs
        echo -e "${YELLOWCOLOR}Successfully Applied"
        echo -e "a backup if the patched files has been created under ${temp_dir}"
        press_key_error
        hacks_menu
    elif [ "$continue_or_not" == "n" ]
    then
        hacks_menu
    else # None selected
        desactivate_logs_copying
    fi
}

activate_logs_copying()
{
    header_to_print="Activate Logs Copying"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "${CYANCOLOR}This will enable logs copying, continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then
        ### Desactivating Logs Copying
        
        # Backuping files
        echo -e "${YELLOWCOLOR}Creating Backup Files ...${BLUECOLOR}"
        if ! test -e ${backup_dir}.dont_detele; then touch ${backup_dir}.dont_delete;fi
        temp_dir="${backup_dir}logs_copying_hack/"
        mkdir -p ${temp_dir}
        cp /etc/vhcs2/apache/parts/dmn_entry.tpl ${temp_dir}
        cp /etc/vhcs2/apache/parts/sub_entry.tpl ${temp_dir}
        cp /etc/vhcs2/apache/parts/als_entry.tpl ${temp_dir}
        cp /etc/vhcs2/crontab/working/crontab.conf ${temp_dir}

        # Applying the hack
echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/dmn_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^#\([^#].*ErrorLog.*\)/\1/g" /etc/vhcs2/apache/parts/dmn_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/sub_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^#\([^#].*ErrorLog.*\)/\1/g" /etc/vhcs2/apache/parts/sub_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/als_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^#\([^#].*ErrorLog.*\)/\1/g" /etc/vhcs2/apache/parts/als_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/dmn_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^#\([^#].*TransferLog.*\)/\1/g" /etc/vhcs2/apache/parts/dmn_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/sub_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^#\([^#].*TransferLog.*\)/\1/g" /etc/vhcs2/apache/parts/sub_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/apache/parts/als_entry.tpl ...${BLUECOLOR}$(sed -i -e "s/^#\([^#].*TransferLog.*\)/\1/g" /etc/vhcs2/apache/parts/als_entry.tpl)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Patching /etc/vhcs2/crontab/working/crontab.conf ...${BLUECOLOR}$(sed -i -e "s/^#\([^#].*vhcs2-httpd-logs-mngr.*\)/\1/g" /etc/vhcs2/crontab/working/crontab.conf)${YELLOWCOLOR} Done..."
        echo -e "${YELLOWCOLOR}Adding new Crontab ... ${BLUECOLOR}$(crontab /etc/vhcs2/crontab/working/crontab.conf)${YELLOWCOLOR} Done..."
        echo -e "${BLUECOLOR}"
        regenerate_configs
        echo -e "${YELLOWCOLOR}Successfully Applied"
        echo -e "a backup if the patched files has been created under ${temp_dir}"
        press_key_error
        hacks_menu
    elif [ "$continue_or_not" == "n" ]
    then
        hacks_menu
    else # None selected
        activate_logs_copying
    fi
}

ask_mysql_pass()
{
        echo -e "${CYANCOLOR}Please enter your mysql root password"
        read mysql_password
        echo -e "${BLUECOLOR}"
}
        
regenerate_configs()
{
        /etc/init.d/vhcs2_daemon stop
        if ! test -e ${base_dir}regenerate_configs; then wget -P ${base_dir} ${url}regenerate_configs; fi
        ask_mysql_pass
        mysql -u root --password="${mysql_password}" < ${base_dir}regenerate_configs
        echo -e "${YELLOWCOLOR}Applying modifications to existing domains ... ${BLUECOLOR}$(/var/www/vhcs2/engine/vhcs2-rqst-mngr)${YELLOWCOLOR} Done..."
        echo -e "${BLUECOLOR}"
        /etc/init.d/vhcs2_daemon start
}

activate_desactivate_debug_mode()
{
    ### This function activate/desactivate degug mode ###
    header_to_print="Activate/Desactivate Debug Mode"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "This hack will activate the debug mode of your VHCS it is usefull to trace bugs and to get better information in"
    echo -e "the /var/log/vhcs2"
    echo -e "Please select what to do from the below menu"
    echo -e "${CYANCOLOR}"
    echo -e "1) Activate Debug mode"
    echo -e "2) Desactivate Debug mode"
    echo -e ""
    echo -e "Type m to Go back to the Hacks Menu"
    echo -e "Type q to Quit the script"
    read install_option
    if [ "$install_option" == "q" ]
    then
        quit_script
    elif [ "$install_option" == "1" ]
        then
        activate_debug_mode
    elif [ "$install_option" == "2" ]
        then
        desactivate_debug_mode
    elif [ "$install_option" == "m" ]
        then
        hacks_menu
    else
        activate_desactivate_debug_mode
    fi
}

activate_debug_mode()
{
    header_to_print="Activate Debug Mode"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "${CYANCOLOR}This will enable debug mode, continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then
        ### Activating debug mode

        # Backuping files
        echo -e "${YELLOWCOLOR}Creating Backup Files ...${BLUECOLOR}"
        if ! test -e ${backup_dir}.dont_detele; then touch ${backup_dir}.dont_delete;fi
        temp_dir="${backup_dir}debug_mode_hack/"
        mkdir -p ${temp_dir}
        cp /var/www/vhcs2/engine/vhcs2_common_code.pl ${temp_dir}

        # Applying the hack

        echo -e "${BLUECOLOR}"
        echo -e "${YELLOWCOLOR}Patching /var/www/vhcs2/engine/vhcs2_common_code.pl ... ${BLUECOLOR}$(sed -i -e \"s/\([#].*\$main::engine_debug = '\(_off_\|_on_\)';.*\)/\$main::engine_debug = '_on_';/g\" /var/www/vhcs2/engine/vhcs2_common_code.pl)"
        echo -e "${YELLOWCOLOR}Successfully Applied"
        echo -e "a backup if the patched files has been created under ${temp_dir}"
        press_key_error
        hacks_menu
    elif [ "$continue_or_not" == "n" ]
    then
        hacks_menu
    else # None selected
        activate_debug_mode
    fi
}

desactivate_debug_mode()
{
    header_to_print="Desactivate Debug Mode"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e ""
    echo -e "${CYANCOLOR}This will disable debug mode, continue? [y/n]"
    read continue_or_not
    if [ "$continue_or_not" == "y" ]
    then
        ### Desactivating debug mode
        
        # Backuping files
        echo -e "${YELLOWCOLOR}Creating Backup Files ...${BLUECOLOR}"
        if ! test -e ${backup_dir}.dont_detele; then touch ${backup_dir}.dont_delete;fi
        temp_dir="${backup_dir}debug_mode_hack/"
        mkdir -p ${temp_dir}
        cp /var/www/vhcs2/engine/vhcs2_common_code.pl ${temp_dir}

        # Applying the hack

        echo -e "${BLUECOLOR}"
        sed -i -e "s/\([#].*\$main::engine_debug = '\(_off_\|_on_\)';.*\)/\$main::engine_debug = '_off_';/g" /var/www/vhcs2/engine/vhcs2_common_code.pl
        echo -e "${YELLOWCOLOR}Successfully Applied"
        echo -e "a backup if the patched files has been created under ${temp_dir}"
        press_key_error
        hacks_menu
    elif [ "$continue_or_not" == "n" ]
    then
        hacks_menu
    else # None selected
        desactivate_debug_mode
    fi
}

check_user()
{
    ### checking about the user
    if [ `whoami` != "root" ]; then
      echo -e "this script can only be run as a super user"
      echo -e "please run it as a super user"
      exit 1
    fi
}

print_license()
{
    ### let's print the license shall we?? :D
    ${clear}
    header_to_print="VHCS Automatic Installer V.${VERSION} By Wael Nasreddine"
    print_header
    echo -e " ${LILACCOLOR}+---------------------------------------------------------------------------------------------------+${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} Wael Nasreddine / wael.nasreddine@sabayonlinux.org                                                ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} and Armadillo / armadillo@penguinfriends.org                                                      ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR}                                                                                                   ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} Purpose of this script is to install VHCS                                                         ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}|${COLOROFF}${GREENCOLOR}                                                                                                   ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}|${COLOROFF}${GREENCOLOR} This script is distributed without any warrenty use it at your own risk.                          ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} If this script blows up your installation it's not my fault :)                                    ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR}                                                                                                   ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} This script has been tested on Ubuntu Breezy Badger 5.10, Dapper Drake (6.06), Gutsy Gibbon(7.10),${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} Debian Sarge (3.1) and Debian Etch (4.0).                                                         ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} You can modify this script and/or redestribute it (Under GPL V2) but this text stay               ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} on the TOP and displayed to the user when he run the script.                                      ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} Whatever you change, this license must always be displayed to the user...                         ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR}                                                                                                   ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}${COLOROFF}${LILACCOLOR}|${COLOROFF}${COLOROFF}${GREENCOLOR} any suggestion are welcomed...                                                                    ${COLOROFF}${LILACCOLOR}|${COLOROFF}"
    echo -e " ${LILACCOLOR}+---------------------------------------------------------------------------------------------------+${COLOROFF}"
    echo -e "${YELLOWCOLOR}"
    echo -e "please read the above text"
    echo -e "do you accept the above terms? [y/n]"
    read accept
    echo -e "${CYANCOLOR}"
    if [ "${accept}" == "n" ]
    then
        echo -e "${YELLOWCOLOR}aborting....${COLOROFF}"
        exit 1
    elif [ "${accept}" == "y" ]
        then
        echo ""
    else # none selected
        print_license
    fi
}

print_script_usage()
{
    ### Let's Just print the Script Usage
    header_to_print="Script Usage"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "The text color will tell you from where the text is coming from and here's the legend"
    echo -e ""
    echo -e "${BLUECOLOR}The blue text means that it's coming from your system"
    echo -e "${YELLOWCOLOR}The Yellow text are the notification coming from the script"
    echo -e "${CYANCOLOR}The Cyan text represent something that needs user intervention like a question or key pressing"
    echo -e "${REDCOLOR}The red text Represent Errors and Very Important notes"
    echo -e "${YELLOWCOLOR}"
    echo -e "if you don't want any colors then "
    echo -e "${REDCOLOR}export VHCS_NO_COLORS=YES"
    echo -e "${YELLOWCOLOR}"
    echo -e "The script will always tell you to press a key on each step two times, to start and to verify that everything went well"
    echo -e "If you dont want to have these questions then press now Ctrl + C and type at the terminal"
    echo -e "${REDCOLOR}export VHCS_NO_QUESTIONS=YES"
    echo -e "${YELLOWCOLOR}Launch the script again"
    echo -e "${YELLOWCOLOR}"
    echo -e "To use another sourceforge mirror use SF_MIRROR envirement variable"
    echo -e "${REDCOLOR}export SF_MIRROR=\"ovh\""
    echo -e "${YELLOWCOLOR}"
    force_press_key
}

check_for_updates()
{
    ### Let's check for a new version
    header_to_print="Check for updates"
    print_header
    echo -e "${BLUECOLOR}"
    if test -e ${base_dir}version; then rm ${base_dir}version; fi
    ${wget} -P ${base_dir} ${url}version
    LATEST_VERSION=$(cat ${base_dir}version)
    if [ "$VERSION" != "$LATEST_VERSION" ]
    then
        echo -e "${YELLOWCOLOR}"
        echo -e "Your Version : ${VERSION}"
        echo -e "Latest Version : ${LATEST_VERSION}"
        echo -e "Downloading New Version"
        press_key
        echo -e "${BLUECOLOR}"
        rm vhcs.sh
        ${wget} ${url}vhcs.sh
        press_key
        sh vhcs.sh
        exit 0
    else
        echo -e "${YELLOWCOLOR}"
        echo -e "You have the Version ${VERSION} which is the Latest Version"
        press_key
    fi
}

print_changelog()
{
    ### Let's display Changelog
    header_to_print="Changelog"
    print_header
    echo -e "${YELLOWCOLOR}"
    echo -e "V 1.3.1"
    echo -e "V It Seems that I forgot to remove my debugging-aid, uncomment main functions."
    echo -e "V 1.3"
    echo -e "\t Updated my script to version 1.2.3b Thanks to Armadillo, Release my script under GPL V2 or, at your choice, a later version."
    echo -e "V 1.2.2e"
    echo -e "\t Added japanese language pack to VHCS 2.4.7.1 package (thanks to hiroron)"
    echo -e "V 1.2.2d"
    echo -e "\t Removed package postfix-tls from Debian Etch (4.0) package list, which is now included in postfix main package"
    echo -e "V 1.2.2c"
    echo -e "\t Updated phpMyAdmin to 2.11.2.2"
    echo -e "V 1.2.2b"
    echo -e "\t Removed a logical bug from the installscript (Thanks to svschwartz)"
    echo -e "\t Added some modifications to the proftpd.conf to increase the speed of proftpd. (Thanks to Marcos again)"
    echo -e "V 1.2.2a"
    echo -e "\t Removed package libnet-perl from the Debian Etch (4.0) Package List, because it's now included in the package perl-modules. (Thanks to Marcos)"
    echo -e "V 1.2.2"
    echo -e "\t Added support for Ubuntu Gutsy Gibbon (7.10), added some cosmetical issues added a line to the Postfix's main.cf."
    echo -e "V 1.2.1b"
    echo -e "\t Added Sources to the sources.list for Debian Etch (4.0) to install ClamAV and Spamassassin. (Thanks to Baris)"
    echo -e "V 1.2.1a"
    echo -e "\t Added some Options in the proftpd.conf in the VCHS Package to get it working right on all systems and to set the proftpd-user to \"proftpd\"."
    echo -e "V 1.2.1"
    echo -e "\t Added automatic copying of the proftpd.conf to /etc/proftpd for Debian Etch (4.0)."
    echo -e "\t Added after copying of the proftpd.conf restarting of ProFTPd to submit the new config."
    echo -e "V 1.2.0a"
    echo -e "\t Some cosmetic changes."
    echo -e "V 1.2.0"
    echo -e "\t Added support for Debian Etch (4.0) with PHP5 and MySQL5."
    echo -e "V 1.1.0c"
    echo -e "\t Replace mysql-common-4.1 with mysql-common for Ubuntu."
    echo -e "V 1.1.0b"
    echo -e "\t Fixed a typo..."
    echo -e "V 1.1.0a"
    echo -e "\t Removed postfix-tls from Ubuntu Breezy..."
    echo -e "V 1.1.0"
    echo -e "\t Added dapper drake..."
    echo -e "\t Using Sourceforge to download vhcs sources and not my server, also use SF_MIRROR to download from a specific mirror"
    echo -e "V 1.0.9b"
    echo -e "\t Removed package libmime-base64-perl from debian installation"
    echo -e "V 1.0.9a"
    echo -e "\t Corrected the sources link from my website"
    echo -e "V 1.0.9"
    echo -e "\t Install VHCS 2.4.7.1 instead of 2.4.7"
    echo -e "\t Added an update from 2.4.7 to 2.4.7.1"
    echo -e "\t replaced mysql-server, mysql-common, mysql-client with mysql-server-4.1, mysql-common-4.1, mysql-client-4.1"
    echo -e "\t added the package php4-gd as it is needed for vhcs gui, lost password feature"
    press_key
}

quit_script()
{
    echo -e "${BLUECOLOR}"
    
    # If the backup directory is empty then erase it!!
    if ! test -e ${backup_dir}.dont_delete; then rm -rf ${backup_dir}; fi
    
    # Restore users sources.list if the backup still exist, this will ensure that the user got back his sources.list
    # when he hit Ctrl + C
    if test -e /etc/apt/sources.list_vhcs_backup; then mv /etc/apt/sources.list_vhcs_backup /etc/apt/sources.list; fi
    
    echo -e "${COLOROFF}"

    # Exit the script depending on the exit parameter
    exit ${1}
}

### End Of Functions ###

### main script starts here ###

### Traping Control C
trap handle_interrupt 2 15

### Checking if it's root user
check_user

### Making the backup dir
mkdir -p ${backup_dir}

### Print the Licence NOTE: You are not authorized to comment the below line
### Or Changing any line on the License itself, it's 15 Lines and must stay 15
### thank you for understanding, and appreciating my hard work upon this script
print_license

### Print the script usage
print_script_usage

### Check for script updates, if there is any download and run it
check_for_updates

### Print the Change log
print_changelog

### Let's go to the Main Menu now as everything is handled already
main_menu

### Ok just to make sure that the script will quit, it's not possible user will achieve this, but just to make sure
quit_script

# End Of File
# vim: set ft=sh ts=4 sw=4 expandtab:
