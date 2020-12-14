
# Assumes: Python 3.6+

import yaml

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

def get_version(pathn):
   klusterlet_csv = load_manifest( pathn)
   
   # the csv name should be klusterlet.x.x.x 
   csv_version = klusterlet_csv["metadata"]["name"][11:]
   return csv_version
