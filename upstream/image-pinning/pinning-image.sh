#!/bin/bash

me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))
top_dir=$(readlink  -f $my_dir/../..)

image_manifest_path="$1"
if [[ -z "$image_manifest_path" ]]; then
   >&2 echo "Error: image manifest file is required."
   exit 1
fi

pwd=`pwd`

# use python script to get new image url
cd $my_dir
image_url=`python -c 'import load_image_info; print(load_image_info.get_image_url('\"${image_manifest_path}\"',"registration-operator"))'`
echo $image_url
if [ "${image_url}" = "" ]; then
  >&2 echo "Error: Failed to get image url."
  >&2 echo "Aborting."
  exit 2
fi

origin_image_url="quay.io/open-cluster-management/registration-operator:latest"

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

cd $pwd