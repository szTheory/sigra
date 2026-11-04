import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// Exercise the shipped Socket class itself without evaluating unrelated DOM
// bootstrap code or copying the methods into a second implementation.
const bundle = readFileSync(new URL('../../test/example/priv/static/assets/js/app.js', import.meta.url), 'utf8');
const socketSource = bundle.match(/\n  var L = class \{[\s\S]*?\n  \};\n/)?.[0];
assert.ok(socketSource?.includes('transportConnect()'), 'shipped Phoenix Socket class is available');

function harness() {
  const events = [];
  const timers = new Map();
  let nextTimer = 0;
  const setTimer = (callback) => { const id = ++nextTimer; timers.set(id, callback); return id; };
  const clearTimer = (id) => timers.delete(id);
  const transports = [];
  class Primary {
    constructor(url, protocols) {
      Object.assign(this, { url, protocols, readyState: 0, bufferedAmount: 0 });
      transports.push(this);
    }
    close() {
      this.beforeClose?.();
      this.readyState = 3;
      this.onclose?.({ code: 1000 });
    }
  }
  class Fallback extends Primary { constructor(...args) { super(...args); this.skipHeartbeat = true; } }
  const Socket = vm.runInNewContext(`${socketSource}\nL;`, {
    clearTimeout: clearTimer, setTimeout: setTimer,
    g: Fallback, p: { connecting: 0, open: 1, closing: 2, closed: 3 },
    m: { error: 'phx_error' },
  });
  const socket = Object.create(Socket.prototype);
  Object.assign(socket, {
    conn: null, transport: Primary, connectClock: 1, closeWasClean: true,
    binaryType: 'arraybuffer', longpollerTimeout: 20000, authToken: null,
    fallbackTimer: null, fallbackRef: null, longPollFallbackMs: null,
    heartbeatTimer: null, heartbeatTimeoutTimer: null, pendingHeartbeatRef: null,
    reconnectTimer: { reset() { events.push(['reconnect-reset']); } },
    endPointURL: () => 'ws://example.test/live/websocket',
    logger: null, sessionStore: null, ref: 0, channels: [],
    stateChangeCallbacks: { open: [], close: [], error: [], message: [] },
    onConnOpen: () => events.push(['open']),
    onConnError: (event) => events.push(['error', event]),
    onConnMessage: (event) => events.push(['message', event]),
    onConnClose: (event) => events.push(['close', event]),
  });
  function channel(state = 'joining', callback = () => {}) {
    return {
      state, errors: 0,
      isErrored() { return this.state === 'errored'; },
      isLeaving() { return this.state === 'leaving'; },
      isClosed() { return this.state === 'closed'; },
      trigger(event) { assert.equal(event, 'phx_error'); this.state = 'errored'; this.errors++; callback(); },
    };
  }
  return { socket, Primary, Fallback, events, transports, timers, setTimer, channel };
}

function dispatch(transport) {
  transport.onopen({ type: 'open' });
  transport.onerror({ type: 'error' });
  transport.onmessage({ type: 'message' });
  transport.onclose({ type: 'close' });
}

test('current physical connection dispatches all four events and keeps transport options', () => {
  const { socket, events } = harness();
  socket.transportConnect();
  assert.equal(socket.conn.url, 'ws://example.test/live/websocket');
  assert.equal(socket.conn.binaryType, 'arraybuffer');
  assert.equal(socket.conn.timeout, 20000);
  dispatch(socket.conn);
  assert.deepEqual(events.map(([name]) => name), ['open', 'error', 'message', 'close']);
  assert.equal(events[1][1].type, 'error');
  assert.equal(events[2][1].type, 'message');
  assert.equal(events[3][1].type, 'close');
});

test('all four stale callbacks are ignored even when the replacement uses the same constructor', () => {
  const { socket, Primary, events } = harness();
  socket.transportConnect();
  const previous = socket.conn;
  socket.replaceTransport(Primary);
  socket.transportConnect();
  const current = socket.conn;
  events.length = 0;
  dispatch(previous);
  assert.equal(socket.conn, current);
  assert.deepEqual(events, []);
  dispatch(current);
  assert.deepEqual(events.map(([name]) => name), ['open', 'error', 'message', 'close']);
});

test('handoff retires connection and heartbeat state before synchronous close or channel callbacks', () => {
  const { socket, Fallback, events, timers, setTimer, channel } = harness();
  socket.transportConnect();
  const previous = socket.conn;
  socket.pendingHeartbeatRef = 'old-heartbeat';
  socket.heartbeatTimer = setTimer(() => assert.fail('retired heartbeat fired'));
  socket.heartbeatTimeoutTimer = setTimer(() => socket.heartbeatTimeout());
  const heartbeat = socket.heartbeatTimer;
  const heartbeatTimeout = socket.heartbeatTimeoutTimer;
  const queuedHeartbeatTimeout = timers.get(heartbeatTimeout);
  previous.beforeClose = () => {
    assert.equal(socket.conn, null);
    assert.equal(socket.transport, Fallback);
  };
  const joining = channel('joining', () => {
    assert.equal(socket.conn, null);
    assert.equal(socket.transport, Fallback);
    assert.equal(socket.pendingHeartbeatRef, null);
    assert.equal(timers.has(heartbeat), false);
    assert.equal(timers.has(heartbeatTimeout), false);
  });
  const leaving = channel('leaving');
  const closed = channel('closed');
  const errored = channel('errored');
  socket.channels = [joining, leaving, closed, errored];
  socket.replaceTransport(Fallback);
  assert.equal(joining.errors, 1);
  assert.equal(leaving.errors + closed.errors + errored.errors, 0);
  assert.equal(events.some(([name]) => name === 'close'), false);
  assert.equal(previous.readyState, 3);
  socket.transportConnect();
  const current = socket.conn;
  queuedHeartbeatTimeout();
  assert.equal(socket.conn, current, 'already queued retired timeout cannot tear down the new connection');
});

for (const action of ['connect', 'disconnect']) {
  test(`fallback respects a channel error callback that calls ${action}`, () => {
    const { socket, Fallback, transports, timers, channel } = harness();
    let callbacks = 0;
    socket.channels = [channel('joining', () => { callbacks++; socket[action](); })];
    socket.connectWithFallback(Fallback, 2500);
    const fallback = timers.get(socket.fallbackTimer);
    assert.equal(typeof fallback, 'function');
    fallback('controlled primary failure');
    assert.equal(callbacks, 1);
    const replacements = transports.filter((transport) => transport instanceof Fallback);
    assert.equal(replacements.length, action === 'connect' ? 1 : 0);
    assert.equal(socket.conn, action === 'connect' ? replacements[0] : null);
  });
}

test('late events after explicit disconnect cannot reopen or dispatch through a retired connection', () => {
  const { socket, events } = harness();
  socket.transportConnect();
  const previous = socket.conn;
  socket.disconnect();
  assert.equal(socket.conn, null);
  events.length = 0;
  dispatch(previous);
  assert.equal(socket.conn, null);
  assert.deepEqual(events, []);
});

test('reentrant open-property callback cannot replace the new connection handlers', () => {
  const { socket, Primary, Fallback, events } = harness();
  class OpenDuringBinding extends Primary {
    set onopen(callback) {
      this.openCallback = callback;
      socket.replaceTransport(Fallback);
      socket.transportConnect();
    }
    get onopen() { return this.openCallback; }
  }
  socket.transport = OpenDuringBinding;
  socket.onConnOpen = () => events.push(['open']);
  socket.transportConnect();
  assert.ok(socket.conn instanceof Fallback);
  events.length = 0;
  dispatch(socket.conn);
  assert.deepEqual(events.map(([name]) => name), ['open', 'error', 'message', 'close']);
});
