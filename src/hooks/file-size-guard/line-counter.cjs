/**
 * line-counter.cjs - Count lines in a file
 *
 * Handles various edge cases:
 * - Non-existent files (returns 0)
 * - Binary files (skipped)
 * - Empty files (returns 0)
 */

const fs = require('fs');
const path = require('path');

// Binary file extensions to skip
const BINARY_EXTENSIONS = new Set([
  '.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.svg',
  '.woff', '.woff2', '.ttf', '.eot', '.otf',
  '.pdf', '.zip', '.tar', '.gz', '.rar',
  '.mp3', '.mp4', '.avi', '.mov', '.webm',
  '.exe', '.dll', '.so', '.dylib',
  '.db', '.sqlite', '.lock'
]);

/**
 * Check if file is likely binary based on extension
 */
function isBinaryFile(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return BINARY_EXTENSIONS.has(ext);
}

/**
 * Count lines in a file
 */
function countLines(filePath) {
  try {
    if (!fs.existsSync(filePath)) {
      return { lines: 0, exists: false, isBinary: false, error: null };
    }

    if (isBinaryFile(filePath)) {
      return { lines: 0, exists: true, isBinary: true, error: null };
    }

    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n').length;

    return { lines, exists: true, isBinary: false, error: null };
  } catch (error) {
    return { lines: 0, exists: false, isBinary: false, error: error.message };
  }
}

/**
 * Estimate lines after edit operation
 */
function estimateLinesAfterEdit(filePath, oldString, newString) {
  const { lines: currentLines } = countLines(filePath);

  const oldLines = (oldString || '').split('\n').length;
  const newLines = (newString || '').split('\n').length;
  const delta = newLines - oldLines;

  return {
    currentLines,
    estimatedLines: currentLines + delta,
    delta
  };
}

/**
 * Estimate lines for new file (Write tool)
 */
function estimateLinesForWrite(content) {
  if (!content) return 0;
  return content.split('\n').length;
}

module.exports = {
  countLines,
  estimateLinesAfterEdit,
  estimateLinesForWrite,
  isBinaryFile
};
