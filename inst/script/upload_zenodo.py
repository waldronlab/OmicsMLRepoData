#!/usr/bin/env python
"""
File:  upload_zenodo.py
History:  28-Jul-2024
Author: Kai Gravel-Pucillo

Creates a new file deposition to Zenodo,
updating an existing deposition if deposition_id is provided.
"""
import argparse
import requests
import sys
import json


def main():
    """Business logic"""

    # Get arguments
    args = get_cli_args()
    depo_id = args.depo_id
    path = args.path
    filename = path.split("/")[-1]

    # Hard-code access token
    access_token = "kNpvCCllUYwdEG33hJUTwlEmCzlLJkErS1HX9gg0bqE56qQuBrseUyn5bZ3e"
    params = {'access_token': access_token}
    # Test access token
    r = requests.get('https://zenodo.org/api/deposit/depositions',
                     params={'access_token': access_token})
    # Exit with error if access token invalid
    if r.status_code != 200:
        print("Access token invalid")
        sys.exit(1)

    # Determine whether to update existing deposition or create new deposition
    if depo_id:
        # If depo_id is present, update existing deposition
        print(f"Deposition ID '{depo_id}' detected. Updating published file version.")
        deposition_id = update_version(depo_id, access_token)
    else:
        # If depo_id is absent, create new deposition
        print("No deposition ID detected. Creating new file publication.")
        deposition_id = upload_new_file(params, filename, path)

    # Hard-code metadata
    data = {
        'metadata': {
            'title': 'My first upload',
            'upload_type': 'poster',
            'description': 'Test upload of example data',
            'creators': [{'name': 'G-P, Kai',
                          'affiliation': 'RF CUNY'}]
        }
    }
    # Upload metadata
    r = requests.put(f'https://zenodo.org/api/deposit/depositions/{deposition_id}',
                     params={'access_token': access_token}, data=json.dumps(data))

    # Exit with error if metadata is invalid
    if r.status_code != 200:
        print("Error in Metadata. Check that upload_type and other fields are valid.")
        sys.exit(1)

    # Publish Upload
    r = requests.post(f'https://zenodo.org/api/deposit/depositions/{deposition_id}/actions/publish',
                      params={'access_token': access_token})

    # Print version ID
    print(f"New upload deposition ID: {deposition_id}")


def get_cli_args():
    """Return parsed command-line arguments"""

    parser = argparse.ArgumentParser(
        description="Provide details for the file to upload and your Zenodo access token.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('--path',
                        help='The path to the file you are uploading',
                        metavar='PATH',
                        type=str)

    parser.add_argument('--depo_id',
                        help='The deposition_id of the existing file in Zenodo',
                        metavar='DEPO',
                        type=str)

    return parser.parse_args()


def upload_new_file(params, filename, path):
    """Upload a new file (version 1)"""

    # Create Empty File Upload
    r = requests.post('https://zenodo.org/api/deposit/depositions',
                      params=params,
                      json={})

    # Upload File
    bucket_url = r.json()["links"]["bucket"]
    deposition_id = r.json()['id']

    with open(path, "rb") as fp:
        r = requests.put(f"{bucket_url}/{filename}",
            data=fp,
            params=params)
    r.json()

    return deposition_id


def update_version(deposition_id, access_token):
    """Post the updated version of your file using a new deposition_id"""

    # Create a new version of the deposition
    r = requests.post(f'https://zenodo.org/api/deposit/depositions/{deposition_id}/actions/newversion',
                      params={'access_token': access_token})

    # Extract the new url to the updated deposition version
    newversion_draft_url = r.json()['links']['latest_draft']

    # Extract the new deposition_id
    deposition_id = newversion_draft_url.split('/')[-1]

    return deposition_id


if __name__ == "__main__":
    main()
