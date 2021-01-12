
# Assumes: Python 3.6+

#import yaml
from ruamel.yaml import YAML
import json

yaml = YAML()

# Load a manifest (YAML) file.
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

# Get community version from csv file   
def get_community_version(pathn):
   klusterlet_csv = load_manifest(pathn)
   # the csv name should be klusterlet.x.x.x 
   csv_version = klusterlet_csv["spec"]["version"]
   return csv_version

# Get product version which save in community_to_product_version config file
def get_product_version(config, community_version):
   with open(config, "r", encoding="UTF-8") as file:
      obj = json.load(file)
   return obj[community_version]

# dump_manifest will change format of annotation and describe in csv, so do no use it.
def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return


def update_skip_replaces(klusterlet_csv,cur_product_version,previous_operator_version):
   cur_rel_version = cur_product_version.split('.')
   if cur_product_version =="2.2.0" :
      # 2.2.0 is the first release of this image
      del klusterlet_csv["spec"]["replaces"]
      return
   if len(previous_operator_version) == 0:
      if cur_rel_version[2] =="0":
         # This is the second or subsequent feature release of a major version, i.e.
         # 2.1.0, 2.2.0, etc.
         #
         # It has no single immediate predecessor but should be an upgrade from any
         # release (iniitial or patch) of the prior feature release.
         #
         # Hence, it has no replaces property but does have a skip range.
         del klusterlet_csv["spec"]["replaces"]
         klusterlet_csv["metadata"]["annotations"]["olm.skipRange"] = ">="+cur_rel_version[0]+"."+str(int(cur_rel_version[1])-1)+".0 <"+cur_rel_version[0]+"."+cur_rel_version[1]+".0"
         return
      elif cur_rel_version[1] =="0":
         # This is a z-stream/patch release of the first feature release of a major
         # version, i.e. 3.0.1, 3.0.2.
         #
         # Its predecessor is simply the z-1 release of the same x.y feature release. Since this is
         # in the z-stream of the first feature release, there is no need for a skipRange to handle
         # upgrade from a prior feature release.
         klusterlet_csv["spec"]["replaces"] = "klusterlet-product.v"+cur_rel_version[0]+"."+cur_rel_version[1]+"."+str(int(cur_rel_version[2])-1)
         return
      else:
         # 2.2.0 -> 2.2.1
         klusterlet_csv["spec"]["replaces"] = "klusterlet-product.v"+cur_rel_version[0]+"."+cur_rel_version[1]+"."+str(int(cur_rel_version[2])-1)
         klusterlet_csv["metadata"]["annotations"]["olm.skipRange"] = ">="+cur_rel_version[0]+"."+str(int(cur_rel_version[1])-1)+".0 <"+cur_rel_version[0]+"."+cur_rel_version[1]+".0"
   else:
      pre_rel_version = previous_operator_version.split('.')
      if pre_rel_version[0]==cur_rel_version[0] and pre_rel_version[1]==cur_rel_version[1]:
         # z stream upgrade 2.2.0 -> 2.2.1
         klusterlet_csv["spec"]["replaces"]="klusterlet-product.v"+previous_operator_version
         klusterlet_csv["metadata"]["annotations"]["olm.skipRange"] = ">="+cur_rel_version[0]+"."+pre_rel_version[1]+".0 <"+cur_rel_version[0]+"."+cur_rel_version[1]+".0"
      elif pre_rel_version[0]==cur_rel_version[0] and pre_rel_version[1]!=cur_rel_version[1]:
         # y stream upgrade 2.2.x -> 2.3.x
         del klusterlet_csv["spec"]["replaces"]
         klusterlet_csv["metadata"]["annotations"]["olm.skipRange"] = ">="+cur_rel_version[0]+"."+pre_rel_version[1]+".0 <"+cur_rel_version[0]+"."+cur_rel_version[1]+".0"
      else:
         #x stream upgrade, do not depend previous release
         del klusterlet_csv["spec"]["replaces"]

# update csv and return csv version
def update_csv(csv_pathn, config, previous_operator_version):
   klusterlet_csv = load_manifest(csv_pathn)
   csv_version = klusterlet_csv["spec"]["version"]
   
   product_version = get_product_version(config,csv_version)
   
   # Update csv version to product version
   klusterlet_csv["spec"]["version"]=product_version
   klusterlet_csv["metadata"]["name"]="klusterlet-product.v"+product_version

   #Handle replaces and skip fileds
   update_skip_replaces(klusterlet_csv,product_version,previous_operator_version)

   dump_manifest(csv_pathn,klusterlet_csv)
   return product_version
