import { pathToFileURL } from 'node:url';
import { readFile } from 'node:fs/promises';

export async function checkLlm({ url, model, apiKey = '', includeTools = true,
  systemPrompt = 'Reply briefly in Chinese.', fetchImpl = fetch }) {
  const endpoint = new URL(url);
  if (!endpoint.pathname.endsWith('/v1/chat/completions')) {
    throw new Error('LLM_API_URL must be the full /v1/chat/completions endpoint');
  }
  if (!model) throw new Error('LLM_MODEL is required');

  const response = await fetchImpl(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
    },
    body: JSON.stringify({
      model,
      max_completion_tokens: 128,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: '请打个招呼。' },
      ],
      ...(includeTools ? {
        tools: [{ type: 'function', function: {
          name: 'get_datetime', description: 'Get current date', parameters: { type: 'object', properties: {} },
        } }],
        tool_choice: 'auto',
      } : {}),
    }),
    signal: AbortSignal.timeout(30000),
  });

  if (!response.ok) {
    const detail = (await response.text()).slice(0, 400);
    throw new Error(`LLM returned HTTP ${response.status}: ${detail}`);
  }
  const data = await response.json();
  const choice = data?.choices?.[0];
  const content = choice?.message?.content;
  const calls = choice?.message?.tool_calls;
  if (!choice || (typeof content !== 'string' && !Array.isArray(calls))) {
    throw new Error('LLM response lacks choices[0].message.content or tool_calls');
  }
  if (Array.isArray(calls) && calls.some((call) =>
    call.type !== 'function' || typeof call.id !== 'string' ||
    typeof call.function?.name !== 'string' || typeof call.function?.arguments !== 'string')) {
    throw new Error('LLM tool_calls must contain id, function name and JSON arguments string');
  }
  return { finishReason: choice.finish_reason, text: content ?? '', toolCalls: calls?.length ?? 0 };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const soul = process.env.LLM_SOUL_FILE ? readFile(process.env.LLM_SOUL_FILE, 'utf8') : Promise.resolve(undefined);
  soul.then((systemPrompt) => checkLlm({
    url: process.env.LLM_API_URL,
    model: process.env.LLM_MODEL,
    apiKey: process.env.LLM_API_KEY,
    includeTools: process.env.LLM_PROBE_TOOLS !== '0',
    systemPrompt,
  })).then((result) => console.log(JSON.stringify(result)))
    .catch((error) => { console.error(error.message); process.exitCode = 1; });
}