#!/bin/bash
me=$(basename $0)
my_dir=$(dirname $(readlink -f $0))
top_dir=$(readlink  -f $my_dir/..)

opm_vers="v1.13.3"
operator_rgy_repo_url="https://github.com/operator-framework/operator-registry"
opm_download_url="$operator_rgy_repo_url/releases/download/$opm_vers/linux-amd64-opm"

# -- Args ---
#
# -t bundle and catalog image tag
# -r Remote registry server/namespace.  (Default: quay.io/open-cluster-management)
# -b Bundle image Name (repo).  (Default: klusterlet-bundle)
# -c Catalog image Name (repo). (Default: klusterlet-custom-registry)
# -P Push image (switch)
#

opt_flags="r:b:c:PJ:"

push_the_image=0

while getopts "$opt_flags" OPTION; do
   case "$OPTION" in
      r) remote_rgy_and_ns="$OPTARG"
         ;;
      b) bundle_image_name="$OPTARG"
         ;;
      c) catalog_image_name="$OPTARG"
         ;;
      P) push_the_image=1
         ;;
      t) bundle_and_catalog_tag="$OPTARG"
         ;;
      ?) exit 1
         ;;
   esac
done
shift "$(($OPTIND -1))"


remote_rgy_and_ns="${remote_rgy_and_ns:-quay.io/open-cluster-management}"
bundle_image_name="${bundle_image_name:-klusterlet-bundle}"
catalog_image_name="${catalog_image_name:-klusterlet-custom-registry}"
bundle_and_catalog_tag="${bundle_and_catalog_tag:-0.3.0}"

bundle_image_ref="$remote_rgy_and_ns/$bundle_image_name:$bundle_and_catalog_tag"
catalog_image_ref="$remote_rgy_and_ns/$catalog_image_name:$bundle_and_catalog_tag"

# Since we currently have only a single DOCKER_USER/PASS pair, we're going to assume
# they are for the registry we push to.  If the source bundles are coming from a
# different registry then we will leave it up to the invoker to do logins to
# those registries before inovking this script.

login_to_image_rgy="$remote_rgy_and_ns"

# Clean up from previous iteration
old_images=$(docker images --format "{{.Repository}}:{{.Tag}}" "$catalog_image_ref")
for img in $old_images; do
   docker rmi "$img" > /dev/null
done

# use upstream as working dir
cd $top_dir/upstream/
rm -rf database etc

if [[ -n $DOCKER_USER ]]; then
   docker login -u=${DOCKER_USER} -p=${DOCKER_PASS} "$login_to_image_rgy"
   if [[ $? -ne 0 ]]; then
      >&2 echo "Error: Error doing docker login to remote registry."
      exit 2
   fi
else
   echo "Note: DOCKER_USER not set, assuming docker login already done."
fi

# As of v1.13.3, "opm index add" countues to be a pain in that it pulls its upstream
# images based on a floating tag (latest), and wose yet produces an image which
# does not run on OCP (Permission denied on /etc/nsswitch.conf).  To circumvent
# we use "opm registry add" ourselves to build the database (this is what the
# "opm index add" command does under the covers, and then generate the image
# oursleves using a patched Dockerfile captured from "opm index add ... --generate".

# Fetch the desired version of OPM

opm="./opm"
curl -Ls -o "$opm" "$opm_download_url"
if [[ $? -ne 0 ]]; then
   >&2 echo "Error: Could not fetch OPM binary from $opm_download_url."
   exit 2
fi
chmod +x "$opm"

# Build registry database
#
# Note:  If your workstation is running podman with the podman-docker compat layer
# rather than genuine docker and you run into 401 Unauthroized errors on opm add,
# you might need this env var in effect:
#
# export REGISTRY_AUTH_FILE=$HOME/.docker/config.json

mkdir "database"

echo "Adding bundle: $bundle_image_ref"
$opm registry add -b "$bundle_image_ref" -d "database/index.db"
if [[ $? -ne 0 ]]; then
   >&2 echo "Error: Could not add bundle to registry database: $bundle_image_ref."
   exit 2
fi


cp "$top_dir/upstream/Dockerfile.index" .
mkdir "etc"
touch "etc/nsswitch.conf"
chmod a+r "etc/nsswitch.conf"

docker build -t "$catalog_image_ref" -f Dockerfile.index \
   --build-arg "opm_vers=$opm_vers" .
if [[ $? -ne 0 ]]; then
   >&2 echo "Error: Could not build custom catalog image $catalog_image_ref."
   exit 2
fi

# Push customer registry image
if [[ $push_the_image -eq 1 ]]; then
   docker push "$catalog_image_ref"
   if [[ $? -ne 0 ]]; then
      >&2 echo "Error: Could not push custom catalog image $catalog_image_ref."
      exit 2
   fi
   echo "Pushed custom catalog image: $catalog_image_ref"
fi

