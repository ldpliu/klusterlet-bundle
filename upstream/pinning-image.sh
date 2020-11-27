#!/bin/bash

me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))
top_dir=$(readlink  -f $my_dir/../..)

echo "${me} me"
echo "${my_dir} mydir "
echo "${top_dir} top_dir "

image_url=$1
origin_image_url="quay.io/repository/open-cluster-management/registration-operator:latest"

csv_path="${top_dir}/manifests/klusterlet.clusterserviceversion.yaml"

# Replace image 
sed "s#${origin_image_url}#${image_url}#g" ${csv_path} > "${top_dir}/temp_file"
if [[ $? -ne 0 ]]; then
  >&2 echo "Error: Failed to replace image from ${origin_image_url} to ${image_url} in file ${csv_path}."
  >&2 echo "Aborting."
  exit 2
fi
mv "${top_dir}/temp_file" ${csv_path}

echo "replaced ${origin_image_url} to ${image_url} in file ${csv_path}"

