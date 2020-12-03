#!/usr/bin/env python3
# Assumes: Python 3.6+

import json

# Load a json file.
def load_json(pathn):
   try:
      with open(pathn, "r") as f:
         return json.load(f)
   except FileNotFoundError:
      print("File not found" + pathn)

def get_image_url(image_manifest_pathn,repo_name):
   image_manifest_list = load_json(image_manifest_pathn)
   
   for entry in image_manifest_list:
      if entry["image-name"] == repo_name:
         new_image_url = entry["image-remote"]+"/"+entry["image-name"]+"@"+entry["image-digest"]
         return new_image_url
   return ""

