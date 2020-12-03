#!/bin/bash

# Generates a bundle image and custom registry image 
#

# -- Args ---
#
# -r Remote registry server/namespace.  (Default: quay.io/open-cluster-management)
# -b image Name  (Default: klusterlet-bundle)
# -t image Tag (Default: 0.3.0)
# -P Push the image (switch)
#
# For backward compatibility with initial version of this script (deprecated):

me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))
top_dir=$(readlink  -f $my_dir/..)
upstream_dir="$top_dir/upstream"

opt_flags="r:b:c:t:P"

image_tag=""
dash_p_opt=""

while getopts "$opt_flags" OPTION; do
   case "$OPTION" in
      r) remote_rgy_and_ns="$OPTARG"
         ;;
      b) bundle_image_name="$OPTARG"
         ;;
      c) catalog_image_name="$OPTARG"
         ;;
      t) image_tag="$OPTARG"
         ;;
      P) dash_p_opt="-P"
         ;;
      ?) exit 1
         ;;
   esac
done
shift "$(($OPTIND -1))"

echo "##### $remote_rgy_and_ns"
echo "##### $catalog_image_name"
echo "##### $dash_p_opt"
echo "##### $1"
exit 0
bundle_vers="$1"
if [[ -z "$bundle_vers" ]]; then
   >&2 echo "Error: Bundle version (x.y.z[-iter]) is required."
   exit 1
fi

remote_rgy_and_ns="${remote_rgy_and_ns:-quay.io/open-cluster-management}"
bundle_image_name="${bundle_image_name:-klusterlet-bundle}"
catalog_image_name="${catalog_image_name:-klusterlet-custom-registry}"


if [[ "$image_tag" = "" ]]; then
   image_tag="$bundle_vers"
fi

# -- End Args --

old_IFS=$IFS
IFS=. rel_xyz=(${bundle_vers%-*})
rel_x=${rel_xyz[0]}
rel_y=${rel_xyz[1]}
rel_z=${rel_xyz[2]}
IFS=$old_IFS

cur_release="release-$rel_x.$rel_y"
release_version=$rel_x.$rel_y.$rel_z

# Generate bundle files, include manifest metadata Dockerfile
echo ""
echo "----- [ Generating Bundle Files ] -----"
echo ""

$top_dir/generate-bundle-files.sh -r $cur_release
if [[ $? -ne 0 ]]; then
   >&2 echo "ABORTING! Could not generate bundle files."
   exit 2
fi

# Replace image tag to image digist
echo ""
echo "----- [ Pinning image for Bundle Manifests ] -----"
echo ""

image_manifest_path="${upstream_dir}/image-manifest/${release_version}.json"
$upstream_dir/image-pinning/pinning-image.sh $image_manifest_path
if [[ $? -ne 0 ]]; then
   >&2 echo "ABORTING! Could not replace image."
   exit 2
fi

# backup current bundle files
rm -rf $upstream_dir/$release_version
mkdir $upstream_dir/$release_version
cp -r $top_dir/manifests $upstream_dir/$release_version/
cp -r $top_dir/metadata $upstream_dir/$release_version/
cp $top_dir/Dockerfile $upstream_dir/$release_version/

# Generate bundle image and push it 
echo ""
echo "----- [ Generating Bundle Image] -----"
echo ""

$upstream_dir/bundle-image/build-bundle-image.sh $dash_p_opt -r $remote_rgy_and_ns -b $bundle_image_name -t $image_tag
if [[ $? -ne 0 ]]; then
   >&2 echo "ABORTING! Could not generate bundle image."
   exit 2
fi

# Generate Custom registry image
echo ""
echo "----- [ Generating Custom Registry Image ] -----"
echo ""

$upstream_dir/custom-registry-image/build-custom-registry-image.sh $dash_p_opt -r $remote_rgy_and_ns -b $bundle_image_name -c $catalog_image_name -t $image_tag
if [[ $? -ne 0 ]]; then
   >&2 echo "ABORTING! Could not generate custom registry image."
   exit 2
fi
