import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { after, before, test } from 'node:test';
import { checkLlm } from './check-llm.mjs';

let server;
let url;
let reply;
let received;

before(async () => {
  server = createServer(async (request, response) => {
    let body = '';
    for await (const chunk of request) body += chunk;
    received = { path: request.url, auth: request.headers.authorization, body: JSON.parse(body) };
    response.writeHead(reply.status, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify(reply.body));
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  url = `http://127.0.0.1:${server.address().port}/v1/chat/completions`;
});

after(() => new Promise((resolve) => server.close(resolve)));

test('persona fits upstream SOUL cache and states its boundaries', async () => {
  const soul = await readFile(new URL('../config/Lisa.Beck/SOUL.md', import.meta.url));
  assert.ok(soul.length > 0 && soul.length < 4096);
  for (const text of ['艾玛·伍兹', '简体中文', '原始录音', '不编造']) {
    assert.ok(soul.toString().includes(text), text);
  }
});

test('accepts text response and sends XiaoClaw-compatible request', async () => {
  reply = { status: 200, body: { choices: [{ message: { content: '你好。' }, finish_reason: 'stop' }] } };
  const result = await checkLlm({ url, model: 'local-model', apiKey: 'test-token' });
  assert.deepEqual(result, { finishReason: 'stop', text: '你好。', toolCalls: 0 });
  assert.equal(received.path, '/v1/chat/completions');
  assert.equal(received.auth, 'Bearer test-token');
  assert.equal(received.body.stream, undefined);
  assert.equal(received.body.max_completion_tokens, 128);
  assert.equal(received.body.tools[0].function.name, 'get_datetime');
});

test('accepts function tool calls with JSON-string arguments', async () => {
  reply = { status: 200, body: { choices: [{ finish_reason: 'tool_calls', message: { content: null,
    tool_calls: [{ id: 'call_1', type: 'function', function: { name: 'get_datetime', arguments: '{}' } }] } }] } };
  const result = await checkLlm({ url, model: 'local-model' });
  assert.equal(result.toolCalls, 1);
});

test('text-only probe omits tools when the server does not support auto tool choice', async () => {
  reply = { status: 200, body: { choices: [{ message: { content: '你好。' }, finish_reason: 'stop' }] } };
  await checkLlm({ url, model: 'local-model', includeTools: false, systemPrompt: '园丁草稿' });
  assert.equal(received.body.tools, undefined);
  assert.equal(received.body.tool_choice, undefined);
  assert.equal(received.body.messages[0].content, '园丁草稿');
});

test('rejects invalid responses and service errors', async () => {
  reply = { status: 200, body: { choices: [{}] } };
  await assert.rejects(checkLlm({ url, model: 'local-model' }), /lacks choices/);
  reply = { status: 503, body: { error: 'unavailable' } };
  await assert.rejects(checkLlm({ url, model: 'local-model' }), /HTTP 503/);
  await assert.rejects(checkLlm({ url: 'http://localhost/v1', model: 'local-model' }), /full \/v1\/chat/);
});