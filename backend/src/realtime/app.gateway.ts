import { randomUUID } from 'crypto';

import { INestApplication, Logger } from '@nestjs/common';
import WebSocket, { WebSocketServer } from 'ws';

import { RealtimeHub } from './realtime.hub';
import { RoutePayload } from './types';

const logger = new Logger('AppGateway');

export const APP_WS_PATH = '/ws/app';

export const setupAppGateway = (app: INestApplication): WebSocketServer => {
  const realtimeHub = app.get(RealtimeHub);

  const wss = new WebSocketServer({
    noServer: true,
  });

  wss.on('connection', (socket) => {
    const connectionId = randomUUID();
    realtimeHub.register({
      id: connectionId,
      kind: 'app',
      projectIds: ['*'],
      send: (payload) => sendEnvelope(socket, payload),
    });
    logger.log(`App client connected (${connectionId.slice(0, 8)})`);

    // Heartbeat: mark alive when we receive a pong
    let isAlive = true;
    const heartbeat = () => {
      isAlive = true;
      realtimeHub.heartbeat(connectionId);
    };
    socket.on('pong', heartbeat);

    // Periodic ping to keep NATs/routers happy and detect half-open
    const interval = setInterval(() => {
      if (socket.readyState !== WebSocket.OPEN) {
        return;
      }
      if (!isAlive) {
        try {
          socket.terminate();
        } catch {}
        return;
      }
      isAlive = false;
      try {
        socket.ping();
      } catch {}
    }, 25_000);

    socket.on('close', (code: number, reason: Buffer) => {
      realtimeHub.unregister(connectionId);
      clearInterval(interval);
      const reasonText = reason && reason.length > 0 ? reason.toString('utf8') : '';
      logger.log(
        `App client disconnected (${connectionId.slice(0, 8)}) code=${code}` +
          (reasonText ? ` reason=${reasonText}` : ''),
      );
    });
    socket.on('error', (err) => logger.warn(`App socket error: ${err}`));
  });

  wss.on('error', (err) => logger.error(`App WebSocket server error: ${err}`));
  logger.log(`App WebSocket gateway ready at ${APP_WS_PATH}`);
  return wss;
};

const sendEnvelope = (socket: WebSocket, payload: unknown) => {
  if (socket.readyState !== WebSocket.OPEN) {
    return;
  }
  const envelope = normalizeAppEnvelope(payload);
  if (!envelope) {
    return;
  }
  try {
    socket.send(JSON.stringify(envelope));
  } catch (error) {
    logger.warn(`Failed to deliver WS payload: ${(error as Error).message}`);
  }
};

const normalizeAppEnvelope = (
  payload: unknown,
): { type: string; payload: unknown } | null => {
  if (isRoutePayload(payload)) {
    return {
      type: payload.type,
      payload: payload.data,
    };
  }
  if (
    payload &&
    typeof payload === 'object' &&
    'type' in payload &&
    typeof (payload as { type?: unknown }).type === 'string'
  ) {
    const value = payload as { type: string; payload?: unknown };
    return { type: value.type, payload: 'payload' in value ? value.payload : payload };
  }
  return null;
};

const isRoutePayload = (value: unknown): value is RoutePayload => {
  if (!value || typeof value !== 'object') {
    return false;
  }
  const candidate = value as RoutePayload;
  return (
    typeof candidate.type === 'string' &&
    'data' in candidate &&
    typeof candidate.data !== 'undefined'
  );
};
