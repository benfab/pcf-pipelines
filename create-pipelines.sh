#!/bin/bash

CCI_ENDPOINT=http://10.0.0.42:25555/
CCI_PASSWORD=purple80Sheep

# login to Concourse
fly -t zero login -c ${CCI_ENDPOINT} -u admin -p ${CCI_PASSWORD}

# Destroy urgade ERT pipeline
fly -t zero destroy-pipeline -p upgrade-ert

# Create upgrade ERT pipeline
fly -t zero sp -c upgrade-ert/pipeline.yml -p upgrade-ert -l upgrade-ert/params.yml

# Destroy PCF pipeline
fly -t zero destroy-pipeline -p install-pcf 

# Create install PCF pipeline
fly -t zero sp -c install-pcf/vsphere/pipeline.yml -p install-pcf -l install-pcf/vsphere/params.yml

