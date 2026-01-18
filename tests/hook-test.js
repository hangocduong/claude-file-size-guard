#!/usr/bin/env node
/**
 * Test suite for file-size-guard hook
 * Run: node tests/hook-test.js
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const HOOK_PATH = path.join(__dirname, '../src/hooks/file-size-guard.cjs');

// Test utilities
function runHook(input) {
  return new Promise((resolve) => {
    const proc = spawn('node', [HOOK_PATH], { stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (d) => stdout += d);
    proc.stderr.on('data', (d) => stderr += d);
    proc.on('close', (code) => resolve({ code, stdout, stderr }));
    proc.stdin.write(JSON.stringify(input));
    proc.stdin.end();
  });
}

async function test(name, fn) {
  try {
    await fn();
    console.log(`✓ ${name}`);
    return true;
  } catch (err) {
    console.log(`✗ ${name}: ${err.message}`);
    return false;
  }
}

// Tests
async function runTests() {
  console.log('Testing file-size-guard hook\n');
  let passed = 0;
  let failed = 0;

  // Test 1: Small file allowed
  if (await test('Small file (10 lines) should be allowed', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: { file_path: '/tmp/small.js', content: 'x\n'.repeat(10) }
    });
    if (result.code !== 0) throw new Error(`Expected exit 0, got ${result.code}`);
  })) passed++; else failed++;

  // Test 2: Warning at threshold
  if (await test('File at warn threshold (125 lines) should warn but allow', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: { file_path: '/tmp/medium.js', content: 'x\n'.repeat(125) }
    });
    if (result.code !== 0) throw new Error(`Expected exit 0, got ${result.code}`);
    if (!result.stderr.includes('WARNING')) throw new Error('Expected warning message');
  })) passed++; else failed++;

  // Test 3: Block at threshold
  if (await test('File over block threshold (250 lines) should be blocked', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: { file_path: '/tmp/large.js', content: 'x\n'.repeat(250) }
    });
    if (result.code !== 2) throw new Error(`Expected exit 2, got ${result.code}`);
    if (!result.stderr.includes('BLOCKED')) throw new Error('Expected block message');
  })) passed++; else failed++;

  // Test 4: Excluded file allowed
  if (await test('JSON file (excluded) should be allowed regardless of size', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: { file_path: '/tmp/large.json', content: 'x\n'.repeat(500) }
    });
    if (result.code !== 0) throw new Error(`Expected exit 0, got ${result.code}`);
  })) passed++; else failed++;

  // Test 5: Markdown excluded
  if (await test('Markdown file (excluded) should be allowed', async () => {
    const result = await runHook({
      tool_name: 'Write',
      tool_input: { file_path: '/tmp/large.md', content: 'x\n'.repeat(500) }
    });
    if (result.code !== 0) throw new Error(`Expected exit 0, got ${result.code}`);
  })) passed++; else failed++;

  // Test 6: Non-Edit/Write allowed
  if (await test('Non-Edit/Write tool should be allowed', async () => {
    const result = await runHook({
      tool_name: 'Read',
      tool_input: { file_path: '/tmp/anything.js' }
    });
    if (result.code !== 0) throw new Error(`Expected exit 0, got ${result.code}`);
  })) passed++; else failed++;

  // Summary
  console.log(`\nResults: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

runTests();
