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
 * Check if path is a regular file (not symlink, directory, etc.)
 */
function isRegularFile(filePath) {
  try {
    const stats = fs.lstatSync(filePath);
    return stats.isFile();
  } catch {
    return false;
  }
}

/**
 * Count lines in a file (with optional content return for replace_all estimation)
 * Handles edge cases: non-existent, binary, symlinks, encoding errors
 *
 * Note: For non-existent files, returns lines: 0, exists: false
 * The hook uses estimateLinesForWrite() for new file content separately
 */
function countLines(filePath, returnContent = false) {
  try {
    // Check existence first
    if (!fs.existsSync(filePath)) {
      return { lines: 0, exists: false, isBinary: false, error: null, content: null };
    }

    // Skip non-regular files (symlinks, directories, etc.)
    // Only check if file exists to avoid false positives
    if (!isRegularFile(filePath)) {
      return { lines: 0, exists: true, isBinary: false, error: 'not-regular-file', content: null };
    }

    if (isBinaryFile(filePath)) {
      return { lines: 0, exists: true, isBinary: true, error: null, content: null };
    }

    // Read file with error handling for encoding issues
    let content;
    try {
      content = fs.readFileSync(filePath, 'utf-8');
    } catch (readError) {
      // File might have encoding issues, treat as binary
      return { lines: 0, exists: true, isBinary: true, error: 'encoding-error', content: null };
    }

    const lines = content.split('\n').length;

    return {
      lines,
      exists: true,
      isBinary: false,
      error: null,
      content: returnContent ? content : null
    };
  } catch (error) {
    return { lines: 0, exists: false, isBinary: false, error: error.message, content: null };
  }
}

/**
 * Estimate lines after edit operation
 * Handles both single replacement and replace_all mode
 */
function estimateLinesAfterEdit(filePath, oldString, newString, replaceAll = false) {
  // For replace_all, we need the file content to count occurrences
  const { lines: currentLines, content } = countLines(filePath, replaceAll);

  const oldLines = (oldString || '').split('\n').length;
  const newLines = (newString || '').split('\n').length;
  const lineDelta = newLines - oldLines;

  // If replace_all and we have content, count all occurrences
  if (replaceAll && content && oldString) {
    const occurrences = content.split(oldString).length - 1;
    const totalDelta = lineDelta * Math.max(occurrences, 1);
    return {
      currentLines,
      estimatedLines: currentLines + totalDelta,
      delta: totalDelta,
      occurrences
    };
  }

  // Single replacement (default behavior)
  return {
    currentLines,
    estimatedLines: currentLines + lineDelta,
    delta: lineDelta,
    occurrences: 1
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
  isBinaryFile,
  isRegularFile
};
