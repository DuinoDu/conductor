import 'reflect-metadata';
import * as dotenv from 'dotenv';
import { ValidationPipe, Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import {
  AppDataSource,
  createAppDataSource,
  setActiveDataSource,
} from './database';
import { setupAgentGateway, setupAppGateway } from './realtime';
import { APP_WS_PATH } from './realtime/app.gateway';
import { AGENT_WS_PATH } from './realtime/agent.gateway';

dotenv.config();

function resolveDataSource() {
  const preferSqlite = !process.env.DB_HOST || process.env.DB_DIALECT === 'sqlite';
  if (preferSqlite) {
    return createAppDataSource({
      type: 'sqlite',
      database: process.env.DB_SQLITE_PATH || './conductor.db',
      synchronize: true,
    });
  }
  return AppDataSource;
}

async function bootstrap() {
  const dataSource = resolveDataSource();
  await dataSource.initialize();
  console.log(`Backend data source initialized (${dataSource.options.type})`);
  setActiveDataSource(dataSource);

  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  // Attach a concrete logger to flush buffered Nest logs and enable Logger() output
  app.useLogger(new Logger());

  // Setup WebSocket gateways and a single upgrade router for clean path routing.
  const httpServer = app.getHttpServer();
  const appWss = setupAppGateway(app);
  const agentWss = setupAgentGateway(app);

  const upgradeLogger = new Logger('Upgrade');
  httpServer.on('upgrade', (req: any, socket: any, head: any) => {
    try {
      const host = req?.headers?.host ?? '';
      const upgrade = req?.headers?.['upgrade'] ?? '';
      const conn = req?.headers?.['connection'] ?? '';
      const origin = req?.headers?.['origin'] ?? '';
      const protocol = req?.headers?.['sec-websocket-protocol'] ?? '';
      const swv = req?.headers?.['sec-websocket-version'] ?? '';
      const url = req?.url ?? '';
      upgradeLogger.log(
        `HTTP upgrade: url=${url} host=${host} upgrade=${upgrade} connection=${conn} origin=${origin} protocol=${protocol} sec-websocket-version=${swv}`,
      );
      const pathname = (() => {
        try {
          const base = host ? `http://${host}` : 'http://localhost';
          return new URL(url, base).pathname;
        } catch {
          return url;
        }
      })();
      const accept = (wss: any) =>
        wss.handleUpgrade(req, socket, head, (ws: any) => wss.emit('connection', ws, req));
      if (pathname === APP_WS_PATH) {
        return accept(appWss);
      }
      if (pathname === AGENT_WS_PATH) {
        return accept(agentWss);
      }
      socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
      socket.destroy();
    } catch (e) {
      upgradeLogger.warn(`Failed to route upgrade: ${(e as Error).message}`);
      try {
        socket.write('HTTP/1.1 400 Bad Request\r\n\r\n');
      } catch {}
      socket.destroy();
    }
  });

  const corsOrigins =
    process.env.CORS_ORIGINS?.split(',')
      .map((origin) => origin.trim())
      .filter((origin) => origin.length > 0) ?? [];

  app.enableCors({
    origin: corsOrigins.length > 0 ? corsOrigins : true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  const port = Number(process.env.PORT || 4000);
  await app.listen(port);
  console.log(`Conductor backend listening on http://localhost:${port}`);
}

bootstrap().catch((err) => {
  console.error('Failed to start backend', err);
  process.exit(1);
});
