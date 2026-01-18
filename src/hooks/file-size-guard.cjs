#!/usr/bin/env node
/**
 * file-size-guard.cjs - Prevent large files through micro-extract pattern
 *
 * Hook for PreToolUse (Edit|Write) that:
 * 1. Checks current file size before edit
 * 2. Estimates size after edit
 * 3. Warns at warnThreshold (default 120 lines)
 * 4. Blocks at blockThreshold (default 200 lines)
 *
 * Philosophy: Prevent refactoring by enforcing modular code from the start.
 * Uses micro-extract pattern: extract NEW code to NEW files, don't modify existing.
 *
 * Exit Codes:
 * - 0: Operation allowed (with optional warning message)
 * - 2: Operation blocked (file too large)
 *
 * Configuration (.ck.json or .claude/.ck.json):
 * {
 *   "fileSizeGuard": {
 *     "enabled": true,
 *     "warnThreshold": 120,
 *     "blockThreshold": 200,
 *     "excludePatterns": ["pattern1", "pattern2"]
 *   }
 * }
 *
 * @version 1.0.0
 * @author Claude File Size Guard
 * @license MIT
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const { countLines, estimateLinesAfterEdit, estimateLinesForWrite } = require('./file-size-guard/line-counter.cjs');
const { checkThreshold, shouldExclude, getThresholdConfig } = require('./file-size-guard/threshold-checker.cjs');
const { formatWarningMessage, formatBlockMessage } = require('./file-size-guard/suggestion-generator.cjs');

/**
 * Load .ck.json config from multiple locations
 * Priority: local project > global
 */
function loadCkConfig() {
  const searchPaths = [
    path.join(process.cwd(), '.claude', '.ck.json'),
    path.join(process.cwd(), '.ck.json'),
    path.join(os.homedir(), '.claude', '.ck.json')
  ];

  for (const configPath of searchPaths) {
    try {
      if (fs.existsSync(configPath)) {
        return JSON.parse(fs.readFileSync(configPath, 'utf-8'));
      }
    } catch (e) {
      // Continue to next path
    }
  }
  return {};
}

/**
 * Resolve file path (handle relative paths)
 */
function resolveFilePath(filePath) {
  if (!filePath) return null;
  if (path.isAbsolute(filePath)) return filePath;
  return path.join(process.cwd(), filePath);
}

/**
 * Main hook logic
 */
function main() {
  try {
    // Read stdin
    const hookInput = fs.readFileSync(0, 'utf-8');
    if (!hookInput || hookInput.trim().length === 0) {
      process.exit(0);
    }

    // Parse JSON
    let data;
    try {
      data = JSON.parse(hookInput);
    } catch {
      process.exit(0); // Fail-open for parse errors
    }

    // Load config
    const ckConfig = loadCkConfig();
    const fileSizeGuard = ckConfig.fileSizeGuard || {};

    // Check if hook is enabled (default: true)
    if (fileSizeGuard.enabled === false) {
      process.exit(0);
    }

    // Get threshold config
    const config = getThresholdConfig(ckConfig);

    // Extract tool info
    const toolName = data.tool_name || '';
    const toolInput = data.tool_input || {};

    // Get file path based on tool
    let filePath = null;
    let estimatedLines = 0;
    let currentLines = 0;

    if (toolName === 'Edit') {
      filePath = resolveFilePath(toolInput.file_path);
      if (!filePath) process.exit(0);

      const result = estimateLinesAfterEdit(
        filePath,
        toolInput.old_string || '',
        toolInput.new_string || ''
      );
      currentLines = result.currentLines;
      estimatedLines = result.estimatedLines;
    } else if (toolName === 'Write') {
      filePath = resolveFilePath(toolInput.file_path);
      if (!filePath) process.exit(0);

      // For Write, check if file exists (update vs create)
      const existing = countLines(filePath);
      currentLines = existing.lines;

      // Estimate based on content being written
      estimatedLines = estimateLinesForWrite(toolInput.content || '');
    } else {
      // Not Edit or Write, allow
      process.exit(0);
    }

    // Check exclusions
    if (shouldExclude(filePath, config.excludePatterns)) {
      process.exit(0);
    }

    // Check thresholds
    const thresholdResult = checkThreshold(estimatedLines, config);

    if (thresholdResult.status === 'block') {
      // Block operation
      console.error(formatBlockMessage(
        filePath,
        currentLines,
        estimatedLines,
        config.blockThreshold
      ));
      process.exit(2);
    }

    if (thresholdResult.status === 'warn') {
      // Warn but allow
      console.error(formatWarningMessage(
        filePath,
        currentLines,
        estimatedLines,
        config.warnThreshold
      ));
      process.exit(0);
    }

    // OK - allow operation
    process.exit(0);

  } catch (error) {
    // Fail-open for unexpected errors
    console.error('WARN: file-size-guard hook error, allowing operation -', error.message);
    process.exit(0);
  }
}

main();
