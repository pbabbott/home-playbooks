#!/bin/bash

# BEGIN ANSIBLE MANAGED BLOCK
# END ANSIBLE MANAGED BLOCK

dt=$(date)
echo "Current time is: $dt"

tar -czvf $dest $path

echo "✔️ Tar complete."
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

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

rm $dest

echo "✔️ Deleted file $dest from host."
