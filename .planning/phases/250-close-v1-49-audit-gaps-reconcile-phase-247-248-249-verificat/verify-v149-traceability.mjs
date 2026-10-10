export function audit(_root, _options = {}) {
  return {
    capturedAt: 'pending',
    status: 'pending',
    score: { requirements: '0/0' },
    requirements: [],
    blockers: [],
  };
}
