export interface AiRequest {
  prompt: string;
  model?: string;
  maxTokens?: number;
}

export interface AiResponse {
  content: string;
  usage?: { inputTokens: number; outputTokens: number };
}

export interface AiClient {
  complete(request: AiRequest): Promise<AiResponse>;
}
