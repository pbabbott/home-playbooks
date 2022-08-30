#!/bin/bash

# BEGIN ANSIBLE MANAGED BLOCK
# END ANSIBLE MANAGED BLOCK


tar -czvf $dest $path

az login --service-principal -u $username -p $password --tenant $tenant

name=$(basename $dest)

az storage blob upload \
    --account-name sthomebackup001 \
    --container-name rpi001 \
    --name $name \
    --file $dest \
    --overwrite \
    --auth-mode login
