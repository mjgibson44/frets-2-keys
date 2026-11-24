# TestFlight certificate fix: what's left

Written on 2026-11-24 for whoever picks this up next. Delete this file once the steps below are done.

## Where things stand

The TestFlight workflow (`.github/workflows/testflight.yml`) stopped working on 2026-11-24. Run [45508679045](https://github.com/mjgibson44/frets-2-keys/actions/runs/45508679045) failed in Archive on both platforms with "Your account has reached the maximum number of certificates".

The cause: every job runs on a fresh runner with no signing identity, so Xcode creates a new Apple Development certificate, named "Created via API", to sign the archive. Nothing removed them. Seven earlier jobs got past Archive, so about seven are on the account.

[PR #12](https://github.com/mjgibson44/frets-2-keys/pull/12) changes the workflow so each job revokes the certificate it created. It is merged. **It has not been through a real run**, and the old certificates are still on the account, so the workflow will keep failing until they are revoked.

Nothing has been revoked on the account so far, and no run has been started since the failure.

## How the fix works

- The step "Record existing certificates" runs before Archive and saves the ID of every certificate on the account.
- The step "Revoke this job's certificate" runs at the end, even if the job failed. It revokes a certificate only if all three are true:
  1. it was not on the account when the job recorded them;
  2. its type is `DEVELOPMENT`, `IOS_DEVELOPMENT` or `MAC_APP_DEVELOPMENT`;
  3. its SHA-1 appears in `security find-identity` on the runner, meaning the runner holds its private key.
- Both steps call `.github/scripts/asc_certificates.py`. It shares the API code in `.github/scripts/asc_api.py` with `check_asc_key.py`.

The workflow never revokes a certificate left by an earlier run. That is deliberate: it cannot prove such a certificate is its own.

## Steps to finish

### 1. Revoke the leftover certificates

This is done by hand in the Apple Developer portal. It cannot be undone, so show the owner the exact list and get a yes before revoking anything.

1. Open <https://developer.apple.com/account/resources/certificates/list>. The owner said on 2026-11-24 that they were already signed in in another session. If a sign-in page appears, the owner has to sign in; do not enter credentials for them.
2. List every certificate with its name, type and expiry date.
3. The ones to revoke have type **Development** and name **Created via API**. Expect about seven. They were created on 2026-10-15 and 2026-11-24, so their expiry dates should fall a year after those days. Treat one that doesn't fit as a question for the owner, not as a candidate.
4. Leave everything else: distribution certificates, anything marked "Managed", and any certificate in the owner's own name.
5. After the owner confirms the list, open each certificate and choose Revoke.

### 2. Run the workflow once for iOS

A run uploads a real build to App Store Connect. Ask the owner before starting one.

```bash
gh workflow run testflight.yml --ref main -f platform=iOS
```

When it finishes, read what the two new steps printed:

```bash
gh run view <run-id> --log | grep -E "Recorded the|since the snapshot|Revoked|Leaving|left alone|already gone|warning|error"
```

A good run prints these lines:

- `Recorded the N certificate(s) already on the account (M development). None of these will be revoked.`
- `Development certificates created since the snapshot: 1. Created on this runner: 1.`
- `Revoked DEVELOPMENT certificate <id>, created by this job.`

Then reload the certificates page and check that no "Created via API" certificate is left.

### 3. If the run does not look like that

| What the log shows | What it means | What to do |
| --- | --- | --- |
| Archive fails again with "maximum number of certificates" | Not enough certificates were revoked in step 1. | Revoke the rest and run again. |
| `Created on this runner: 0` and a warning about a signing identity that matches no new certificate | The runner has the certificate, but the script did not match it. Either Apple reports a type outside the three listed, or the fingerprint comparison is wrong. | Look for the line `Also new since the snapshot, and left alone: <types>`. If it names the type Xcode used, add it to `DEVELOPMENT_TYPES` in `asc_certificates.py`. Revoke that run's certificate by hand. |
| `Created on this runner: 0` and no warning | The certificate Xcode created is not visible to `security find-identity`. | Add a temporary step after Archive that prints the count of identities, find where Xcode put the key, and fix `keychain_identities()`. Revoke that run's certificate by hand. |
| `Could not revoke certificate ... (HTTP 403 ...)` | The API key may not revoke certificates. | Check that the key still has the Admin role. Revoke by hand. |
| The snapshot step fails | The key cannot list certificates, or Apple was unreachable. | Read the error. Archive did not run, so no certificate was created. |

### 4. Run it for both platforms

After iOS works, ask the owner again and run with `-f platform=both`. The two jobs run at the same time, and this case has only been tested against a fake server. Each job should print `Created on this runner: 1` and revoke one certificate. A job may also print `Leaving 1 alone: not created on this runner`, which is the other job's certificate and is expected.

### 5. Tidy up

- Tick the two certificate items under "App Store Connect setup" in `RELEASE_CHECKLIST.md`, and update its "Notes for the next session".
- Delete this file.

## Things to know

- The repository is public, so workflow logs are public. The scripts print counts, certificate types and certificate IDs only. Keep it that way: no key material, and no names beyond what is already there.
- If a job is killed before the revoke step runs, its certificate stays on the account and has to be revoked by hand.
- Revoking a development certificate invalidates the Xcode-managed development profile that included it. Xcode regenerates that profile on the next automatically signed build, in CI or on the owner's Mac.
- The scripts were tested locally against a fake App Store Connect server with a throwaway key (16 checks, Python 3.14 and 3.9). That test script was not committed.
- An approach that creates no certificate at all, archiving unsigned and signing only at export, was not used. Export takes the app's entitlements from the archive's signature, and nobody has confirmed that the iCloud key-value entitlement and the Mac sandbox entitlement survive an unsigned archive.
