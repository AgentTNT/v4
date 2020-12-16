#!/bin/bash
#-----------------------------------------------------------------------------#
# eFa 4.0.3 build script version 20200912
#-----------------------------------------------------------------------------#
# Copyright (C) 2013~2020 https://efa-project.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#-----------------------------------------------------------------------------#
action=$1
[[ -z $action ]] && action="production" # default to prod if no arg supplied

#-----------------------------------------------------------------------------#
# Install eFa
#-----------------------------------------------------------------------------#
mirror="https://mirrors.efa-project.org"
LOGFILE="/var/log/eFa/build.log"

#-----------------------------------------------------------------------------#
# Set up logging
#-----------------------------------------------------------------------------#
LOGGER='/usr/bin/logger'
HEADER='=============  EFA4 BUILD SCRIPT STARTING  ============'

# CREATE LOG FOLDER IF NOT EXISTS
mkdir -p $(dirname "${LOGFILE}")

# TRY TO CREATE LOG FILE IF NOT EXISTS
( [ -e "$LOGFILE" ] || touch "$LOGFILE" ) && [ ! -w "$LOGFILE" ] && echo "Unable to create or write to $LOGFILE"

function logthis() {
    TAG='EFA4'
    MSG="$1"
    $LOGGER -t "$TAG" "$MSG"
    echo "`date +%Y.%m.%d-%H:%M:%S` - $MSG"
    echo "`date +%Y.%m.%d-%H:%M:%S` - $MSG" >> $LOGFILE
}

logthis "$HEADER"
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# check if user is root
#-----------------------------------------------------------------------------#
if [ `whoami` == root ]; then
  logthis "Good you are root."
else
  logthis "ERROR: Please become root first."
  logthis "^^^^^^^^^^ SCRIPT ABORTED ^^^^^^^^^^"
  exit 1
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# check if running a supported EL version of 7 or 8
#-----------------------------------------------------------------------------#
STRING_OSNAME="Good, you are running $OSNAME Linux"
OSINFO=`cat /etc/*-release`
if [[ $OSINFO =~ .*'Oracle'.* ]]; then
  OSNAME="Oracle"
  logthis "$STRING_OSNAME"
elif [[ $OSINFO =~ .*'CentOS'.* ]]; then
  OSNAME="CentOS"
  logthis "$STRING_OSNAME"
elif [[ $OSINFO =~ .*'Red Hat Enterprise'.* ]]; then
  OSNAME="Red Hat Enterprise"
  logthis "$STRING_OSNAME"
else
  logthis "ERROR: You are running an unsupported flavor of Linux"
  logthis "ERROR: Unsupported system, stopping now"
  logthis "^^^^^^^^^^ SCRIPT ABORTED ^^^^^^^^^^"
  exit 1
fi

if [[ $OSINFO =~ .*'release 7.'.* ]]; then
  RELEASE=7
  logthis "Good, you are running $OSNAME Linux $RELEASE"
elif [[ $OSINFO =~ .*'release 8.'.* ]]; then
  RELEASE=8
  logthis "Good, you are running $OSNAME Linux $RELEASE"
else
  logthis "ERROR: You are running an unsupported release of $OSNAME Linux"
  logthis "ERROR: Unsupported system, stopping now"
  logthis "^^^^^^^^^^ SCRIPT ABORTED ^^^^^^^^^^"
  exit 1
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Check that SELinux is not disabled (unless it is lxc)
#-----------------------------------------------------------------------------#
if [[ -z $(grep -i 'lxc\|docker' /proc/1/cgroup) ]]; then
    if [[ -f /etc/selinux/config && -n $(grep -i ^SELINUX=disabled$ /etc/selinux/config)  ]]; then
        logthis "ERROR: SELinux is disabled and this is not an lxc container"
        logthis "ERROR: Please enable SELinux and try again."
        logthis "^^^^^^^^^^ SCRIPT ABORTED ^^^^^^^^^^"
        exit 1
    fi
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Check network connectivity
#-----------------------------------------------------------------------------#
logthis "Checking network connectivity"
# use curl to test in case wget not installed yet.
curl -s --connect-timeout 3 --max-time 10 --retry 3 --retry-delay 0 --retry-max-time 30 "${mirror}" > /dev/null
if [[ $? -eq 0 ]]; then
  logthis "OK - $mirror is reachable"
else
  logthis "ERROR: No network connectivity"
  logthis "ERROR: unable to reach $mirror"
  logthis "^^^^^^^^^^ SCRIPT ABORTED ^^^^^^^^^^"
  exit 1
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# have network, install wget if missing
#-----------------------------------------------------------------------------#
rpm -q wget >/dev/null 2>&1
if [ $? -ne 0 ]; then
    logthis "Installing wget"
    yum -y install wget
    if [ $? -eq 0 ]; then
        logthis "wget installed"
    else
        logthis "ERROR: wget installation failed"
        # non-fatal for this script but will cause issues after system configuration
    fi
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Install perl if missing
#-----------------------------------------------------------------------------#
rpm -q perl >/dev/null 2>&1
if [ $? -ne 0 ]; then
    logthis "Installing perl"
    yum -y install perl
    if [ $? -eq 0 ]; then
        logthis "perl installed"
    else
        logthis "ERROR: perl installation failed"
        exit 1
    fi
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Add eFa Repo
#-----------------------------------------------------------------------------#
aCTN=(testing kstesting testingnoefa)

case "${aCTN[@]}" in
    ("$action "*|*" $action "*|*" $action")
       if [ ! -f /etc/yum.repos.d/eFa4-testing.repo ]; then
            if [[ $RELEASE -eq 7 ]]; then
                logthis "Adding eFa Enterprise Linux 7 Testing Repo"
                rpm --import $mirror/rpm/eFa4/RPM-GPG-KEY-eFa-Project
                curl -L $mirror/rpm/eFa4/eFa4-testing.repo -o /etc/yum.repos.d/eFa4-testing.repo
            else
                logthis "Adding eFa Enterprise Linux 8 Testing Repo"
                rpm --import $mirror/rpm/eFa4/RPM-GPG-KEY-eFa-Project
                curl -L $mirror/rpm/eFa4/CentOS8/eFa4-centos8-testing.repo -o /etc/yum.repos.d/eFa4-centos8-testing.repo
            fi
       fi
       ;;

    *)  if [ ! -f /etc/yum.repos.d/eFa4.repo ]; then
            if [[ $RELEASE -eq 7 ]]; then
                logthis "Adding eFa Repo"
                rpm --import $mirror/rpm/eFa4/RPM-GPG-KEY-eFa-Project
                curl -L $mirror/rpm/eFa4/eFa4.repo -o /etc/yum.repos.d/eFa4.repo
            else
                logthis "Adding eFa Repo"
                rpm --import $mirror/rpm/eFa4/RPM-GPG-KEY-eFa-Project
                curl -L $mirror/rpm/eFa4/CentOS8/eFa4-centos8.repo -o /etc/yum.repos.d/eFa4.repo
            fi
        fi
        ;;
esac
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# epel repo
#-----------------------------------------------------------------------------#
STRING_EPEL_PREV_INSTALLED="$OSNAME EPEL $RELEASE repo already installed"
STRING_EPEL_NOT_INSTALLED="$OSNAME EPEL $RELEASE repo is not installed"
STRING_EPEL_INSTALLING="Installing $OSNAME EPEL $RELEASE Repo"
STRING_EPEL_INSTALLED="$OSNAME EPEL $RELEASE repo installed"
STRING_EPEL_ERROR="ERROR: $OSNAME EPEL $RELEASE installation failed"
STRING_SCRIPT_ABORT="^^^^^^^^^^ SCRIPT ABORTED ^^^^^^^^^^"

if [ "$OSNAME" = "CentOS" ]; then
  rpm -q epel-release >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    logthis "$STRING_EPEL_PREV_INSTALLED"
  elif [ $? -ne 0 ]; then
    logthis "$STRING_EPEL_NOT_INSTALLED"
    logthis "$STRING_EPEL_INSTALLING"
    yum -y install epel-release
    if [ $? -eq 0 ]; then
      logthis "$STRING_EPEL_INSTALLED"
    else
      logthis "$STRING_EPEL_ERROR"
      logthis "$STRING_SCRIPT_ABORT"
      exit 1
    fi
  fi
elif [ "$OSNAME" = "Oracle" ] || [ "$OSNAME" = "Red Hat Enterprise" ]; then
  if [ $RELEASE -eq 7 ]; then
    rpm -q epel-release >/dev/null 2>&1
    if [ $? -eq 0 ]; then
    logthis "$STRING_EPEL_PREV_INSTALLED"
    elif [[ $? -ne 0 ]]; then
      logthis "$STRING_EPEL_NOT_INSTALLED"
      logthis "$STRING_EPEL_INSTALLING"
      yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
      rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
      if [ $? -eq 0 ]; then
        logthis "$STRING_EPEL_INSTALLED"
      else
        logthis "$STRING_EPEL_ERROR"
        logthis "$STRING_SCRIPT_ABORT"
        exit 1
      fi
    fi
  elif [ $RELEASE -eq 8 ]; then
    rpm -q epel-release >/dev/null 2>&1
    if [ $? -eq 0 ]; then
     logthis "$STRING_EPEL_PREV_INSTALLED"
    elif [[ $? -ne 0 ]]; then
      logthis "$STRING_EPEL_NOT_INSTALLED"
      logthis "$STRING_EPEL_INSTALLING"
      yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
      rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8
      if [ $? -eq 0 ]; then
        logthis "$STRING_EPEL_INSTALLED"
      else
        logthis "$STRING_EPEL_ERROR"
        logthis "$STRING_SCRIPT_ABORT"
        exit 1
      fi
    fi
  fi
fi

#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# ius repo
#-----------------------------------------------------------------------------#
if [[ $RELEASE -eq 7 ]]; then
    rpm -q ius-release >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        logthis "Installing IUS Repo"
        yum -y install https://repo.ius.io/ius-release-el7.rpm
        if [ $? -eq 0 ]; then
            logthis "IUS repo installed"
            rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-IUS-7
            if [[ "$OSNAME" = "Oracle" ]]; then
              #Needed for perl packages on Oracle Linux
              logthis "Enabling $OSNAME Linux $RELEASE Optional Latest repo"
              yum-config-manager --enable ol7_optional_latest
            fi
        else
            logthis "ERROR: IUS installation failed"
            logthis "^^^^^^^^^^ SCRIPT ABORTED ^^^^^^^^^^"
            exit 1
        fi
    fi
elif [[ $RELEASE -eq 8 ]]; then
  if [[ "$OSNAME" = "CentOS" ]]; then
    logthis "Enabling CentOS 8 PowerTools Repo"
    yum config-manager --set-enabled powertools
    [ $? -ne 0 ] && exit 1
  elif [[ "$OSNAME" = "Oracle" ]]; then
    logthis "Enabling Oracle Linux 8 CodeReady Builder repo"
    yum config-manager --set-enabled ol8_codeready_builder
  fi
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Update OS
#-----------------------------------------------------------------------------#
logthis "Updating the OS"
yum -y update >> $LOGFILE 2>&1
if [ $? -eq 0 ]; then
    logthis "System Updated"
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Remove not needed packages
#-----------------------------------------------------------------------------#
logthis "Removing conflicting packages"
yum -y remove postfix mariadb-libs >/dev/null 2>&1
# Ignore return here
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# install eFa
#-----------------------------------------------------------------------------#
logthis "Installing eFa packages (This can take a while)"
rpm -q eFa >/dev/null 2>&1
if [ $? -ne 0 ]; then
    if [[ "$action" != "testingnoefa" ]]; then
        yum -y install eFa >> $LOGFILE 2>&1
        if [ $? -eq 0 ]; then
            logthis "eFa4 Installed"
        else
            logthis "ERROR: eFa4 failed to install"
            logthis "^^^^^^^^^^ SCRIPT ABORTED ^^^^^^^^^^"
            exit 1
        fi
    fi
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# kickstart
#-----------------------------------------------------------------------------#
if [[ "$action" == "kstesting" || "$action" == "ksproduction" ]]; then
  # Set root default pass for kickstart builds
  echo 'echo "First time login: root/eFaPr0j3ct" >> /etc/issue' >> /etc/rc.d/rc.local
  echo "root:eFaPr0j3ct" | chpasswd --md5 root

  # Disable ssh for kickstart builds
  systemctl disable sshd
fi

if [[ "$action" == "ksproduction" ]]; then
  # Zero free space in preparation for export
  logthis "Zeroing free space"
  dd if=/dev/zero of=/filler bs=4096 >/dev/null 2>&1
  rm -f /filler
  dd if=/dev/zero of=/tmp/filler bs=4096 >/dev/null 2>&1
  rm -f /tmp/filler
  dd if=/dev/zero of=/boot/filler bs=4096 >/dev/null 2>&1
  rm -f /boot/filler
  dd if=/dev/zero of=/var/filler bs=4096 >/dev/null 2>&1
  rm -f /var/filler
  logthis "Zeroed free space"
fi
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# finalize
#-----------------------------------------------------------------------------#
logthis "============  EFA4 BUILD SCRIPT FINISHED  ============"
logthis "============  PLEASE REBOOT YOUR SYSTEM   ============"

if [[ "$action" == "testing" || "$action" == "production" ]]; then
  read -p "Do you wish to reboot the system now? (Y/N): " yn
  if [[ "$yn" == "y" || "$yn" == "Y" ]]; then
    shutdown -r +1 "Installation requires reboot. Restarting in 1 minute"
    exit 0
  else
    exit 0
  fi
fi
exit 0
#-----------------------------------------------------------------------------#
