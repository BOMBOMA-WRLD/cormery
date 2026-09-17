import { createDeepSeek } from '@ai-sdk/deepseek';

// 1. Initialisation du provider avec la clé API
export const deepseekProvider = createDeepSeek({
  apiKey: process.env.DEEPSEEK_API_KEY || '',
});

// 2. Helper pour instancier les modèles principaux (Reasoning ou Chat)
export const deepseekModel = (
  modelName: 'deepseek-chat' | 'deepseek-reasoner' = 'deepseek-chat'
) => {
  return deepseekProvider(modelName);
};
