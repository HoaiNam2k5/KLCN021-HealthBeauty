# Gemini spa assistant — 2026-10-28

The API assistant is deployed to EC2; Flutter changes are in the local DEV source and require a new run/build on the user's device.

## Behavior

- Home has an AI assistant button and the confirmed hotline 1900 8888. The buttons hide when scrolling the home content and return at the top. The hotline sheet opens the phone dialer or copies the number. No unconfirmed opening hours are displayed.
- Assistant requires authentication, supports recent conversation context and retry, and discloses that messages go to Gemini and advice is informational. It does not place appointments automatically.
- `POST /api/v1/assistant/chat` accepts `message` and optional six-message history. It enforces bounds and an account rate limit. The response contains generated advice plus service/combo/package identifiers. Only active catalog IDs are retained; prices, durations and package validity are formatted from database records. The app links services and combos to booking, and packages to the package catalog.
- Gemini advice can be inaccurate; guardrails and a disclaimer do not replace professional advice. Catalog selection is capped at 200 services, 100 combos and 100 packages.

## Production deployment

- API release `20261028-gemini-assistant`: new image `healthbeauty-api:lifecycle-20261028081339`, API container `a9a2d270afeb`.
- Only API was recreated. Web `2bceba0979a5`, SQL Server `76010c7d5135` and Caddy `41d1609bf828` retained their prior containers. Existing runtime environment, mounts, JWT, SQL, SePay, Cloudinary, application settings and nginx were checked.
- Gemini key was read from the user's local `D:/KhoaLuan/keygemini.txt` without displaying it, sent via SSH, and stored on EC2 in the new private release environment file with permission 600. It was not embedded in source, Git, mobile app or image layers. Never print the environment file or Docker inspect output.
- The API reads `Gemini__ApiKey`; optional `Gemini__Model` defaults to `gemini-3.5-flash-lite`, with `Gemini__TimeoutSeconds` optional. The key/model was verified directly from EC2 with one non-sensitive request: HTTP 200 and structured response valid.
- Two overrides are appended after the existing full Compose chain: `/home/ubuntu/demo-api/compose.release.20261028-gemini-assistant.yaml` for image and `/home/ubuntu/demo-api/compose.release.20261028-gemini-env.yaml` for the private environment file. Preserve both and all prior SePay/Cloudinary overrides in future releases.
- No database scripts, database writes, SQL restore, volume removal, Web deployment or GitHub push.

The first model check accidentally extracted only a suffix from a key containing a period and returned API_KEY_INVALID. Retesting the entire unmodified key succeeded. The initial local Google connection and SSH were unavailable; connectivity was restored after the user checked SSH. An optional status command had a quoting error and made no changes.

## Checks and limitations

- API tests: 651/651; build succeeded. Flutter full tests: 207/207; focused analyzer clean. Twelve Linux release-preservation tests passed.
- API HTTPS catalog: 200; unauthenticated assistant: 401; SePay auth checks 401/400 before transaction handling; Cloudinary read-only ping200; four containers running with restart count0.
- Gemini direct provider probe is successful. An authenticated end-to-end request from the new Flutter chat to the deployed endpoint was **not** confirmed; the emulator changed screens during the attempted interaction. User should Hot Restart and test with a non-sensitive question.
- A screenshot of the home buttons and an earlier chat screen was inspected. Buttons initially obscured a section action; they now hide while scrolling, and space was reserved for the affected heading. The final revision passed widget tests but has not been visually rechecked on a physical phone.

## Rollback

On EC2, if required:

```bash
HEALTHBEAUTY_RELEASE_ID=20261028-gemini-assistant \
python3 /home/ubuntu/demo-api/releases/20261028-gemini-assistant/source/deploy/aws/release.py rollback
```

Rollback uses the previously saved Compose chain and prior API image and removes the added Gemini environment from the running API. Web, SQL Server and Caddy remain untouched. The private key file remains on disk for deliberate later handling; do not print it. No database rollback is needed.
