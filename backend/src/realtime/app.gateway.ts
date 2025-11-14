import { randomUUID } from 'crypto';

import { INestApplication, Logger } from '@nestjs/common';
import WebSocket, { WebSocketServer } from 'ws';

import { RealtimeHub } from './realtime.hub';

const logger = new Logger('AppGateway');

export const setupAppGateway = (app: INestApplication): void => {
  const httpServer = app.getHttpServer();
  const realtimeHub = app.get(RealtimeHub);

  const wss = new WebSocketServer({
    server: httpServer,
    path: '/ws/app',
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

    socket.on('close', () => {
      realtimeHub.unregister(connectionId);
      logger.log(`App client disconnected (${connectionId.slice(0, 8)})`);
    });
    socket.on('error', (err) => logger.warn(`App socket error: ${err}`));
  });

  wss.on('error', (err) => logger.error(`App WebSocket server error: ${err}`));
  logger.log('App WebSocket gateway ready at /ws/app');
};

const sendEnvelope = (socket: WebSocket, payload: unknown) => {
  if (socket.readyState !== WebSocket.OPEN) {
    return;
  }
  try {
    socket.send(JSON.stringify(payload));
  } catch (error) {
    logger.warn(`Failed to deliver WS payload: ${(error as Error).message}`);
  }
};
