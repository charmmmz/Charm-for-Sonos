import { Router } from 'express';
import type { Logger } from 'pino';

import { Cs2GameStateService, Cs2GameStateValidationError } from './cs2GameState.js';
import type { Cs2GameStatePayload } from './cs2Types.js';

export function createCs2GameStateRouter(service: Cs2GameStateService, log: Logger): Router {
  const router = Router();

  router.post('/cs2/gamestate', (req, res) => {
    try {
      const snapshot = service.receive(req.body as Cs2GameStatePayload);
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

  return router;
}
