export const RedisKeys = {
  agentHeartbeat(agentId: string): string {
    return `agent:${agentId}:heartbeat`;
  },

  agentCapabilities(agentIdOrToken: string): string {
    return `agent:${agentIdOrToken}:capabilities`;
  },

  projectActiveTasks(projectId: string): string {
    return `project:${projectId}:active_tasks`;
  },

  taskStatus(taskId: string): string {
    return `task:${taskId}:status`;
  },

  taskLogChannel(taskId: string): string {
    return `task:${taskId}:logs`;
  },

  wsSession(sessionId: string): string {
    return `ws:session:${sessionId}`;
  },
};
