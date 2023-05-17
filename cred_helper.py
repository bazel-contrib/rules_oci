#!/usr/bin/env python3

import sys
import json
import logging.config
import urllib.parse
import subprocess
import base64
import requests
import www_authenticate


# constants
ACCEPT = [ "text/html", "image/gif", "image/jpeg", "*/*" ]
DOCKER_MEDIA_TYPES = ["application/vnd.docker.distribution.manifest.list.v2+json", "application/vnd.docker.distribution.manifest.v2+json"]
OCI_MEDIA_TYPES = ["application/vnd.oci.image.index.v1+json", "application/vnd.oci.image.manifest.v1+json"]

# setup logging
logging.basicConfig(filename='auth.log', level= 10)
logger = logging.getLogger('Auth')

# authorization
headers = {
    "Accept": [",".join(DOCKER_MEDIA_TYPES + OCI_MEDIA_TYPES + ACCEPT)],
    "Authorization": []
}

payload = json.loads(sys.stdin.read())
if payload["uri"] == "https://webhook.site/30dfcda1-3647-4ad5-bf3e-ddd11cf1813a":
    payload["uri"] = "https://index.docker.io/v2/library/debian/manifests/latest"


parsed = urllib.parse.urlparse(payload["uri"])
url = parsed.netloc
if url == "":
    url = parsed.path
logger.info(payload)

# ask crane for now
token = None
crane = subprocess.Popen(
    ['crane', 'auth', 'get'],
    stdin=subprocess.PIPE, 
    stdout=subprocess.PIPE, 
    stderr=subprocess.PIPE,
)
crane.stdin.write(url.encode())
stdout, stderr = crane.communicate()
output = stdout.strip()
if crane.returncode == 0:
    output_json = json.loads(output)
    token = base64.urlsafe_b64encode("{}:{}".format(output_json["Username"], output_json["Secret"]).encode()).decode()
else:
    logger.info("{} {}".format(stderr, stdout))

r = requests.get("https://{}/v2".format(url))
if r.status_code == 401 and 'www-authenticate' in r.headers and token:
    www_authenticate_header = r.headers['www-authenticate']
    challenges = www_authenticate.parse(www_authenticate_header)
    auth_url = "{realm}?scope={scope}&service={service}".format(
        realm = challenges["bearer"]["realm"],
        service = challenges["bearer"]["service"],
        scope = "repository:{}:pull".format("library/debian")
    )
    ar = requests.get(auth_url)
    resp = ar.json()
    logger.info(resp)
    headers["Authorization"] = ["Bearer {}".format(resp["token"])]
else:
    headers["Authorization"] = ["Basic {}".format(token)]
logger.info(headers)
print(json.dumps({"headers": headers}))
