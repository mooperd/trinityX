
######################################################################
# TrinityX
# Copyright (c) 2016  ClusterVision B.V.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License (included with the sources) for more
# details.
######################################################################


display_var HA PRIMARY_INSTALL CTRL2_HOSTNAME POST_FILEDIR


#---------------------------------------
# Shared functions
#---------------------------------------

# Generate user SSH keys
# By default the target dir is the .ssh subfolder of the user's home directory.
# The first option overrides this and creates the keys in a different directory.
# Any additional option is passed to ssh-keygen as-is.
#
# Syntax: generate_user_keys [target_dir] [additional ssh-keygen params]

function generate_user_keys {
    echo_info "Generating private SSH keys"
    
    dest="${1:-${HOME}/.ssh}"
    mkdir -p "$dest" && chmod 700 "$dest"
    shift
    
    [[ -e ${dest}/id_rsa ]] || ssh-keygen -t rsa -b 4096 -N "" -f ${dest}/id_rsa "${@}"
    [[ -e ${dest}/id_ecdsa ]] || ssh-keygen -t ecdsa -b 521 -N "" -f ${dest}/id_ecdsa "${@}"
    [[ -e ${dest}/id_ed25519 ]] || ssh-keygen -t ed25519 -N "" -f ${dest}/id_ed25519 "${@}"
}


function install_ctrl_config {
    install -D -m 600 --backup "${POST_FILEDIR}/sshd_config" /etc/ssh/sshd_config
    install -D -m 644 --backup "${POST_FILEDIR}/ssh_config" /etc/ssh/ssh_config

    systemctl restart sshd
}



#---------------------------------------
# Non-HA
#---------------------------------------

if flag_is_unset HA ; then

    generate_user_keys
    install_ctrl_config
    exit
fi



#---------------------------------------
# HA primary
#---------------------------------------

if flag_is_set PRIMARY_INSTALL ; then
    
    generate_user_keys
    install_ctrl_config
    
    # Now the primary keys are set, but we need to be able to SSH into the
    # secondary node, and vice-versa. Also, we need to be able to SSH into the
    # same controller as we are logged in, using the floating name.
    # The easiest way to set that up is to generate here and now the secondary
    # root's SSH key pairs, use it to set up the authorized_keys file, and
    # prepare everything for the secondary install.
    
    dest="/root/secondary/.ssh"
    generate_user_keys "$dest" -C "root@${CTRL2_HOSTNAME}.$(hostname -d)"
    append_line /root/.ssh/authorized_keys "$(cat /root/.ssh/id_ed25519.pub)"
    append_line /root/.ssh/authorized_keys "$(cat "${dest}/id_ed25519.pub")"
    cp /root/.ssh/authorized_keys "$dest"


#---------------------------------------
# HA secondary
#---------------------------------------

else
    
    install_ctrl_config

    # All was prepared during the primary installation, copy it over
    install -D -t /root -m 700 /root/secondary/.ssh
fi

