import https from 'node:https';

import type { HueBridgeInfo, HueLightClient } from './hueTypes.js';

export class HueClipClient implements HueLightClient {
  constructor(
    private readonly bridge: HueBridgeInfo,
    private readonly applicationKey: string,
  ) {}

  async updateLight(id: string, body: unknown): Promise<void> {
    await this.request('PUT', `/clip/v2/resource/light/${encodeURIComponent(id)}`, body);
  }

  private request(method: string, requestPath: string, body: unknown): Promise<void> {
    const payload = JSON.stringify(body);

    return new Promise((resolve, reject) => {
      const req = https.request(
        {
          hostname: this.bridge.ipAddress,
          port: 443,
          path: requestPath,
          method,
          rejectUnauthorized: false,
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload),
            'hue-application-key': this.applicationKey,
          },
          timeout: 5_000,
        },
        res => {
          const chunks: Buffer[] = [];
          res.on('data', chunk => chunks.push(Buffer.from(chunk)));
          res.on('end', () => {
            if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
              resolve();
              return;
            }
            const text = Buffer.concat(chunks).toString('utf8');
            reject(new Error(`Hue ${method} ${requestPath} failed: HTTP ${res.statusCode} ${text}`));
          });
        },
      );

      req.on('timeout', () => {
        req.destroy(new Error(`Hue ${method} ${requestPath} timed out`));
      });
      req.on('error', reject);
      req.write(payload);
      req.end();
    });
  }
}
