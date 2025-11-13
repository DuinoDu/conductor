import { EventEmitter } from 'events';

import { RealtimeConnection, RoutePayload } from './types';

interface ConnectionState extends RealtimeConnection {
  lastHeartbeat: number;
}

export interface RealtimeHubOptions {
  heartbeatTimeoutMs?: number;
}

export class RealtimeHub extends EventEmitter {
  private readonly connections = new Map<string, ConnectionState>();
  private readonly heartbeatTimeout: number;

  constructor(options: RealtimeHubOptions = {}) {
    super();
    this.heartbeatTimeout = options.heartbeatTimeoutMs ?? 30_000;
  }

  register(connection: RealtimeConnection): void {
    this.connections.set(connection.id, {
      ...connection,
      lastHeartbeat: Date.now(),
    });
    this.emit('connected', connection);
  }

  unregister(connectionId: string): void {
    const existing = this.connections.get(connectionId);
    if (!existing) {
      return;
    }
    this.connections.delete(connectionId);
    this.emit('disconnected', existing);
  }

  heartbeat(connectionId: string): void {
    const existing = this.connections.get(connectionId);
    if (!existing) {
      return;
    }
    existing.lastHeartbeat = Date.now();
  }

  pruneStaleConnections(now = Date.now()): void {
    for (const [id, state] of this.connections.entries()) {
      if (now - state.lastHeartbeat > this.heartbeatTimeout) {
        this.unregister(id);
      }
    }
  }

  routeToProjectApps(payload: RoutePayload): void {
    this.dispatch(
      payload,
      (connection) => connection.kind === 'app' && connection.projectIds.includes(payload.projectId),
    );
  }

  routeToProjectAgents(payload: RoutePayload): void {
    this.dispatch(
      payload,
      (connection) =>
        connection.kind === 'agent' && connection.projectIds.includes(payload.projectId),
    );
  }

  broadcastToAgents(message: unknown): void {
    this.dispatch(message, (connection) => connection.kind === 'agent');
  }

  size(): number {
    return this.connections.size;
  }

  private dispatch(payload: unknown, predicate: (connection: ConnectionState) => boolean): void {
    for (const connection of this.connections.values()) {
      if (predicate(connection)) {
        connection.send(payload);
      }
    }
  }
}
