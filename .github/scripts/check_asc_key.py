"""Checks the App Store Connect API key secrets before archiving.

Prints only shapes and Apple's response, never the secret values.
"""
import os, re, sys, urllib.error, urllib.request

from asc_api import make_token

key_id = os.environ.get("ASC_KEY_ID", "")
issuer = os.environ.get("ASC_ISSUER_ID", "")
key_path = os.environ["KEY_PATH"]
problems = []

if key_id != key_id.strip() or issuer != issuer.strip():
    problems.append("ASC_KEY_ID or ASC_ISSUER_ID has leading/trailing whitespace")
key_id, issuer = key_id.strip(), issuer.strip()
if not re.fullmatch(r"[A-Z0-9]{10}", key_id):
    problems.append(f"ASC_KEY_ID should be 10 uppercase letters/digits (got {len(key_id)} chars)")
if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", issuer):
    problems.append(f"ASC_ISSUER_ID should be a UUID like 57246542-96fe-1a63-e053-0824d011072a (got {len(issuer)} chars)")
pem = open(key_path, "rb").read()
if b"-----BEGIN PRIVATE KEY-----" not in pem:
    problems.append("ASC_KEY_P8_BASE64 does not decode to a .p8 private key")

for p in problems:
    print(f"::error::{p}")
if problems:
    sys.exit(1)

token = make_token(key_id, issuer, key_path)

req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/apps?limit=1",
                             headers={"Authorization": f"Bearer {token}"})
try:
    with urllib.request.urlopen(req) as resp:
        print(f"App Store Connect accepted the key (HTTP {resp.status}).")
except urllib.error.HTTPError as e:
    print(f"::error::App Store Connect rejected the key (HTTP {e.code}): {e.read().decode()[:500]}")
    print("Check that ASC_KEY_ID matches the .p8 file, that ASC_ISSUER_ID is the Issuer ID above the "
          "Team Keys table, and that the key is a Team key (not an Individual key).")
    sys.exit(1)
