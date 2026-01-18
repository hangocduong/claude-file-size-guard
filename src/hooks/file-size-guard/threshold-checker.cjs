/**
 * threshold-checker.cjs - Check file size against thresholds
 *
 * Thresholds:
 * - warnThreshold (default 120): Inject warning, suggest micro-extract
 * - blockThreshold (default 200): Block operation, require refactor first
 */

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
  /\.snap$/
];

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
 * Get threshold config from .ck.json
 */
function getThresholdConfig(ckConfig) {
  const fileSizeGuard = ckConfig?.fileSizeGuard || {};

  return {
    warnThreshold: fileSizeGuard.warnThreshold || DEFAULT_WARN_THRESHOLD,
    blockThreshold: fileSizeGuard.blockThreshold || DEFAULT_BLOCK_THRESHOLD,
    excludePatterns: fileSizeGuard.excludePatterns
      ? fileSizeGuard.excludePatterns.map(p => new RegExp(p))
      : DEFAULT_EXCLUDE_PATTERNS
  };
}

module.exports = {
  checkThreshold,
  shouldExclude,
  getThresholdConfig,
  DEFAULT_WARN_THRESHOLD,
  DEFAULT_BLOCK_THRESHOLD,
  DEFAULT_EXCLUDE_PATTERNS
};
