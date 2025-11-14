import { randomUUID } from 'crypto';

import { INestApplication, Logger } from '@nestjs/common';
import type { IncomingMessage } from 'http';
import WebSocket, { WebSocketServer } from 'ws';

import { MessageService } from '../message';
import { MessageRole } from '../entities';
import { TaskService } from '../project-task';
import { RealtimeHub } from './realtime.hub';
import { RoutePayload } from './types';

type AgentEvent =
  | {
      type: 'create_task';
      payload: {
        task_id: string;
        project_id: string;
        title: string;
        prefill?: string;
      };
    }
  | {
      type: 'sdk_message';
      payload: {
        task_id: string;
        content: string;
        metadata?: Record<string, unknown>;
      };
    };

type CreateTaskEvent = Extract<AgentEvent, { type: 'create_task' }>;
type SdkMessageEvent = Extract<AgentEvent, { type: 'sdk_message' }>;

const logger = new Logger('AgentGateway');

const parseEvent = (data: WebSocket.RawData): AgentEvent => {
  try {
    const json = typeof data === 'string' ? data : data.toString();
    const parsed = JSON.parse(json) as AgentEvent;
    if (!parsed?.type) {
      throw new Error('Missing event type');
    }
    return parsed;
  } catch (error) {
    throw new Error(`Invalid event payload: ${(error as Error).message}`);
  }
};

const sendEnvelope = (socket: WebSocket, envelope: Record<string, unknown>) => {
  if (socket.readyState !== WebSocket.OPEN) {
    return;
  }
  socket.send(JSON.stringify(envelope));
};

const extractToken = (req: IncomingMessage): string | undefined => {
  const header = req.headers['authorization'] ?? req.headers['Authorization'];
  if (!header || Array.isArray(header)) {
    return undefined;
  }
  const [, token] = header.split(' ');
  return token;
};

const handleCreateTask = async (
  payload: CreateTaskEvent['payload'],
  taskService: TaskService,
  messageService: MessageService,
) => {
  if (
    typeof payload?.task_id !== 'string' ||
    typeof payload.project_id !== 'string' ||
    typeof payload.title !== 'string'
  ) {
    throw new Error('create_task payload requires task_id, project_id, and title');
  }
  const task = await taskService.createTask({
    taskId: payload.task_id,
    projectId: payload.project_id,
    title: payload.title,
  });
  if (payload.prefill && payload.prefill.trim().length > 0) {
    await messageService.createMessage({
      taskId: task.id,
      role: MessageRole.USER,
      content: payload.prefill,
    });
  }
  return task.id;
};

const handleSdkMessage = async (
  payload: SdkMessageEvent['payload'],
  messageService: MessageService,
) => {
  if (typeof payload?.task_id !== 'string' || typeof payload.content !== 'string') {
    throw new Error('sdk_message payload requires task_id and content');
  }
  await messageService.createMessage({
    taskId: payload.task_id,
    role: MessageRole.SDK,
    content: payload.content,
    metadata: payload.metadata,
  });
};

export const AGENT_WS_PATH = '/ws/agent';

export const setupAgentGateway = (app: INestApplication): WebSocketServer => {
  const taskService = app.get(TaskService);
  const messageService = app.get(MessageService);
  const realtimeHub = app.get(RealtimeHub);

  const wss = new WebSocketServer({ noServer: true });

  wss.on('connection', (socket, request) => {
    const token = extractToken(request);
    logger.log(`Agent connected${token ? ` token=${token.slice(0, 6)}…` : ''}`);
    const connectionId = randomUUID();
    realtimeHub.register({
      id: connectionId,
      kind: 'agent',
      projectIds: ['*'],
      send: (payload) => {
        const envelope = normalizeAgentEnvelope(payload);
        if (envelope) {
          sendEnvelope(socket, envelope);
        }
      },
    });

    socket.on('message', async (raw) => {
      try {
        const event = parseEvent(raw);
        switch (event.type) {
          case 'create_task': {
            const taskId = await handleCreateTask(event.payload, taskService, messageService);
            sendEnvelope(socket, { type: 'task_created', payload: { task_id: taskId } });
            break;
          }
          case 'sdk_message': {
            await handleSdkMessage(event.payload, messageService);
            sendEnvelope(socket, {
              type: 'message_recorded',
              payload: { task_id: event.payload.task_id },
            });
            break;
          }
          default: {
            const unsupported = event as { type: string };
            throw new Error(`Unsupported event type ${unsupported.type}`);
          }
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown agent error';
        logger.error(message);
        sendEnvelope(socket, { type: 'error', payload: { message } });
      }
    });

    socket.on('close', () => {
      realtimeHub.unregister(connectionId);
      logger.log('Agent disconnected');
    });
    socket.on('error', (err) => logger.warn(`Agent socket error: ${err}`));
  });

  wss.on('error', (err) => logger.error(`Agent WebSocket server error: ${err}`));
  logger.log(`Agent WebSocket gateway ready at ${AGENT_WS_PATH}`);
  return wss;
};

const normalizeAgentEnvelope = (
  payload: unknown,
): { type: string; payload: unknown } | null => {
  if (isRoutePayload(payload)) {
    return {
      type: payload.type,
      payload: payload.data,
    };
  }
  if (isTypedEnvelope(payload)) {
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

const isTypedEnvelope = (value: unknown): value is { type: string } => {
  return (
    !!value &&
    typeof value === 'object' &&
    'type' in value &&
    typeof (value as { type?: unknown }).type === 'string'
  );
};
