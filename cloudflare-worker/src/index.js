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
echo "QEST bootstrap is temporarily unavailable (upstream fetch failed)."
echo "Try again in a moment, or use direct fallback:"
echo "curl -fsSL ${FALLBACK_URL} | bash"
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
