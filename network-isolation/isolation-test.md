# Network Isolation Test Scenarios

Quick commands to verify the network isolation is working correctly. Run these from the `network-isolation/` directory with the proxy already running (`docker-compose up -d proxy`).

---

## 1. Blocked domain — should FAIL

Any domain not in `squid.conf` must be denied with `TCP_DENIED/403`.

```bash
podman run --rm \
  --entrypoint bash \
  -e HTTP_PROXY=http://proxy:3128 \
  -e HTTPS_PROXY=http://proxy:3128 \
  -e http_proxy=http://proxy:3128 \
  -e https_proxy=http://proxy:3128 \
  --net network-isolation_isolated \
  localhost/network-isolation_agent \
  -c "curl -s --max-time 5 -o /dev/null -w 'HTTP status: %{http_code}\n' https://example.com || echo 'Blocked (expected)'"
```

**Expected:** `HTTP status: 000` and `Blocked (expected)`

---

## 2. Allowed domain — should SUCCEED

`api.anthropic.com` is in the allowlist and must be reachable.

```bash
podman run --rm \
  --entrypoint bash \
  -e HTTP_PROXY=http://proxy:3128 \
  -e HTTPS_PROXY=http://proxy:3128 \
  -e http_proxy=http://proxy:3128 \
  -e https_proxy=http://proxy:3128 \
  --net network-isolation_isolated \
  localhost/network-isolation_agent \
  -c "curl -s --max-time 15 -o /dev/null -w 'HTTP status: %{http_code}\n' https://api.anthropic.com"
```

**Expected:** `HTTP status: 200` or `404` (any valid HTTP response — not `000`)

---

## 3. Direct internet bypass — should FAIL

Without the proxy, the isolated network has no egress route at all.

```bash
podman run --rm \
  --entrypoint bash \
  --net network-isolation_isolated \
  localhost/network-isolation_agent \
  -c "curl -s --noproxy '*' --max-time 5 -o /dev/null -w 'HTTP status: %{http_code}\n' https://example.com || echo 'No route (expected)'"
```

**Expected:** `HTTP status: 000` and `No route (expected)`

---

## 4. GitHub — should SUCCEED

`github.com` is in the allowlist.

```bash
podman run --rm \
  --entrypoint bash \
  -e HTTP_PROXY=http://proxy:3128 \
  -e HTTPS_PROXY=http://proxy:3128 \
  -e http_proxy=http://proxy:3128 \
  -e https_proxy=http://proxy:3128 \
  --net network-isolation_isolated \
  localhost/network-isolation_agent \
  -c "curl -s --max-time 5 -o /dev/null -w 'HTTP status: %{http_code}\n' https://github.com"
```

**Expected:** `HTTP status: 200`

---

## 5. npm registry — should SUCCEED

`registry.npmjs.org` is in the allowlist (required for `npm install` inside the agent).

```bash
podman run --rm \
  --entrypoint bash \
  -e HTTP_PROXY=http://proxy:3128 \
  -e HTTPS_PROXY=http://proxy:3128 \
  -e http_proxy=http://proxy:3128 \
  -e https_proxy=http://proxy:3128 \
  --net network-isolation_isolated \
  localhost/network-isolation_agent \
  -c "curl -s --max-time 15 -o /dev/null -w 'HTTP status: %{http_code}\n' https://registry.npmjs.org"
```

**Expected:** `HTTP status: 200`

---

## 6. Run all tests at once

```bash
podman run --rm \
  --entrypoint bash \
  -e HTTP_PROXY=http://proxy:3128 \
  -e HTTPS_PROXY=http://proxy:3128 \
  -e http_proxy=http://proxy:3128 \
  -e https_proxy=http://proxy:3128 \
  --net network-isolation_isolated \
  localhost/network-isolation_agent \
  -c "
check() {
  local label=\$1 url=\$2 timeout=\$3 expect=\$4
  code=\$(curl -s --max-time \"\$timeout\" -o /dev/null -w '%{http_code}' \"\$url\" 2>/dev/null)
  if [ \"\$expect\" = 'blocked' ] && [ \"\$code\" = '000' ]; then
    echo \"PASS  \$label -> blocked (000)\"
  elif [ \"\$expect\" = 'allowed' ] && [ \"\$code\" != '000' ]; then
    echo \"PASS  \$label -> allowed (\$code)\"
  else
    echo \"FAIL  \$label -> expected \$expect but got \$code (proxy may have allowed it but remote returned no data within timeout)\"
  fi
}

check 'example.com (blocked)'          https://example.com        5  blocked
check 'api.anthropic.com (allowed)'    https://api.anthropic.com 15  allowed
check 'github.com (allowed)'           https://github.com         5  allowed
check 'registry.npmjs.org (allowed)'   https://registry.npmjs.org 15  allowed
check 'google.com (blocked)'           https://google.com         5  blocked
"
```

**Expected output:**
```
PASS  example.com (blocked)          -> blocked (000)
PASS  api.anthropic.com (allowed)    -> allowed (404)
PASS  github.com (allowed)           -> allowed (200)
PASS  registry.npmjs.org (allowed)   -> allowed (200)
PASS  google.com (blocked)           -> blocked (000)
```

---

## 7. Check proxy logs

After running any test above, inspect what Squid logged:

```bash
docker-compose logs proxy | grep -E "(DENIED|TUNNEL)" | tail -20
```

`TCP_DENIED/403` = blocked, `TCP_TUNNEL/200` = allowed through.
