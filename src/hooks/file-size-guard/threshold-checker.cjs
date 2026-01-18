/**
 * threshold-checker.cjs - Check file size against thresholds
 *
 * Thresholds:
 * - warnThreshold (default 120): Inject warning, suggest micro-extract
 * - blockThreshold (default 200): Block operation, require refactor first
 *
 * File-level overrides (inline comments):
 * - // @file-size-guard: max-lines=500
 * - // @file-size-guard: disabled
 * - # @file-size-guard: max-lines=500  (for Python/Shell)
 */

const fs = require('fs');
const path = require('path');

// Default thresholds
const DEFAULT_WARN_THRESHOLD = 120;
const DEFAULT_BLOCK_THRESHOLD = 200;

// File patterns to exclude from checks
const DEFAULT_EXCLUDE_PATTERNS = [
  /package-lock\.json$/,
  /pnpm-lock\.yaml$/,
  /yarn\.lock$/,
  /Cargo\.lock$/,
  /poetry\.lock$/,
  /\.min\.(js|css)$/,
  /\.bundle\.(js|css)$/,
  /\.generated\./,
  /\.d\.ts$/,
  /\.config\.(js|ts|cjs|mjs)$/,
  /tsconfig.*\.json$/,
  /\.eslintrc/,
  /\.prettierrc/,
  /\.json$/,
  /\.yaml$/,
  /\.yml$/,
  /\.toml$/,
  /\.xml$/,
  /\.md$/,
  /\.mdx$/,
  /\.rst$/,
  /\.txt$/,
  /__fixtures__\//,
  /__snapshots__\//,
  /\.snap$/,
  // Test file patterns
  /\.test\.(ts|tsx|js|jsx|mjs|cjs)$/,
  /\.spec\.(ts|tsx|js|jsx|mjs|cjs)$/,
  /_test\.go$/,
  /test_.*\.py$/,
  /.*_test\.py$/
];

/**
 * Parse file-level override from inline comment
 * Supports: // @file-size-guard: max-lines=500
 *           // @file-size-guard: disabled
 *           # @file-size-guard: max-lines=500  (Python/Shell)
 *
 * Optimized: Only reads first 4KB (enough for ~50 lines)
 */
function getFileOverride(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;

    // Check if it's a regular file (not symlink, directory, etc.)
    const stats = fs.lstatSync(filePath);
    if (!stats.isFile()) return null;

    // Read only first 4KB for performance (directive must be near top)
    const fd = fs.openSync(filePath, 'r');
    const buffer = Buffer.alloc(4096);
    const bytesRead = fs.readSync(fd, buffer, 0, 4096, 0);
    fs.closeSync(fd);

    if (bytesRead === 0) return null;

    // Convert buffer to string, handling potential encoding issues
    const content = buffer.slice(0, bytesRead).toString('utf-8');

    // Match both // and # comment styles
    const match = content.match(/@file-size-guard:\s*(max-lines=(\d+)|disabled)/i);

    if (match) {
      if (match[1].toLowerCase() === 'disabled') {
        return { disabled: true };
      }
      if (match[2]) {
        return { maxLines: parseInt(match[2], 10) };
      }
    }
    return null;
  } catch {
    return null; // Fail-safe: return null on any error
  }
}

/**
 * Check if file path matches any whitelist pattern
 */
function isWhitelisted(filePath, whitelistPaths = []) {
  if (!whitelistPaths.length) return false;
  const normalizedPath = filePath.replace(/\\/g, '/');
  return whitelistPaths.some(pattern => {
    // Support glob-like patterns (simple prefix match)
    const normalizedPattern = pattern.replace(/\\/g, '/');
    return normalizedPath.includes(normalizedPattern);
  });
}

/**
 * Check if file should be excluded from size checks
 */
function shouldExclude(filePath, excludePatterns = DEFAULT_EXCLUDE_PATTERNS) {
  const normalizedPath = filePath.replace(/\\/g, '/');
  return excludePatterns.some(pattern => pattern.test(normalizedPath));
}

/**
 * Check lines against thresholds
 */
function checkThreshold(lines, config = {}) {
  const warnThreshold = config.warnThreshold || DEFAULT_WARN_THRESHOLD;
  const blockThreshold = config.blockThreshold || DEFAULT_BLOCK_THRESHOLD;

  if (lines >= blockThreshold) {
    return { status: 'block', threshold: blockThreshold, lines };
  }

  if (lines >= warnThreshold) {
    return { status: 'warn', threshold: warnThreshold, lines };
  }

  return { status: 'ok', threshold: warnThreshold, lines };
}

/**
 * Safely create RegExp from string, returns null if invalid
 */
function safeRegExp(pattern) {
  try {
    return new RegExp(pattern);
  } catch {
    return null; // Invalid regex, skip it
  }
}

/**
 * Get threshold config from .ck.json
 * Validates custom regex patterns to prevent crashes
 */
function getThresholdConfig(ckConfig) {
  const fileSizeGuard = ckConfig?.fileSizeGuard || {};

  // Parse custom exclude patterns with validation
  let excludePatterns = DEFAULT_EXCLUDE_PATTERNS;
  if (Array.isArray(fileSizeGuard.excludePatterns)) {
    const customPatterns = fileSizeGuard.excludePatterns
      .map(p => safeRegExp(p))
      .filter(p => p !== null); // Remove invalid patterns
    if (customPatterns.length > 0) {
      excludePatterns = customPatterns;
    }
  }

  return {
    warnThreshold: fileSizeGuard.warnThreshold || DEFAULT_WARN_THRESHOLD,
    blockThreshold: fileSizeGuard.blockThreshold || DEFAULT_BLOCK_THRESHOLD,
    excludePatterns,
    whitelistPaths: Array.isArray(fileSizeGuard.whitelistPaths)
      ? fileSizeGuard.whitelistPaths
      : []
  };
}

module.exports = {
  checkThreshold,
  shouldExclude,
  getThresholdConfig,
  getFileOverride,
  isWhitelisted,
  DEFAULT_WARN_THRESHOLD,
  DEFAULT_BLOCK_THRESHOLD,
  DEFAULT_EXCLUDE_PATTERNS
};
