/**
 * suggestion-generator.cjs - Generate micro-extract suggestions
 *
 * Provides actionable suggestions for splitting large files
 * following the micro-extract pattern (extract new code to new files)
 */

const path = require('path');

/**
 * Generate file name suggestion for extracted module
 */
function generateExtractedFileName(originalPath, suffix) {
  const dir = path.dirname(originalPath);
  const ext = path.extname(originalPath);
  const base = path.basename(originalPath, ext);

  return path.join(dir, `${base}-${suffix}${ext}`);
}

/**
 * Generate micro-extract suggestion based on file type
 */
function generateSuggestion(filePath, currentLines, estimatedLines) {
  const ext = path.extname(filePath).toLowerCase();
  const delta = estimatedLines - currentLines;

  const suggestion = {
    action: 'micro-extract',
    reason: `File will have ${estimatedLines} lines (adding ${delta} lines)`,
    steps: [],
    newFiles: []
  };

  switch (ext) {
    case '.ts':
    case '.tsx':
    case '.js':
    case '.jsx':
      suggestion.steps = [
        'Extract the NEW function/component to a separate file',
        'Keep existing code unchanged in original file',
        'Add import statement to original file',
        'Export from new file'
      ];
      suggestion.newFiles = [
        generateExtractedFileName(filePath, 'utils'),
        generateExtractedFileName(filePath, 'types'),
        generateExtractedFileName(filePath, 'helpers')
      ];
      suggestion.example = `
// Instead of adding to ${path.basename(filePath)}:
// export function newFunction() { ... }

// Create ${path.basename(filePath, ext)}-utils${ext}:
export function newFunction() { ... }

// Then import in ${path.basename(filePath)}:
import { newFunction } from './${path.basename(filePath, ext)}-utils';
`;
      break;

    case '.py':
      suggestion.steps = [
        'Extract the NEW function/class to a separate module',
        'Keep existing code unchanged in original file',
        'Add import statement to original file'
      ];
      suggestion.newFiles = [
        generateExtractedFileName(filePath, 'utils'),
        generateExtractedFileName(filePath, 'helpers')
      ];
      suggestion.example = `
# Instead of adding to ${path.basename(filePath)}:
# def new_function(): ...

# Create ${path.basename(filePath, ext)}_utils${ext}:
def new_function():
    ...

# Then import in ${path.basename(filePath)}:
from .${path.basename(filePath, ext)}_utils import new_function
`;
      break;

    case '.rs':
      suggestion.steps = [
        'Extract the NEW function/struct to a separate module',
        'Add mod declaration to parent module',
        'Use pub use for re-exports if needed'
      ];
      suggestion.newFiles = [
        generateExtractedFileName(filePath, 'utils'),
        generateExtractedFileName(filePath, 'types')
      ];
      break;

    default:
      suggestion.steps = [
        'Extract new code to a separate file',
        'Import/include in original file',
        'Keep original file unchanged'
      ];
  }

  return suggestion;
}

/**
 * Format warning message for console output
 */
function formatWarningMessage(filePath, currentLines, estimatedLines, threshold) {
  const suggestion = generateSuggestion(filePath, currentLines, estimatedLines);

  return `
\x1b[33m⚠️  FILE SIZE WARNING\x1b[0m

\x1b[36mFile:\x1b[0m      ${filePath}
\x1b[36mCurrent:\x1b[0m   ${currentLines} lines
\x1b[36mAfter edit:\x1b[0m ${estimatedLines} lines
\x1b[36mThreshold:\x1b[0m ${threshold} lines

\x1b[33mRecommendation: Use MICRO-EXTRACT pattern\x1b[0m
${suggestion.steps.map((s, i) => `  ${i + 1}. ${s}`).join('\n')}

\x1b[36mSuggested new files:\x1b[0m
${suggestion.newFiles.map(f => `  - ${path.basename(f)}`).join('\n')}

\x1b[2mThis warning helps prevent large refactors later.\x1b[0m
\x1b[2mOperation will continue - consider extracting new code to separate file.\x1b[0m
`;
}

/**
 * Format block message for console output
 */
function formatBlockMessage(filePath, currentLines, estimatedLines, threshold) {
  const suggestion = generateSuggestion(filePath, currentLines, estimatedLines);

  return `
\x1b[31m🚫 FILE SIZE LIMIT EXCEEDED\x1b[0m

\x1b[36mFile:\x1b[0m      ${filePath}
\x1b[36mCurrent:\x1b[0m   ${currentLines} lines
\x1b[36mAfter edit:\x1b[0m ${estimatedLines} lines
\x1b[36mLimit:\x1b[0m     ${threshold} lines

\x1b[31mOperation BLOCKED - File too large\x1b[0m

\x1b[33mRequired action: MICRO-EXTRACT before adding code\x1b[0m
${suggestion.steps.map((s, i) => `  ${i + 1}. ${s}`).join('\n')}

\x1b[36mSuggested new files:\x1b[0m
${suggestion.newFiles.map(f => `  - ${path.basename(f)}`).join('\n')}
${suggestion.example ? `\n\x1b[36mExample:\x1b[0m${suggestion.example}` : ''}

\x1b[2mThis block prevents large refactors later.\x1b[0m
\x1b[2mExtract new code to a separate file, then retry.\x1b[0m
`;
}

module.exports = {
  generateSuggestion,
  generateExtractedFileName,
  formatWarningMessage,
  formatBlockMessage
};
