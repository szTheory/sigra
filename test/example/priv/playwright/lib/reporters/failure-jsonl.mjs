// Phase 253 plan 59 (D-24): incremental per-test JSONL reporter.
//
// Playwright's list and json reporters only surface failure text at onEnd, so a CLI killed at
// its deadline leaves no per-test error text. This reporter appends one fsync'd JSON line at
// every onTestEnd, so every finished test survives a kill. It is dependency-free and is only
// registered when SIGRA_PLAYWRIGHT_FAILURE_JSONL names an output path (see playwright.config.ts).
import fs from 'node:fs';
import path from 'node:path';

export const FAILURE_JSONL_SCHEMA = 'sigra.phase253.playwright-test-end/v1';
export const RUN_ERROR_JSONL_SCHEMA = 'sigra.phase253.playwright-run-error/v1';
export const MAX_ERROR_MESSAGE_BYTES = 8192;

// eslint-disable-next-line no-control-regex
const ANSI = /\u001b\[[0-9;?]*[ -/]*[@-~]/g;

function truncateUtf8(text, maxBytes) {
  const buffer = Buffer.from(text, 'utf8');
  if (buffer.length <= maxBytes) return text;
  let end = maxBytes;
  // Do not cut a multi-byte sequence in half.
  while (end > 0 && (buffer[end] & 0xc0) === 0x80) end -= 1;
  return buffer.subarray(0, end).toString('utf8');
}

function describeError(error) {
  const raw = String(error?.message ?? error?.value ?? error ?? '');
  const location = error?.location
    ? { file: error.location.file ?? null, line: error.location.line ?? null, column: error.location.column ?? null }
    : null;
  return { message: truncateUtf8(raw.replace(ANSI, ''), MAX_ERROR_MESSAGE_BYTES), location };
}

export default class FailureJsonlReporter {
  constructor(options = {}) {
    this.outputFile = options.outputFile;
    if (!this.outputFile) throw new Error('failure-jsonl reporter requires an outputFile');
    this.invocationId = options.invocationId ?? process.env.SIGRA_CI_INVOCATION_ID ?? null;
    this.nativeIdentity = options.nativeIdentity ?? process.env.SIGRA_CI_NATIVE_IDENTITY ?? null;
    fs.mkdirSync(path.dirname(path.resolve(this.outputFile)), { recursive: true });
  }

  printsToStdio() { return false; }

  append(line) {
    const fd = fs.openSync(this.outputFile, 'a');
    try {
      fs.writeSync(fd, `${JSON.stringify(line)}\n`);
      fs.fsyncSync(fd);
    } finally {
      fs.closeSync(fd);
    }
  }

  onTestEnd(test, result) {
    const line = {
      schema: FAILURE_JSONL_SCHEMA,
      invocation_id: this.invocationId,
      native_identity: this.nativeIdentity,
      project: test.parent?.project?.()?.name ?? null,
      title: test.title,
      file: test.location?.file ?? null,
      line: test.location?.line ?? null,
      status: result.status,
      expected_status: test.expectedStatus ?? null,
      ok: typeof test.ok === 'function' ? test.ok() : result.status === (test.expectedStatus ?? 'passed'),
      duration_ms: result.duration,
      retry: result.retry,
      errors: (result.errors ?? (result.error ? [result.error] : [])).map(describeError),
    };
    this.append(line);
  }

  onError(error) {
    this.append({
      schema: RUN_ERROR_JSONL_SCHEMA,
      type: 'error',
      invocation_id: this.invocationId,
      native_identity: this.nativeIdentity,
      error: describeError(error),
    });
  }
}
