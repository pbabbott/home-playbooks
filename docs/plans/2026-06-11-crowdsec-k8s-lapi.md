# CrowdSec: k8s LAPI + Istio Behavioral Detection

**Repo:** home-kubernetes  
**Goal:** Deploy CrowdSec LAPI + agent in the prod k8s cluster. Agent reads Istio gateway access logs to detect behavioral threats (scanners, brute force, CVE probers). LAPI serves ban decisions to the HAProxy firewall bouncer and any in-cluster bouncers.

---

## Architecture

```
Istio Gateway pods
      │ access logs
      ▼
CrowdSec Agent (DaemonSet)
      │ detects threats
      ▼
CrowdSec LAPI (Deployment) ◄── community blocklist sync
      │
      ├── HAProxy firewall bouncer (pulls decisions → iptables DROP at edge)
      └── (optional) in-cluster bouncer for k8s NetworkPolicy bans
```

---

## Step 1: Configure Istio access logs

CrowdSec agent needs structured access logs from the Istio ingress gateway. Enable JSON access logging in the Istio mesh config (or via `IstioOperator`):

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    accessLogFile: /dev/stdout
    accessLogFormat: |
      {"authority":"%REQ(:AUTHORITY)%","bytes_received":"%BYTES_RECEIVED%","bytes_sent":"%BYTES_SENT%","duration":"%DURATION%","method":"%REQ(:METHOD)%","path":"%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%","protocol":"%PROTOCOL%","request_id":"%REQ(X-REQUEST-ID)%","requested_server_name":"%REQUESTED_SERVER_NAME%","response_code":"%RESPONSE_CODE%","response_flags":"%RESPONSE_FLAGS%","route_name":"%ROUTE_NAME%","start_time":"%START_TIME%","upstream_cluster":"%UPSTREAM_CLUSTER%","upstream_host":"%UPSTREAM_HOST%","user_agent":"%REQ(USER-AGENT)%","x_forwarded_for":"%REQ(X-FORWARDED-FOR)%"}
    accessLogEncoding: JSON
```

The `x_forwarded_for` field is the real client IP (set by Cloudflare). CrowdSec must ban on this IP, not the Cloudflare proxy IP.

---

## Step 2: Deploy CrowdSec via Helm

```bash
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update
```

`values.yaml`:

```yaml
container_runtime: containerd

agent:
  acquisition:
    - namespace: istio-system
      podName: istio-ingressgateway-*
      program: istio   # uses crowdsecurity/istio collection parser
  env:
    - name: COLLECTIONS
      value: "crowdsecurity/istio crowdsecurity/base-http-scenarios"

lapi:
  env:
    - name: ENROLL_KEY        # optional — links to app.crowdsec.net dashboard
      value: ""               # fill in if you want the console
    - name: SCENARIOS
      value: "crowdsecurity/http-crawl-non_statics crowdsecurity/http-bad-user-agent crowdsecurity/http-path-traversal-probing"

service:
  type: NodePort
  nodePort: 32080             # HAProxy LXC connects here
```

```bash
helm install crowdsec crowdsec/crowdsec -n crowdsec --create-namespace -f values.yaml
```

---

## Step 3: Generate HAProxy bouncer API key

```bash
kubectl exec -n crowdsec deploy/crowdsec-lapi -- cscli bouncers add haproxy-bouncer
# Copy the output key — used in home-playbooks terraform.tfvars as crowdsec_bouncer_api_key
```

---

## Step 4: Verify agent sees Istio logs

```bash
kubectl exec -n crowdsec deploy/crowdsec-lapi -- cscli metrics
# Should show log lines parsed from istio-ingressgateway pods

kubectl exec -n crowdsec deploy/crowdsec-lapi -- cscli alerts list
# Will populate as threats are detected
```

---

## Step 5: (Optional) In-cluster bouncer

If you want bans enforced inside the cluster as well (NetworkPolicy-level):

```bash
helm install crowdsec-k8s-bouncer crowdsec/crowdsec-helm-charts \
  --set "bouncer.crowdsec_lapi_url=http://crowdsec-service.crowdsec:8080" \
  --set "bouncer.crowdsec_lapi_key=<key from cscli bouncers add k8s-bouncer>"
```

---

## After k8s setup — return to home-playbooks

With LAPI running and HAProxy bouncer key in hand, complete `2026-06-11-crowdsec-haproxy-bouncer.md`:

1. Add `crowdsec_lapi_url = "http://192.168.6.2x:32080"` to `terraform.tfvars`
2. Add `crowdsec_bouncer_api_key` to `terraform.tfvars`
3. `terraform apply`

---

## Notes

- Real client IP is in `X-Forwarded-For` (set by Cloudflare). Confirm CrowdSec is banning the XFF IP, not the Cloudflare IP, or all bans will block all Cloudflare traffic.
- CrowdSec free tier includes community blocklists. No account needed, but enrolling at app.crowdsec.net gives a dashboard and premium threat feeds.
- Start with scenarios in log/simulation mode (`--no-api`) to validate parsing before live bans.
