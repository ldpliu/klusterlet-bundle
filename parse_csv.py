
# Assumes: Python 3.6+

import yaml
import json

yaml_loader = yaml.SafeLoader

# Load a manifest (YAML) file.
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f, yaml_loader)
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
      yaml.dump(manifest, f, width=100, default_flow_style=False, sort_keys=False)
   return

# update csv and return csv version
def update_csv(csv_pathn, config, previous_operator_version):
   klusterlet_csv = load_manifest(csv_pathn)
   csv_version = klusterlet_csv["spec"]["version"]
   
   product_version = get_product_version(config,csv_version)
   
   # Update csv version to product version
   klusterlet_csv["spec"]["version"]=product_version
   klusterlet_csv["metadata"]["name"]="klusterlet.v"+product_version

   #Handle replaces filed
   if len(previous_operator_version)==0:
      del klusterlet_csv["spec"]["replaces"]

   dump_manifest(csv_pathn,klusterlet_csv)
   return product_version
