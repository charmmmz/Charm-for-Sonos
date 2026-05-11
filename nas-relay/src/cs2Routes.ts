import { Router } from 'express';
import type { Logger } from 'pino';

import { Cs2GameStateService, Cs2GameStateValidationError } from './cs2GameState.js';
import type { Cs2DebugSample, Cs2GameStatePayload } from './cs2Types.js';

export function createCs2GameStateRouter(service: Cs2GameStateService, log: Logger): Router {
  const router = Router();

  router.post('/cs2/gamestate', (req, res) => {
    try {
      const snapshot = service.receive(req.body as Cs2GameStatePayload, { sourceIp: req.ip });
      log.debug({ providerSteamId: snapshot.providerSteamId }, 'received CS2 game state');
      res.status(204).send();
    } catch (err) {
      if (err instanceof Cs2GameStateValidationError) {
        res.status(400).json({ ok: false, error: err.message });
        return;
      }

      log.warn({ err }, 'failed to receive CS2 game state');
      res.status(500).json({ ok: false, error: String(err) });
    }
  });

  router.get('/cs2/status', (_req, res) => {
    res.json({ ok: true, providers: service.status() });
  });

  router.get('/cs2/debug/recent', (_req, res) => {
    res.json({ ok: true, samples: service.debugSamples() });
  });

  router.delete('/cs2/debug/recent', (_req, res) => {
    service.clearDebugSamples();
    res.json({ ok: true });
  });

  router.get('/cs2/debug/stream', (req, res) => {
    res.status(200);
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders?.();
    res.write(': connected\n\n');

    const sendSample = (sample: Cs2DebugSample) => {
      res.write(`event: state\ndata: ${JSON.stringify(sample)}\n\n`);
    };

    service.on('debug-sample', sendSample);
    req.on('close', () => {
      service.off('debug-sample', sendSample);
    });
  });

  return router;
}
