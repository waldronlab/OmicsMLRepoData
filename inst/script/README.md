
# upload_zenodo

## Overview

Upload a new file to Zenodo or update an existing file in Zenodo. 

## Authors

Kai Gravel-Pucillo
  
## Getting Started

First, hard-code your Zenodo access token into the upload_zenodo.py script in the corresponding space on line 26.
Next, hard-code the relevant metadata for your file upload into the upload_zenodo.py script in the corresponding
spaces on lines 48-54. 

Be sure to specify an approved upload type from the list provided here: https://instruct-eric.org/help/other/zenodo-upload-guidelines

All metadata for a file can be changed in uploads of subsequent versions, however changing the 'upload type' from an
approved type to an unapproved type will result in the creation of a draft version that cannot be published, and all
future versions will be blocked from publication until this draft version is published.

Refer to the following Zenodo page to learn about optional metadata categories not currently included in the script:
https://help.zenodo.org/docs/deposit/describe-records/

## Running the Script

From the command line, navigate to the directory containing the "upload_zenodo.py" script and run the follow command:

`Python .\upload_zenodo.py --path <file_path>`

where "<file_path>" is the path to the file you intend to upload.

The following optional argument can be applied:

- `--depo_id` A string of eight numbers representing the deposition ID of the most recent version of the published file you intend to update. Only include this argument if you are updating the version of an already published file. The deposition ID is found by navigating to the published file's page and selecting the eight-digit serial number at the end of the DOI for the newest version of the file.

For example, to update a published file to a new version, one could input the following command:

`Python .\upload_zenodo.py --path ./data/test_file.csv --depo_id 12345678`
