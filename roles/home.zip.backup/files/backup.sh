#!/bin/bash

# BEGIN ANSIBLE MANAGED BLOCK
# END ANSIBLE MANAGED BLOCK

dt=$(date)
echo "Current time is: $dt"

tar -czvf $dest $path

echo "✔️ Tar complete."
# export HOME=/home/pi
# export PYTHONPATH=/usr/local/lib/python3.9/dist-packages
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo $PATH | tr ":" "\n"

az login --service-principal -u $username -p $password --tenant $tenant

echo "✔️ Login complete."

name=$(basename $dest)

az storage blob upload \
    --account-name sthomebackup001 \
    --container-name rpi001 \
    --name $name \
    --file $dest \
    --overwrite \
    --auth-mode login

echo "✔️ Upload complete."