import { RealtimeHub, RoutePayload } from '../../src';

const createConnection = (overrides = {}) => ({
  id: `conn-${Math.random().toString(16).slice(2)}`,
  kind: 'app' as const,
  projectIds: ['project-1'],
  send: jest.fn(),
  ...overrides,
});

describe('RealtimeHub', () => {
  it('registers and dispatches to project-scoped apps', () => {
    const hub = new RealtimeHub();
    const appConn = createConnection();
    hub.register(appConn);

    const payload: RoutePayload = {
      taskId: 'task-1',
      projectId: 'project-1',
      type: 'task_user_message',
      data: { content: 'Hello' },
    };

    hub.routeToProjectApps(payload);
    expect(appConn.send).toHaveBeenCalledWith(payload);
  });

  it('dispatches only to agents subscribed to the project', () => {
    const hub = new RealtimeHub();
    const agent = createConnection({ kind: 'agent', projectIds: ['project-2'] });
    const otherAgent = createConnection({ kind: 'agent', projectIds: ['project-3'] });
    hub.register(agent);
    hub.register(otherAgent);

    const payload: RoutePayload = {
      taskId: 'task-2',
      projectId: 'project-2',
      type: 'action_request',
      data: { action: 'run_tests' },
    };

    hub.routeToProjectAgents(payload);
    expect(agent.send).toHaveBeenCalledWith(payload);
    expect(otherAgent.send).not.toHaveBeenCalled();
  });

  it('tracks heartbeats and prunes stale connections', () => {
    const hub = new RealtimeHub({ heartbeatTimeoutMs: 1000 });
    const conn = createConnection();
    const disconnected = jest.fn();
    hub.on('disconnected', disconnected);
    hub.register(conn);
    expect(hub.size()).toBe(1);

    hub.pruneStaleConnections(Date.now() + 2000);
    expect(hub.size()).toBe(0);
    expect(disconnected).toHaveBeenCalledWith(expect.objectContaining({ id: conn.id }));
  });

  it('broadcasts to all agents', () => {
    const hub = new RealtimeHub();
    const agentA = createConnection({ kind: 'agent', projectIds: ['p1'] });
    const agentB = createConnection({ kind: 'agent', projectIds: ['p2'] });
    const app = createConnection({ kind: 'app' });
    hub.register(agentA);
    hub.register(agentB);
    hub.register(app);

    const message = { type: 'heartbeat_request' };
    hub.broadcastToAgents(message);
    expect(agentA.send).toHaveBeenCalledWith(message);
    expect(agentB.send).toHaveBeenCalledWith(message);
    expect(app.send).not.toHaveBeenCalled();
  });
});
