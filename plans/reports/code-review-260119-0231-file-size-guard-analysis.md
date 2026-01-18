# Code Review: Claude File Size Guard v1.0.0

**Date:** 2026-01-19 | **Reviewer:** Claude Code | **Status:** Complete

---

## Executive Summary

Hook enforces modular code by warning (120 lines) and blocking (200 lines) file operations. **Verdict: Good tool for enforcing best practices with room for improvement.**

### Should You Use It?

| Use Case | Recommendation |
|----------|----------------|
| Learning modular coding | ✅ Highly recommended |
| Team standardization | ✅ Recommended |
| Solo experienced dev | ⚠️ May be restrictive |
| Complex algorithms/state machines | ⚠️ Needs file whitelist |

---

## Architecture Analysis

### File Structure (Well-organized)
```
src/hooks/
├── file-size-guard.cjs (180 lines) - Entry point
└── file-size-guard/
    ├── line-counter.cjs (84 lines)     - Line counting
    ├── threshold-checker.cjs (93 lines) - Threshold logic
    └── suggestion-generator.cjs (168 lines) - Messages
```

### Strengths
1. **Modular design** - Properly separated concerns
2. **Fail-open strategy** - Errors don't block user workflow
3. **Clear documentation** - Good inline comments
4. **Configurable** - Thresholds/exclusions via `.ck.json`
5. **Multi-location config** - Searches project then global

---

## Issues Identified

### Critical Issues

#### 1. `replace_all` Parameter Not Handled
```javascript
// file-size-guard.cjs:117-123
const result = estimateLinesAfterEdit(
  filePath,
  toolInput.old_string || '',
  toolInput.new_string || ''
);
// MISSING: toolInput.replace_all handling
```
**Impact:** If `replace_all=true`, estimation is wrong (calculates single replacement, not all occurrences).

#### 2. No Per-File Override Mechanism
Large files like state machines, protocol handlers, or complex algorithms legitimately need >200 lines. Currently no way to whitelist specific files.

### Performance Issues

#### 3. Config Loaded Every Hook Call
```javascript
// file-size-guard.cjs:45-62
function loadCkConfig() {
  // Reads file system on EVERY Edit/Write operation
  for (const configPath of searchPaths) {
    if (fs.existsSync(configPath)) {
      return JSON.parse(fs.readFileSync(configPath, 'utf-8'));
    }
  }
}
```
**Impact:** Extra I/O on every file operation. Not major but unnecessary.

#### 4. Full File Read for Line Count
```javascript
// line-counter.cjs:44-45
const content = fs.readFileSync(filePath, 'utf-8');
const lines = content.split('\n').length;
```
**Impact:** Reading multi-MB files into memory just to count newlines.

### Minor Issues

#### 5. ReDoS Potential in Custom Patterns
```javascript
// threshold-checker.cjs:79-81
excludePatterns: fileSizeGuard.excludePatterns
  ? fileSizeGuard.excludePatterns.map(p => new RegExp(p))
  // User-provided regex without validation
```
**Risk:** Malicious/accidental catastrophic backtracking patterns.

#### 6. Missing Test File Support in Defaults
Default exclusions include `__fixtures__/`, `__snapshots__/` but miss `.spec.ts`, `.test.tsx` test files.

---

## Impact on Large Logic Files

### Scenario: Complex Single-File Requirements

Some code legitimately requires single-file structure:
- State machines with many states
- Protocol decoders/encoders
- Mathematical algorithms
- Generated code wrappers
- Legacy integration adapters

### Current Workarounds
1. Disable globally via toggle script (loses all protection)
2. Add file extension to excludePatterns (too broad)
3. Increase blockThreshold globally (reduces effectiveness)

### Recommended Solution
Per-file inline directive: `// @file-size-guard: max-lines=500`

---

## Harmful Effects Assessment

### Potential Negatives
| Risk | Severity | Mitigation |
|------|----------|------------|
| Blocks legitimate large files | Medium | Add whitelist mechanism |
| Interrupts flow during complex work | Low | Toggle script available |
| Incorrect estimation for `replace_all` | Medium | Fix in code |
| Learning curve for micro-extract | Low | Good suggestions provided |

### Benefits Outweigh Risks
- Prevents 1000+ line files that are hard to maintain
- Teaches extraction patterns proactively
- Catches file bloat early vs during code review
- Easy toggle when needed

---

## Upgrade Recommendations

### Priority 1: Fix `replace_all` Handling

```javascript
// In file-size-guard.cjs, update Edit handling:
if (toolName === 'Edit') {
  const result = estimateLinesAfterEdit(
    filePath,
    toolInput.old_string || '',
    toolInput.new_string || '',
    toolInput.replace_all || false  // ADD THIS
  );
}

// In line-counter.cjs:
function estimateLinesAfterEdit(filePath, oldString, newString, replaceAll = false) {
  const { lines: currentLines, content } = countLinesWithContent(filePath);

  if (replaceAll && content) {
    const occurrences = content.split(oldString).length - 1;
    const delta = (newString.split('\n').length - oldString.split('\n').length) * occurrences;
    return { currentLines, estimatedLines: currentLines + delta, delta };
  }

  // Original single-replacement logic
  const delta = newString.split('\n').length - oldString.split('\n').length;
  return { currentLines, estimatedLines: currentLines + delta, delta };
}
```

### Priority 2: Add File-Level Override

Support inline directive in files:
```javascript
// @file-size-guard: max-lines=500
// or
// @file-size-guard: disabled
```

Implementation in `threshold-checker.cjs`:
```javascript
function getFileOverride(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const match = content.match(/@file-size-guard:\s*(max-lines=(\d+)|disabled)/);
  if (match) {
    if (match[1] === 'disabled') return { disabled: true };
    if (match[2]) return { maxLines: parseInt(match[2], 10) };
  }
  return null;
}
```

### Priority 3: Add Path Whitelist to Config

```json
{
  "fileSizeGuard": {
    "whitelistPaths": [
      "src/generated/",
      "src/protocols/parser.ts",
      "lib/state-machine.js"
    ]
  }
}
```

### Priority 4: Streaming Line Count for Large Files

```javascript
function countLinesStream(filePath) {
  return new Promise((resolve) => {
    let count = 0;
    fs.createReadStream(filePath)
      .on('data', (chunk) => {
        for (let i = 0; i < chunk.length; i++) {
          if (chunk[i] === 10) count++; // newline char
        }
      })
      .on('end', () => resolve(count + 1))
      .on('error', () => resolve(0));
  });
}
```

### Priority 5: Add Common Test Patterns to Defaults

```javascript
const DEFAULT_EXCLUDE_PATTERNS = [
  // ... existing patterns ...
  /\.test\.(ts|tsx|js|jsx)$/,
  /\.spec\.(ts|tsx|js|jsx)$/,
  /_test\.go$/,
  /test_.*\.py$/
];
```

---

## Conclusion

### Overall Assessment: **7.5/10**

| Category | Score | Notes |
|----------|-------|-------|
| Code quality | 8/10 | Clean, modular, well-documented |
| Functionality | 7/10 | Core works, missing edge cases |
| Performance | 7/10 | Minor inefficiencies |
| Usability | 7/10 | Good UX, needs more flexibility |
| Maintainability | 8/10 | Easy to extend |

### Final Verdict

**Recommended for use** with these caveats:
1. Great for enforcing modular patterns from start
2. Implement Priority 1-3 upgrades for production use
3. May need higher thresholds for certain project types
4. Toggle available when legitimately needed

---

## Unresolved Questions

1. Should streaming line count be async? (Would change hook execution model)
2. Should per-file overrides require specific comment syntax or be flexible?
3. Should there be a "soft block" mode (warn but allow with confirmation)?
