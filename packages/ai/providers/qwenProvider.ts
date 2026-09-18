import { createOpenAI } from '@ai-sdk/openai';

export const qwenProvider = createOpenAI({
    name: 'qwen',
    apiKey: process.env.QWEN_API_KEY || '',
    baseurl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
})

export const qwenModel = (modelName: 'qwen-max'| 'qwen-plus' | 'qwen-turbo' = 'qwen-plus') => { return qwenProvider(modelName);
};
