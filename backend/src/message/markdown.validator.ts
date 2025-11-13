const MAX_LENGTH = 20_000;
const DISALLOWED_TAGS = ['<script', '<iframe', '<object', '<embed'];

export const validateMarkdown = (content: string): void => {
  if (!content || !content.trim()) {
    throw new Error('Message content cannot be empty');
  }
  if (content.length > MAX_LENGTH) {
    throw new Error(`Message content exceeds ${MAX_LENGTH} characters`);
  }
  const lowered = content.toLowerCase();
  if (DISALLOWED_TAGS.some((tag) => lowered.includes(tag))) {
    throw new Error('HTML tags are not allowed in markdown content');
  }

  const fenceCount = (content.match(/```/g) || []).length;
  if (fenceCount % 2 !== 0) {
    throw new Error('Markdown code fences must be balanced');
  }
};
