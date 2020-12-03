#!/bin/bash

# Generates a bundle image 
#

# -- Args ---
#
# -r Remote registry server/namespace.  (Default: quay.io/open-cluster-management)
# -b image Name  (Default: klusterlet-bundle)
# -t image Tag (Default: 0.3.0)
# -P Push the image (switch)
#
# For backward compatibility with initial version of this script (deprecated):

opt_flags="r:n:t:P:"

push_the_image=0
image_tag=""

while getopts "$opt_flags" OPTION; do
   case "$OPTION" in
      r) remote_rgy_and_ns="$OPTARG"
         ;;
      b) bundle_image_name="$OPTARG"
         ;;
      t) image_tag="$OPTARG"
         ;;
      P) push_the_image=1
         ;;
      ?) exit 1
         ;;
   esac
done
shift "$(($OPTIND -1))"

me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))
top_dir=$(readlink  -f $my_dir/..)


manifests_dir=${top_dir}/manifests
metadata_dir=${top_dir}/metadata

if [[ ! -d "$manifests_dir" ]]; then
   >&2 echo "Error: Input bundle manifests directory does not exist: $manifests_dir"
   exit 2
fi
if [[ ! -d "$metadata_dir" ]]; then
   >&2 echo "Error: Input bundle metadata directory does not exist: $metadata_dir"
   exit 2
fi

remote_rgy_and_ns="${remote_rgy_and_ns:-quay.io/open-cluster-management}"
bundle_image_name="${bundle_image_name:-klusterlet-bundle}"
image_tag="${image_tag:-0.3.0}"


bundle_image_rgy_ns_and_name="$remote_rgy_and_ns/$bundle_image_name"
bundle_image_url="$bundle_image_rgy_ns_and_name:$image_tag"

# Get rid of previous local image if any
images=$(docker images --format "{{.Repository}}:{{.Tag}}" "$bundle_image_rgy_ns_and_name")
for img in $images; do
   docker rmi "$img" > /dev/null
done

echo "Buiding build image ${bundle_image_url}"
# Build the image locally
docker build -t "$bundle_image_url" -f "$top_dir/Dockerfile" $top_dir

if [[ $? -ne 0 ]]; then
   >&2 echo "Error: Could not build klusterlet bundle image."
   exit 2
fi
echo "Succesfully built image locally: $bundle_image_url"


# Push the image to remote registry if requested
if [[ $push_the_image -eq 1 ]]; then
   if [[ -n $DOCKER_USER ]]; then
      remote_rgy=${remote_rgy_and_ns%%/*}
      docker login $remote_rgy -u $DOCKER_USER -p $DOCKER_PASS
      if [[ $? -ne 0 ]]; then
         >&2 echo "Error: Error doing docker login to remote registry."
         exit 2
      fi
   else
      echo "Note: DOCKER_USER not set, assuming docker login already done."
   fi
   docker push "$bundle_image_url"
   if [[ $? -ne 0 ]]; then
      >&2 echo "Error: Failed to push to remote registry."
      exit 2
   fi
   echo "Successfully pushed image: $bundle_image_url"
else
   echo "Not pushing the image."
fi

