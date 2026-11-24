"""App Store Connect API access shared by the workflow scripts.

Reads ASC_KEY_ID, ASC_ISSUER_ID and KEY_PATH from the environment. Never prints them.
"""
import base64, json, os, subprocess, time, urllib.error, urllib.request

API = "https://api.appstoreconnect.apple.com"


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_token(key_id: str, issuer: str, key_path: str) -> str:
    """A ten-minute ES256 JWT for the API, signed with the .p8 key through openssl."""
    now = int(time.time())
    header = _b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = _b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 600,
                                  "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{payload}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input,
                         capture_output=True, check=True).stdout

    # Convert the DER ECDSA signature to the raw r||s form JWT expects.
    def read_int(buf, i):
        assert buf[i] == 0x02
        n = buf[i + 1]
        return int.from_bytes(buf[i + 2:i + 2 + n], "big"), i + 2 + n
    r, i = read_int(der, 2)
    s, _ = read_int(der, i)
    return f"{header}.{payload}.{_b64url(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


def token_from_env() -> str:
    return make_token(os.environ["ASC_KEY_ID"].strip(), os.environ["ASC_ISSUER_ID"].strip(),
                      os.environ["KEY_PATH"])


def call(method: str, url: str, token: str, attempts: int = 3):
    """Sends one request and returns the decoded JSON body, or None if there is none.

    Retries network errors, 429 and 5xx. Raises urllib.error.HTTPError for other failures.
    """
    if url.startswith("/"):
        url = API + url
    if not url.startswith(API + "/"):
        # Paging links come from the response; the token only ever goes to Apple.
        raise ValueError("refusing to send the API token to another host")
    for attempt in range(1, attempts + 1):
        req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {token}"})
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                body = resp.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or attempt == attempts:
                raise
        except urllib.error.URLError:
            if attempt == attempts:
                raise
        time.sleep(5 * attempt)
