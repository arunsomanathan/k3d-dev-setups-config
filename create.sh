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

declare -A input_opts
input_opts["agents"]="-a"
input_opts["env"]="-e"
input_opts["image"]="-i"
input_opts["kubeapi"]="-k"
input_opts["options"]="-o"
input_opts["ports"]="-p"
input_opts["network"]="-n"
input_opts["registries"]="-r"
input_opts["servers"]="-s"
input_opts["token"]="-t"
input_opts["volumes"]="-v"

declare dryrun="N"

# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat << EOF

    Usage:
        -a          Agents identifier
        -c          Configuration file for creating the k3d cluster
        -d          Dry run. Can be used to view the configuration
        -e          Environment variables
        -h          Displays this help
        -i          Image identifier
        -k          kubeAPI settings identifier
        -l          Labels
        -n          Name of the cluster
        -o          Options settings identifier
        -p          Ports settings identifier
        -q          Network settings identifier
        -r          Registry settings identifier
        -s          Servers identifier
        -t          Token settings identifier
        -v          Volumes settings identifier
        -y          Select a predefined combination of configuration
EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    while getopts "a:c:e:dhi:k:l:n:o:p:q:r:s:t:v:y:" flag ; do
        case ${flag} in
            a) agents=${OPTARG};;
            c) config=${OPTARG} ;;
            d) dryrun="Y" ;;
            e) env=${OPTARG} ;;
            h) script_usage; script_exit "" ;;
            i) image=${OPTARG};;
            k) kubeapi=${OPTARG} ;;
            l) lables=${OPTARG} ;;
            n) name=${OPTARG};;
            o) options=${OPTARG} ;;
            p) ports=${OPTARG};;
            q) network=${OPTARG} ;;
            r) registries=${OPTARG};;
            s) servers=${OPTARG} ;;
            t) token=${OPTARG} ;;
            v) volumes=${OPTARG} ;;
            y) preset=${OPTARG} ;;
        esac
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
    
    if [ "${dryrun}" = "N" ]
    then
        create_cluster
    fi
    

    cleanup
}

# DESC: Checks the prerequisite for running the scripts
# ARGS: None
# OUTS: None
function check_prerequisite() {
    check_docker
    check_k3d
    check_yq

    validate_inputs
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

# DESC: Checks whether yq is available
# ARGS: None
# OUTS: None
function check_yq() {
    command -v yq >/dev/null 2>&1 || { script_exit "yq is require but it's not installed. Aborting." 1 ; }
}

# DESC: Validate the user inputs
# ARGS: None
# OUTS: None
function validate_inputs() {

    #Validate Config
    if ! [ -z ${config+x} ]
    then
        check_config_file_exist
    fi

    #TODO look at the option of creating constants
    for key in "${!input_opts[@]}"; 
    do
        if ! [ -z ${!key+x} ]
        then
            check_file_exist "./configs/${key}/${!key}.yaml" "${input_opts[$key]} ${!key}"
        fi
    done

    #Validate preset
    if ! [ -z ${preset+x} ]
    then
        check_valid_preset "${preset}"
    fi
}

# DESC: Check the file exist
# ARGS: None
# OUTS: None
function check_file_exist() {
    if test -f "${1}"; then
        return
    fi
    script_exit "Cannot find configuration file for the provided flag ${2}" 1
}

# DESC: Check the input config file exist
# ARGS: None
# OUTS: None
function check_config_file_exist() {
    if test -f "${config}"; then
        return
    fi
    config="./configs/${config}"
    if test -f "${config}"; then
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
    prepare_config
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
    
    pretty_print "Check whether the cluster with name ${name} exist"
    
    clusterList=$(k3d cluster list --no-headers | awk '{ print $1}')

    for clusterName in $clusterList
    do
        if [ "${name}" = "${clusterName}" ]
        then
            clusterExist=true
            break
        fi
    done

    if [ ${clusterExist} = true ]
    then
        pretty_print "${name} cluster exists"
    else
        pretty_print "${name} cluster does not exists"
    fi

    pretty_print "================================================================================"
}

# DESC: Find the name of the cluster in the config file
# ARGS: None
# OUTS: None
function find_name_from_config_file() {
    name=$(find_value_from_yaml "${config}" "name")
}

# DESC: Delete the cluster
# ARGS: None
# OUTS: None
function delete_cluster() {
    if [ ${clusterExist} = true ]

    then
        pretty_print "================================================================================" ${fg_red}
        pretty_print "Cluster - ${name} already exist. Do you want to delete it and create a new cluster ? [y/N]" ${fg_red}
        read -p "" confirm && [[ ${confirm} == [yY] || ${confirm} == [yY][eE][sS] ]] || script_exit "" 
        pretty_print "Deleting ${name} cluster" ${fg_red}
        
        k3d cluster delete ${name}
        
        pretty_print "================================================================================" ${fg_red}
    fi
}

# DESC: Prepate the configuration based on the inputs
# ARGS: None
# OUTS: None
function prepare_config() {
    pretty_print "================================================================================" ${fg_magenta}
    # Following will the order of creating config file if the option is specified
    # preset <- individual config <- user config file
    temp_conf_file=$(mktemp)
    yq e ./configs/k3d-v1alpha2.yaml > ${temp_conf_file}
    
    if ! [ -z ${preset+x} ]
    then
        prepare_preset_config "${preset}"
    fi

    for key in "${!input_opts[@]}";
    do
        if ! [ -z ${!key+x} ]
        then
            merge_yaml "./configs/${key}/${!key}.yaml"
        fi
    done

    if ! [ -z ${config+x} ] && [ -f "${config}" ]
    then
        merge_yaml ${config} 
    fi

    pretty_print "Configuration: " ${fg_magenta}
    pretty_print "--------------" ${fg_magenta}
    yq e -C ${temp_conf_file}
    pretty_print "================================================================================" ${fg_magenta}
}

# DESC: Create new k3d cluster
# ARGS: None
# OUTS: None
function create_cluster() {
    pretty_print "================================================================================" ${fg_cyan}
    pretty_print "Setting up and starting ${name} cluster" ${fg_cyan}
    if test -f "${temp_conf_file}"
    then
        k3d cluster create ${name}
    else
        k3d cluster create ${name} --config "${temp_conf_file}"
    fi
    pretty_print "================================================================================" ${fg_cyan}
}

# DESC: Cleanup after cluster create
# ARGS: None
# OUTS: None
function cleanup() {
    if  [ ! -z ${temp_conf_file+x} ] && [ -f "${temp_conf_file}" ]
    then
        rm ${temp_conf_file}
    fi
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

source "$(dirname "${BASH_SOURCE[0]}")/presets.sh"

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi

