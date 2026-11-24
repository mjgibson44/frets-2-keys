"""Stops the TestFlight workflow from leaving signing certificates on the account.

Every job starts on a fresh runner with no signing identity, so Xcode's automatic signing
creates a new Apple Development certificate for the Archive step. Nothing removed it, and
after a handful of runs the account reached Apple's certificate limit and Archive failed.

  snapshot  before Archive: records the IDs of the certificates already on the account
  revoke    at the end of the job: revokes the certificate this job created, and no other

A certificate is revoked only if all three hold:
  - it was not on the account when the snapshot was taken,
  - it is a development certificate, never a distribution one, and
  - its private key is in this runner's keychain, which is only true of a certificate
    that Xcode created on this runner.
The third test is what separates this job's certificate from one that the other platform's
job, running at the same time, or a person created after the snapshot.

Reads CERT_SNAPSHOT (the snapshot file's path) plus the variables asc_api needs.
Prints counts, certificate types and certificate IDs. Never prints key material.
"""
import base64, hashlib, json, os, re, subprocess, sys, urllib.error

from asc_api import call, token_from_env

DEVELOPMENT_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT", "MAC_APP_DEVELOPMENT"}
PORTAL = "https://developer.apple.com/account/resources/certificates/list"


def list_certificates(token):
    certs, url = [], "/v1/certificates?limit=200"
    while url:
        page = call("GET", url, token)
        certs += page["data"]
        url = page.get("links", {}).get("next")
    return certs


def cert_type(cert):
    return cert["attributes"].get("certificateType", "UNKNOWN")


def fingerprint(cert):
    """SHA-1 of the certificate, in the form `security find-identity` prints."""
    content = cert["attributes"].get("certificateContent")
    return hashlib.sha1(base64.b64decode(content)).hexdigest().upper() if content else None


def keychain_identities():
    """SHA-1 fingerprints of the certificates whose private key is in this runner's keychains."""
    out = subprocess.run(["security", "find-identity"], capture_output=True, text=True).stdout
    return set(re.findall(r"\b[0-9A-F]{40}\b", out))


def describe_http_error(e):
    return f"HTTP {e.code}: {e.read().decode(errors='replace')[:300]}"


def snapshot(path):
    certs = list_certificates(token_from_env())
    with open(path, "w") as f:
        json.dump(sorted(c["id"] for c in certs), f)
    development = sum(cert_type(c) in DEVELOPMENT_TYPES for c in certs)
    print(f"Recorded the {len(certs)} certificate(s) already on the account "
          f"({development} development). None of these will be revoked.")
    return 0


def revoke(path):
    if not path or not os.path.exists(path):
        print("No snapshot was taken, so the job stopped before Archive and created no certificate.")
        return 0
    with open(path) as f:
        before = set(json.load(f))

    token = token_from_env()
    new = [c for c in list_certificates(token) if c["id"] not in before]
    new_development = [c for c in new if cert_type(c) in DEVELOPMENT_TYPES]
    local = keychain_identities()
    mine = [c for c in new_development if fingerprint(c) in local]
    print(f"Development certificates created since the snapshot: {len(new_development)}. "
          f"Created on this runner: {len(mine)}.")
    if len(new_development) > len(mine):
        print(f"Leaving {len(new_development) - len(mine)} alone: not created on this runner.")
    if len(new) > len(new_development):
        kinds = sorted(cert_type(c) for c in new if cert_type(c) not in DEVELOPMENT_TYPES)
        print(f"Also new since the snapshot, and left alone: {', '.join(kinds)}.")
    if local and not mine:
        print("::warning::This runner's keychain holds a signing identity that matches no new "
              f"certificate on the account, so nothing was revoked. Check {PORTAL} for a leftover "
              "\"Created via API\" certificate.")

    failed = False
    for cert in mine:
        try:
            call("DELETE", f"/v1/certificates/{cert['id']}", token)
            print(f"Revoked {cert_type(cert)} certificate {cert['id']}, created by this job.")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                print(f"Certificate {cert['id']} is already gone.")
                continue
            failed = True
            print(f"::error::Could not revoke certificate {cert['id']} ({describe_http_error(e)}). "
                  f"Revoke it by hand at {PORTAL}")
    return 1 if failed else 0


def main():
    commands = {"snapshot": snapshot, "revoke": revoke}
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    path = os.environ.get("CERT_SNAPSHOT", "")
    if command not in commands or (command == "snapshot" and not path):
        print("usage: CERT_SNAPSHOT=<file> asc_certificates.py snapshot|revoke")
        return 2
    try:
        return commands[command](path)
    except urllib.error.HTTPError as e:
        print(f"::error::App Store Connect refused the certificates request ({describe_http_error(e)})")
    except urllib.error.URLError as e:
        print(f"::error::Could not reach App Store Connect: {e.reason}")
    if command == "revoke":
        print(f"::error::This job's certificate may still be on the account. Check {PORTAL}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
