k3d Development Cluster Setups
==============================

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository maintain various configurations that will be helpful in the bring up a K8s cluster for development using k3d.

- [Prerequisite](#Prerequisite)
- [Usage](#usage)
- [License](#license)

Prerequisite
------------
- Docker    - https://docs.docker.com/get-docker/
- k3d       - https://k3d.io/#installation

Usage
--------------
Clusters can be created by executing the `create.sh` script. If script is run whitout any input parameters, then the default K3d cluster will be created.

 - Configuration file:

    A predefined configuration can be selected by specifying the -c \<configuration file name\>. 
  
    ```bash
    ./create.sh -c cluster-1-server-1-agent.yaml
    ```
    Script will load the configurations from the config directory. Config files can also be placed in any of the sub directies of the config directories, in this case relative path of config file to config directories should be passed as paramter

    ```bash
    ./create.sh -c registry-mirror/cluster-1-server-with-registry-mirros.yaml
    ```
    This script can also load configuration from a external directory by using the -c flag.

    ```bash
    ./create.sh -c ../newconf/cluster-1-server-with-registry-mirros.yaml
    ```
    or 

    ```bash
    ./create.sh -c /tmp/cluster-1-server-with-registry-mirros.yaml
    ```

- Cluster Name: 

    The name of the cluster can be set using -n paramter. If the script is run with a configuration file, then cluster name in the configuration file will be overridden. Since k3d prefix 'k3d-' to cluster name, the actual cluster name will be always k3d-\<cluster name\>
    ```bash
    ./create.sh -n arun-k8s
    ```

License
-------

All content is licensed under the terms of [The MIT License](LICENSE).
