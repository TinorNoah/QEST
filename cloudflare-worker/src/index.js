const SCRIPT_URL =
  'https://raw.githubusercontent.com/TinorNoah/QEST/main/get.qest.sh';

export default {
  async fetch() {
    const upstream = await fetch(SCRIPT_URL, {
      cf: { cacheTtl: 300, cacheEverything: true },
    });

    if (!upstream.ok) {
      return new Response(
        '#!/bin/bash\necho "QEST bootstrap is temporarily unavailable."\nexit 1\n',
        {
          status: 503,
          headers: {
            'content-type': 'text/plain; charset=utf-8',
            'cache-control': 'no-store',
          },
        }
      );
    }

    const script = await upstream.text();
    return new Response(script, {
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'cache-control': 'no-store',
      },
    });
  },
};
