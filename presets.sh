#!/usr/bin/env bash

presets=( /
'k3d-default' /         #The default configuration of k3d
'k3d-sample-conf' /     #The sample configuration in k3d site
'single-node-dev' /     #Single node development cluster (no treafik)
'two-node-dev' /        #Two node development cluster (1 server 2 agents with no traefik)
'three-node-dev' /      #Three node development cluster (1 server 3 agents with no traefik)
)

#Different useful presets for k3d cluster are maintained here

# DESC: Check whether the preset is valid one
# ARGS: None
# OUTS: None
function check_valid_preset() {
    #TODO This logic need to be updated as more and more preset start getting added to it
    preset=$1
    if ! [[ ${presets[*]} =~ (^|[[:space:]])"${preset}"($|[[:space:]]) ]]
    then
        pretty_print "Preset - ${preset} does not exist" ${fg_red} 
        script_exit ""
    fi
    
}

# DESC: Prepate the preset config
# ARGS: None
# OUTS: None
function prepare_preset_config() {
    preset=$1
    case "${preset}" in
        "k3d-default") 
            merge_yaml ./configs/k3d-default.yaml ;;
        "k3d-sample-conf")
            merge_yaml ./configs/k3d-sample.yaml
            merge_yaml ./configs/servers/1.yaml 
            merge_yaml ./configs/agents/2.yaml 
            merge_yaml ./configs/kubeapi/k3d-sample.yaml 
            merge_yaml ./configs/image/latest.yaml 
            merge_yaml ./configs/network/k3d-sample.yaml 
            merge_yaml ./configs/token/k3d-sample.yaml 
            merge_yaml ./configs/volumes/k3d-sample.yaml 
            merge_yaml ./configs/ports/k3d-sample.yaml 
            merge_yaml ./configs/labels/k3d-sample.yaml 
            merge_yaml ./configs/env/k3d-sample.yaml 
            merge_yaml ./configs/registries/k3d-sample.yaml 
            merge_yaml ./configs/options/k3d-sample.yaml 
            ;;
        "single-node-dev") 
            prepare_single_node_dev_config 
            ;;
        "three-node-dev") 
            prepare_single_node_dev_config
            merge_yaml ./configs/agents/3.yaml 
            ;;
        "two-node-dev") 
            prepare_single_node_dev_config
            merge_yaml ./configs/agents/2.yaml 
            ;;
    esac
}

# DESC: Prepate the preset config
# ARGS: None
# OUTS: None
function prepare_single_node_dev_config() {
    merge_yaml ./configs/servers/1.yaml 
    merge_yaml ./configs/agents/0.yaml 
    merge_yaml ./configs/kubeapi/dev.yaml 
    merge_yaml ./configs/image/latest.yaml 
    merge_yaml ./configs/token/k3d-sample.yaml 
    merge_yaml ./configs/volumes/dev.yaml 
    merge_yaml ./configs/ports/8080-8443.yaml 
    merge_yaml ./configs/registries/dev.yaml 
    merge_yaml ./configs/options/dev.yaml    
}

