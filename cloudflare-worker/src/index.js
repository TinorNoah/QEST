const SCRIPT_URL =
  'https://raw.githubusercontent.com/TinorNoah/QEST/main/get.qest.sh';
const FALLBACK_URL =
  'https://raw.githubusercontent.com/TinorNoah/QEST/main/get.qest.sh';

export default {
  async fetch() {
    const upstream = await fetch(SCRIPT_URL, {
      cf: { cacheTtl: 60, cacheEverything: true },
    });

    if (!upstream.ok) {
      return new Response(
        `#!/bin/bash
echo "[ERROR] QEST bootstrap is temporarily unavailable (upstream fetch failed)."
echo "[INFO] Retry in a few minutes, or run the direct fallback now:"
echo "curl -fsSL ${FALLBACK_URL} | bash"
echo "[INFO] If this keeps failing, check https://www.githubstatus.com/ and your network settings."
exit 1
`,
        {
          status: 503,
          headers: {
            'content-type': 'text/plain; charset=utf-8',
            'cache-control': 'public, max-age=60',
          },
        }
      );
    }

    const script = await upstream.text();
    return new Response(script, {
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'cache-control': 'public, max-age=60',
      },
    });
  },
};
