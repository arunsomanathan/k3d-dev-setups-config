#!/usr/bin/env bash

# A best practices Bash script template with many useful functions. This file
# sources in the bulk of the functions from the source.sh file which it expects
# to be in the same directory. Only those functions which are likely to need
# modification are present in this file. This is a great combination if you're
# writing several scripts! By pulling in the common functions you'll minimise
# code duplication, as well as ease any potential updates to shared functions.

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace       # Trace the execution of the script (debug)
fi

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    # A better class of script...
    set -o errexit      # Exit on most errors (see the manual)
    set -o nounset      # Disallow expansion of unset variables
    set -o pipefail     # Use last non-zero exit code in a pipeline
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace         # Ensure the error trap handler is inherited

# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat << EOF

Usage:
    -h          Displays this help
    -c          Configuration file for creating the k3d cluster
    -n          Name of the cluster
EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    while getopts "hn:c:" flag ; do
        case ${flag} in
            h) script_usage; script_exit "" ;;
            n) name=${OPTARG} ;;
            c) config=${OPTARG};;
        esac
        shift
    done
}


# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
# DESC: Create cluster flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function create() {
    
    clusterExist=false

    check_prerequisite

    prepare_environment
    
    create_cluster
}

# DESC: Checks the prerequisite for running the scripts
# ARGS: None
# OUTS: None
function check_prerequisite() {
    check_docker
    check_k3d

    if ! [ -z ${config+x} ]
    then
        check_config_file_exist
    fi
}

# DESC: Checks whether docker is available
# ARGS: None
# OUTS: None
function check_docker() {
    command -v docker >/dev/null 2>&1 || { script_exit "docker is require but it's not installed. Aborting." 1 ; }
}

# DESC: Checks whether k3d is available
# ARGS: None
# OUTS: None
function check_k3d() {
    command -v k3d >/dev/null 2>&1 || { script_exit "k3d is require but it's not installed. Aborting." 1 ; }
}

# DESC: Check the input config file exist
# ARGS: None
# OUTS: None
function check_config_file_exist() {
    if test -f "$config"; then
        return
    fi
    config="./configs/$config"
    if test -f "$config"; then
        return
    fi
    script_exit "Invalid config file. Please check config file is present in the given location" 1
}

# DESC: Prepare the environment for creating a new cluster
# ARGS: None
# OUTS: None
function prepare_environment() {
    check_cluster_exist
    delete_cluster
}

# DESC: Checks whether the cluster with the given name exist
# ARGS: None
# OUTS: None
function check_cluster_exist() {
    pretty_print "================================================================================"
    if [ -z ${name+x} ]
    then
        if ! [ -z ${config+x} ]
        then
            find_name_from_config_file
        fi

        if [ -z ${name+x} ]
        then
            pretty_print "Using default name k3s-default for the cluster"
            name="k3s-default"
        fi
    fi
    pretty_print "Check whether the cluster with name $name exist"
    
    clusterList=$(k3d cluster list --no-headers | awk '{ print $1}')

    for clusterName in $clusterList
    do
            if [ "$name" = "$clusterName" ]
            then
                    clusterExist=true
                    break
            fi
    done

    if [ $clusterExist = true ]
    then
            pretty_print "$name cluster exists"
    else
            pretty_print "$name cluster does not exists"
    fi

    pretty_print "================================================================================"
}

# DESC: Find the name of the cluster in the config file
# ARGS: None
# OUTS: None
function find_name_from_config_file() {
    name=$(find_value_from_yaml "$config" "name")
}


# DESC: Find the value for a key in a yaml file.
# ARGS: $1 - The yaml file to be parsed, $2 - the key to be searched
# OUTS: None
function find_value_from_yaml() {
    local key="name"
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    value=$(sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -v key_name="$key" -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            if ( key_name == $2 ) {
                print $3
            }

        }
    }')
    echo $value
}

# DESC: Delete the cluster
# ARGS: None
# OUTS: None
function delete_cluster() {
    if [ $clusterExist = true ]

    then
        pretty_print "Cluster - $name already exist. Do you want to delete it and create a new cluster ? [y/N]" $fg_red
        read -p "" confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || script_exit "" 
        pretty_print "================================================================================" $fg_red
        pretty_print "Deleting $name cluster" $fg_red
        
        k3d cluster delete $name
        
        pretty_print "================================================================================" $fg_red
    fi
}

# DESC: Create new k3d cluster
# ARGS: None
# OUTS: None
function create_cluster() {
    pretty_print "================================================================================" $fg_cyan
    pretty_print "Setting up and starting $name cluster" $fg_cyan
    if [ "$config" = "" ]
    then
        k3d cluster create $name
    else
        k3d cluster create $name --config "$config"
    fi
    pretty_print "================================================================================" $fg_cyan
}


# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    parse_params "$@"
    cron_init
    colour_init
    #lock_init system
    
    create

}

# shellcheck source=source.sh
source "$(dirname "${BASH_SOURCE[0]}")/source.sh"

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi

