"use strict";

(function () {
  var PolyfillEvent = eventConstructor();

  function eventConstructor() {
    if (typeof window.CustomEvent === "function") return window.CustomEvent;
    // IE<=9 Support
    function CustomEvent(event, params) {
      params = params || {
        bubbles: false,
        cancelable: false,
        detail: undefined,
      };
      var evt = document.createEvent("CustomEvent");
      evt.initCustomEvent(
        event,
        params.bubbles,
        params.cancelable,
        params.detail,
      );
      return evt;
    }
    CustomEvent.prototype = window.Event.prototype;
    return CustomEvent;
  }

  function buildHiddenInput(name, value) {
    var input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    input.value = value;
    return input;
  }

  function handleClick(element, targetModifierKey) {
    var to = element.getAttribute("data-to"),
      method = buildHiddenInput("_method", element.getAttribute("data-method")),
      csrf = buildHiddenInput("_csrf_token", element.getAttribute("data-csrf")),
      form = document.createElement("form"),
      submit = document.createElement("input"),
      target = element.getAttribute("target");

    form.method =
      element.getAttribute("data-method") === "get" ? "get" : "post";
    form.action = to;
    form.style.display = "none";

    if (target) form.target = target;
    else if (targetModifierKey) form.target = "_blank";

    form.appendChild(csrf);
    form.appendChild(method);
    document.body.appendChild(form);

    // Insert a button and click it instead of using `form.submit`
    // because the `submit` function does not emit a `submit` event.
    submit.type = "submit";
    form.appendChild(submit);
    submit.click();
  }

  window.addEventListener(
    "click",
    function (e) {
      var element = e.target;
      if (e.defaultPrevented) return;

      while (element && element.getAttribute) {
        var phoenixLinkEvent = new PolyfillEvent("phoenix.link.click", {
          bubbles: true,
          cancelable: true,
        });

        if (!element.dispatchEvent(phoenixLinkEvent)) {
          e.preventDefault();
          e.stopImmediatePropagation();
          return false;
        }

        if (
          element.getAttribute("data-method") &&
          element.getAttribute("data-to")
        ) {
          handleClick(element, e.metaKey || e.shiftKey);
          e.preventDefault();
          return false;
        } else {
          element = element.parentNode;
        }
      }
    },
    false,
  );

  window.addEventListener(
    "phoenix.link.click",
    function (e) {
      var message = e.target.getAttribute("data-confirm");
      if (message && !window.confirm(message)) {
        e.preventDefault();
      }
    },
    false,
  );
})();
var Phoenix = (() => {
  var _ = Object.defineProperty;
  var $ = Object.getOwnPropertyDescriptor;
  var M = Object.getOwnPropertyNames;
  var U = Object.prototype.hasOwnProperty;
  var D = (a, e) => {
      for (var t in e) _(a, t, { get: e[t], enumerable: !0 });
    },
    I = (a, e, t, i) => {
      if ((e && typeof e == "object") || typeof e == "function")
        for (let s of M(e))
          !U.call(a, s) &&
            s !== t &&
            _(a, s, {
              get: () => e[s],
              enumerable: !(i = $(e, s)) || i.enumerable,
            });
      return a;
    };
  var F = (a) => I(_({}, "__esModule", { value: !0 }), a);
  var W = {};
  D(W, {
    Channel: () => k,
    LongPoll: () => g,
    Presence: () => w,
    Serializer: () => y,
    Socket: () => L,
  });
  var S = (a) =>
    typeof a == "function"
      ? a
      : function () {
          return a;
        };
  var J = typeof self != "undefined" ? self : null,
    R = typeof window != "undefined" ? window : null,
    d = J || R || globalThis,
    H = "2.0.0",
    p = { connecting: 0, open: 1, closing: 2, closed: 3 },
    O = 1e4,
    P = 1e3,
    u = {
      closed: "closed",
      errored: "errored",
      joined: "joined",
      joining: "joining",
      leaving: "leaving",
    },
    m = {
      close: "phx_close",
      error: "phx_error",
      join: "phx_join",
      reply: "phx_reply",
      leave: "phx_leave",
    },
    j = { longpoll: "longpoll", websocket: "websocket" },
    B = { complete: 4 },
    A = "base64url.bearer.phx.";
  var b = class {
    constructor(e, t, i, s) {
      ((this.channel = e),
        (this.event = t),
        (this.payload =
          i ||
          function () {
            return {};
          }),
        (this.receivedResp = null),
        (this.timeout = s),
        (this.timeoutTimer = null),
        (this.recHooks = []),
        (this.sent = !1));
    }
    resend(e) {
      ((this.timeout = e), this.reset(), this.send());
    }
    send() {
      this.hasReceived("timeout") ||
        (this.startTimeout(),
        (this.sent = !0),
        this.channel.socket.push({
          topic: this.channel.topic,
          event: this.event,
          payload: this.payload(),
          ref: this.ref,
          join_ref: this.channel.joinRef(),
        }));
    }
    receive(e, t) {
      return (
        this.hasReceived(e) && t(this.receivedResp.response),
        this.recHooks.push({ status: e, callback: t }),
        this
      );
    }
    reset() {
      (this.cancelRefEvent(),
        (this.ref = null),
        (this.refEvent = null),
        (this.receivedResp = null),
        (this.sent = !1));
    }
    matchReceive({ status: e, response: t, _ref: i }) {
      this.recHooks.filter((s) => s.status === e).forEach((s) => s.callback(t));
    }
    cancelRefEvent() {
      this.refEvent && this.channel.off(this.refEvent);
    }
    cancelTimeout() {
      (clearTimeout(this.timeoutTimer), (this.timeoutTimer = null));
    }
    startTimeout() {
      (this.timeoutTimer && this.cancelTimeout(),
        (this.ref = this.channel.socket.makeRef()),
        (this.refEvent = this.channel.replyEventName(this.ref)),
        this.channel.on(this.refEvent, (e) => {
          (this.cancelRefEvent(),
            this.cancelTimeout(),
            (this.receivedResp = e),
            this.matchReceive(e));
        }),
        (this.timeoutTimer = setTimeout(() => {
          this.trigger("timeout", {});
        }, this.timeout)));
    }
    hasReceived(e) {
      return this.receivedResp && this.receivedResp.status === e;
    }
    trigger(e, t) {
      this.channel.trigger(this.refEvent, { status: e, response: t });
    }
  };
  var v = class {
    constructor(e, t) {
      ((this.callback = e),
        (this.timerCalc = t),
        (this.timer = null),
        (this.tries = 0));
    }
    reset() {
      ((this.tries = 0), clearTimeout(this.timer));
    }
    scheduleTimeout() {
      (clearTimeout(this.timer),
        (this.timer = setTimeout(
          () => {
            ((this.tries = this.tries + 1), this.callback());
          },
          this.timerCalc(this.tries + 1),
        )));
    }
  };
  var k = class {
    constructor(e, t, i) {
      ((this.state = u.closed),
        (this.topic = e),
        (this.params = S(t || {})),
        (this.socket = i),
        (this.bindings = []),
        (this.bindingRef = 0),
        (this.timeout = this.socket.timeout),
        (this.joinedOnce = !1),
        (this.joinPush = new b(this, m.join, this.params, this.timeout)),
        (this.pushBuffer = []),
        (this.stateChangeRefs = []),
        (this.rejoinTimer = new v(() => {
          this.socket.isConnected() && this.rejoin();
        }, this.socket.rejoinAfterMs)),
        this.stateChangeRefs.push(
          this.socket.onError(() => this.rejoinTimer.reset()),
        ),
        this.stateChangeRefs.push(
          this.socket.onOpen(() => {
            (this.rejoinTimer.reset(), this.isErrored() && this.rejoin());
          }),
        ),
        this.joinPush.receive("ok", () => {
          ((this.state = u.joined),
            this.rejoinTimer.reset(),
            this.pushBuffer.forEach((s) => s.send()),
            (this.pushBuffer = []));
        }),
        this.joinPush.receive("error", () => {
          ((this.state = u.errored),
            this.socket.isConnected() && this.rejoinTimer.scheduleTimeout());
        }),
        this.onClose(() => {
          (this.rejoinTimer.reset(),
            this.socket.hasLogger() &&
              this.socket.log(
                "channel",
                `close ${this.topic} ${this.joinRef()}`,
              ),
            (this.state = u.closed),
            this.socket.remove(this));
        }),
        this.onError((s) => {
          (this.socket.hasLogger() &&
            this.socket.log("channel", `error ${this.topic}`, s),
            this.isJoining() && this.joinPush.reset(),
            (this.state = u.errored),
            this.socket.isConnected() && this.rejoinTimer.scheduleTimeout());
        }),
        this.joinPush.receive("timeout", () => {
          (this.socket.hasLogger() &&
            this.socket.log(
              "channel",
              `timeout ${this.topic} (${this.joinRef()})`,
              this.joinPush.timeout,
            ),
            new b(this, m.leave, S({}), this.timeout).send(),
            (this.state = u.errored),
            this.joinPush.reset(),
            this.socket.isConnected() && this.rejoinTimer.scheduleTimeout());
        }),
        this.on(m.reply, (s, o) => {
          this.trigger(this.replyEventName(o), s);
        }));
    }
    join(e = this.timeout) {
      if (this.joinedOnce)
        throw new Error(
          "tried to join multiple times. 'join' can only be called a single time per channel instance",
        );
      return (
        (this.timeout = e),
        (this.joinedOnce = !0),
        this.rejoin(),
        this.joinPush
      );
    }
    onClose(e) {
      this.on(m.close, e);
    }
    onError(e) {
      return this.on(m.error, (t) => e(t));
    }
    on(e, t) {
      let i = this.bindingRef++;
      return (this.bindings.push({ event: e, ref: i, callback: t }), i);
    }
    off(e, t) {
      this.bindings = this.bindings.filter(
        (i) => !(i.event === e && (typeof t == "undefined" || t === i.ref)),
      );
    }
    canPush() {
      return this.socket.isConnected() && this.isJoined();
    }
    push(e, t, i = this.timeout) {
      if (((t = t || {}), !this.joinedOnce))
        throw new Error(
          `tried to push '${e}' to '${this.topic}' before joining. Use channel.join() before pushing events`,
        );
      let s = new b(
        this,
        e,
        function () {
          return t;
        },
        i,
      );
      return (
        this.canPush() ? s.send() : (s.startTimeout(), this.pushBuffer.push(s)),
        s
      );
    }
    leave(e = this.timeout) {
      (this.rejoinTimer.reset(),
        this.joinPush.cancelTimeout(),
        (this.state = u.leaving));
      let t = () => {
          (this.socket.hasLogger() &&
            this.socket.log("channel", `leave ${this.topic}`),
            this.trigger(m.close, "leave"));
        },
        i = new b(this, m.leave, S({}), e);
      return (
        i.receive("ok", () => t()).receive("timeout", () => t()),
        i.send(),
        this.canPush() || i.trigger("ok", {}),
        i
      );
    }
    onMessage(e, t, i) {
      return t;
    }
    isMember(e, t, i, s) {
      return this.topic !== e
        ? !1
        : s && s !== this.joinRef()
          ? (this.socket.hasLogger() &&
              this.socket.log("channel", "dropping outdated message", {
                topic: e,
                event: t,
                payload: i,
                joinRef: s,
              }),
            !1)
          : !0;
    }
    joinRef() {
      return this.joinPush.ref;
    }
    rejoin(e = this.timeout) {
      this.isLeaving() ||
        (this.socket.leaveOpenTopic(this.topic),
        (this.state = u.joining),
        this.joinPush.resend(e));
    }
    trigger(e, t, i, s) {
      let o = this.onMessage(e, t, i, s);
      if (t && !o)
        throw new Error(
          "channel onMessage callbacks must return the payload, modified or unmodified",
        );
      let r = this.bindings.filter((n) => n.event === e);
      for (let n = 0; n < r.length; n++)
        r[n].callback(o, i, s || this.joinRef());
    }
    replyEventName(e) {
      return `chan_reply_${e}`;
    }
    isClosed() {
      return this.state === u.closed;
    }
    isErrored() {
      return this.state === u.errored;
    }
    isJoined() {
      return this.state === u.joined;
    }
    isJoining() {
      return this.state === u.joining;
    }
    isLeaving() {
      return this.state === u.leaving;
    }
  };
  var T = class {
    static request(e, t, i, s, o, r, n) {
      if (d.XDomainRequest) {
        let h = new d.XDomainRequest();
        return this.xdomainRequest(h, e, t, s, o, r, n);
      } else if (d.XMLHttpRequest) {
        let h = new d.XMLHttpRequest();
        return this.xhrRequest(h, e, t, i, s, o, r, n);
      } else {
        if (d.fetch && d.AbortController)
          return this.fetchRequest(e, t, i, s, o, r, n);
        throw new Error("No suitable XMLHttpRequest implementation found");
      }
    }
    static fetchRequest(e, t, i, s, o, r, n) {
      let h = { method: e, headers: i, body: s },
        l = null;
      if (o) {
        l = new AbortController();
        let c = setTimeout(() => l.abort(), o);
        h.signal = l.signal;
      }
      return (
        d
          .fetch(t, h)
          .then((c) => c.text())
          .then((c) => this.parseJSON(c))
          .then((c) => n && n(c))
          .catch((c) => {
            c.name === "AbortError" && r ? r() : n && n(null);
          }),
        l
      );
    }
    static xdomainRequest(e, t, i, s, o, r, n) {
      return (
        (e.timeout = o),
        e.open(t, i),
        (e.onload = () => {
          let h = this.parseJSON(e.responseText);
          n && n(h);
        }),
        r && (e.ontimeout = r),
        (e.onprogress = () => {}),
        e.send(s),
        e
      );
    }
    static xhrRequest(e, t, i, s, o, r, n, h) {
      (e.open(t, i, !0), (e.timeout = r));
      for (let [l, c] of Object.entries(s)) e.setRequestHeader(l, c);
      return (
        (e.onerror = () => h && h(null)),
        (e.onreadystatechange = () => {
          if (e.readyState === B.complete && h) {
            let l = this.parseJSON(e.responseText);
            h(l);
          }
        }),
        n && (e.ontimeout = n),
        e.send(o),
        e
      );
    }
    static parseJSON(e) {
      if (!e || e === "") return null;
      try {
        return JSON.parse(e);
      } catch (t) {
        return (
          console && console.log("failed to parse JSON response", e),
          null
        );
      }
    }
    static serialize(e, t) {
      let i = [];
      for (var s in e) {
        if (!Object.prototype.hasOwnProperty.call(e, s)) continue;
        let o = t ? `${t}[${s}]` : s,
          r = e[s];
        typeof r == "object"
          ? i.push(this.serialize(r, o))
          : i.push(encodeURIComponent(o) + "=" + encodeURIComponent(r));
      }
      return i.join("&");
    }
    static appendParams(e, t) {
      if (Object.keys(t).length === 0) return e;
      let i = e.match(/\?/) ? "&" : "?";
      return `${e}${i}${this.serialize(t)}`;
    }
  };
  var z = (a) => {
      let e = "",
        t = new Uint8Array(a),
        i = t.byteLength;
      for (let s = 0; s < i; s++) e += String.fromCharCode(t[s]);
      return btoa(e);
    },
    g = class {
      constructor(e, t) {
        (t &&
          t.length === 2 &&
          t[1].startsWith(A) &&
          (this.authToken = atob(t[1].slice(A.length))),
          (this.endPoint = null),
          (this.token = null),
          (this.skipHeartbeat = !0),
          (this.reqs = new Set()),
          (this.awaitingBatchAck = !1),
          (this.currentBatch = null),
          (this.currentBatchTimer = null),
          (this.batchBuffer = []),
          (this.onopen = function () {}),
          (this.onerror = function () {}),
          (this.onmessage = function () {}),
          (this.onclose = function () {}),
          (this.pollEndpoint = this.normalizeEndpoint(e)),
          (this.readyState = p.connecting),
          setTimeout(() => this.poll(), 0));
      }
      normalizeEndpoint(e) {
        return e
          .replace("ws://", "http://")
          .replace("wss://", "https://")
          .replace(new RegExp("(.*)/" + j.websocket), "$1/" + j.longpoll);
      }
      endpointURL() {
        return T.appendParams(this.pollEndpoint, { token: this.token });
      }
      closeAndRetry(e, t, i) {
        (this.close(e, t, i), (this.readyState = p.connecting));
      }
      ontimeout() {
        (this.onerror("timeout"), this.closeAndRetry(1005, "timeout", !1));
      }
      isActive() {
        return this.readyState === p.open || this.readyState === p.connecting;
      }
      poll() {
        let e = { Accept: "application/json" };
        (this.authToken && (e["X-Phoenix-AuthToken"] = this.authToken),
          this.ajax(
            "GET",
            e,
            null,
            () => this.ontimeout(),
            (t) => {
              if (t) {
                var { status: i, token: s, messages: o } = t;
                if (i === 410 && this.token !== null) {
                  (this.onerror(410),
                    this.closeAndRetry(3410, "session_gone", !1));
                  return;
                }
                this.token = s;
              } else i = 0;
              switch (i) {
                case 200:
                  (o.forEach((r) => {
                    setTimeout(() => this.onmessage({ data: r }), 0);
                  }),
                    this.poll());
                  break;
                case 204:
                  this.poll();
                  break;
                case 410:
                  ((this.readyState = p.open), this.onopen({}), this.poll());
                  break;
                case 403:
                  (this.onerror(403), this.close(1008, "forbidden", !1));
                  break;
                case 0:
                case 500:
                  (this.onerror(500),
                    this.closeAndRetry(1011, "internal server error", 500));
                  break;
                default:
                  throw new Error(`unhandled poll status ${i}`);
              }
            },
          ));
      }
      send(e) {
        (typeof e != "string" && (e = z(e)),
          this.currentBatch
            ? this.currentBatch.push(e)
            : this.awaitingBatchAck
              ? this.batchBuffer.push(e)
              : ((this.currentBatch = [e]),
                (this.currentBatchTimer = setTimeout(() => {
                  (this.batchSend(this.currentBatch),
                    (this.currentBatch = null));
                }, 0))));
      }
      batchSend(e) {
        ((this.awaitingBatchAck = !0),
          this.ajax(
            "POST",
            { "Content-Type": "application/x-ndjson" },
            e.join(`
`),
            () => this.onerror("timeout"),
            (t) => {
              ((this.awaitingBatchAck = !1),
                !t || t.status !== 200
                  ? (this.onerror(t && t.status),
                    this.closeAndRetry(1011, "internal server error", !1))
                  : this.batchBuffer.length > 0 &&
                    (this.batchSend(this.batchBuffer),
                    (this.batchBuffer = [])));
            },
          ));
      }
      close(e, t, i) {
        for (let o of this.reqs) o.abort();
        this.readyState = p.closed;
        let s = Object.assign(
          { code: 1e3, reason: void 0, wasClean: !0 },
          { code: e, reason: t, wasClean: i },
        );
        ((this.batchBuffer = []),
          clearTimeout(this.currentBatchTimer),
          (this.currentBatchTimer = null),
          typeof CloseEvent != "undefined"
            ? this.onclose(new CloseEvent("close", s))
            : this.onclose(s));
      }
      ajax(e, t, i, s, o) {
        let r,
          n = () => {
            (this.reqs.delete(r), s());
          };
        ((r = T.request(e, this.endpointURL(), t, i, this.timeout, n, (h) => {
          (this.reqs.delete(r), this.isActive() && o(h));
        })),
          this.reqs.add(r));
      }
    };
  var w = class a {
    constructor(e, t = {}) {
      let i = t.events || { state: "presence_state", diff: "presence_diff" };
      ((this.state = {}),
        (this.pendingDiffs = []),
        (this.channel = e),
        (this.joinRef = null),
        (this.caller = {
          onJoin: function () {},
          onLeave: function () {},
          onSync: function () {},
        }),
        this.channel.on(i.state, (s) => {
          let { onJoin: o, onLeave: r, onSync: n } = this.caller;
          ((this.joinRef = this.channel.joinRef()),
            (this.state = a.syncState(this.state, s, o, r)),
            this.pendingDiffs.forEach((h) => {
              this.state = a.syncDiff(this.state, h, o, r);
            }),
            (this.pendingDiffs = []),
            n());
        }),
        this.channel.on(i.diff, (s) => {
          let { onJoin: o, onLeave: r, onSync: n } = this.caller;
          this.inPendingSyncState()
            ? this.pendingDiffs.push(s)
            : ((this.state = a.syncDiff(this.state, s, o, r)), n());
        }));
    }
    onJoin(e) {
      this.caller.onJoin = e;
    }
    onLeave(e) {
      this.caller.onLeave = e;
    }
    onSync(e) {
      this.caller.onSync = e;
    }
    list(e) {
      return a.list(this.state, e);
    }
    inPendingSyncState() {
      return !this.joinRef || this.joinRef !== this.channel.joinRef();
    }
    static syncState(e, t, i, s) {
      let o = this.clone(e),
        r = {},
        n = {};
      return (
        this.map(o, (h, l) => {
          t[h] || (n[h] = l);
        }),
        this.map(t, (h, l) => {
          let c = o[h];
          if (c) {
            let f = l.metas.map((E) => E.phx_ref),
              C = c.metas.map((E) => E.phx_ref),
              x = l.metas.filter((E) => C.indexOf(E.phx_ref) < 0),
              N = c.metas.filter((E) => f.indexOf(E.phx_ref) < 0);
            (x.length > 0 && ((r[h] = l), (r[h].metas = x)),
              N.length > 0 && ((n[h] = this.clone(c)), (n[h].metas = N)));
          } else r[h] = l;
        }),
        this.syncDiff(o, { joins: r, leaves: n }, i, s)
      );
    }
    static syncDiff(e, t, i, s) {
      let { joins: o, leaves: r } = this.clone(t);
      return (
        i || (i = function () {}),
        s || (s = function () {}),
        this.map(o, (n, h) => {
          let l = e[n];
          if (((e[n] = this.clone(h)), l)) {
            let c = e[n].metas.map((C) => C.phx_ref),
              f = l.metas.filter((C) => c.indexOf(C.phx_ref) < 0);
            e[n].metas.unshift(...f);
          }
          i(n, l, h);
        }),
        this.map(r, (n, h) => {
          let l = e[n];
          if (!l) return;
          let c = h.metas.map((f) => f.phx_ref);
          ((l.metas = l.metas.filter((f) => c.indexOf(f.phx_ref) < 0)),
            s(n, l, h),
            l.metas.length === 0 && delete e[n]);
        }),
        e
      );
    }
    static list(e, t) {
      return (
        t ||
          (t = function (i, s) {
            return s;
          }),
        this.map(e, (i, s) => t(i, s))
      );
    }
    static map(e, t) {
      return Object.getOwnPropertyNames(e).map((i) => t(i, e[i]));
    }
    static clone(e) {
      return JSON.parse(JSON.stringify(e));
    }
  };
  var y = {
    HEADER_LENGTH: 1,
    META_LENGTH: 4,
    KINDS: { push: 0, reply: 1, broadcast: 2 },
    encode(a, e) {
      if (a.payload.constructor === ArrayBuffer) return e(this.binaryEncode(a));
      {
        let t = [a.join_ref, a.ref, a.topic, a.event, a.payload];
        return e(JSON.stringify(t));
      }
    },
    decode(a, e) {
      if (a.constructor === ArrayBuffer) return e(this.binaryDecode(a));
      {
        let [t, i, s, o, r] = JSON.parse(a);
        return e({ join_ref: t, ref: i, topic: s, event: o, payload: r });
      }
    },
    binaryEncode(a) {
      let { join_ref: e, ref: t, event: i, topic: s, payload: o } = a,
        r = this.META_LENGTH + e.length + t.length + s.length + i.length,
        n = new ArrayBuffer(this.HEADER_LENGTH + r),
        h = new DataView(n),
        l = 0;
      (h.setUint8(l++, this.KINDS.push),
        h.setUint8(l++, e.length),
        h.setUint8(l++, t.length),
        h.setUint8(l++, s.length),
        h.setUint8(l++, i.length),
        Array.from(e, (f) => h.setUint8(l++, f.charCodeAt(0))),
        Array.from(t, (f) => h.setUint8(l++, f.charCodeAt(0))),
        Array.from(s, (f) => h.setUint8(l++, f.charCodeAt(0))),
        Array.from(i, (f) => h.setUint8(l++, f.charCodeAt(0))));
      var c = new Uint8Array(n.byteLength + o.byteLength);
      return (
        c.set(new Uint8Array(n), 0),
        c.set(new Uint8Array(o), n.byteLength),
        c.buffer
      );
    },
    binaryDecode(a) {
      let e = new DataView(a),
        t = e.getUint8(0),
        i = new TextDecoder();
      switch (t) {
        case this.KINDS.push:
          return this.decodePush(a, e, i);
        case this.KINDS.reply:
          return this.decodeReply(a, e, i);
        case this.KINDS.broadcast:
          return this.decodeBroadcast(a, e, i);
      }
    },
    decodePush(a, e, t) {
      let i = e.getUint8(1),
        s = e.getUint8(2),
        o = e.getUint8(3),
        r = this.HEADER_LENGTH + this.META_LENGTH - 1,
        n = t.decode(a.slice(r, r + i));
      r = r + i;
      let h = t.decode(a.slice(r, r + s));
      r = r + s;
      let l = t.decode(a.slice(r, r + o));
      r = r + o;
      let c = a.slice(r, a.byteLength);
      return { join_ref: n, ref: null, topic: h, event: l, payload: c };
    },
    decodeReply(a, e, t) {
      let i = e.getUint8(1),
        s = e.getUint8(2),
        o = e.getUint8(3),
        r = e.getUint8(4),
        n = this.HEADER_LENGTH + this.META_LENGTH,
        h = t.decode(a.slice(n, n + i));
      n = n + i;
      let l = t.decode(a.slice(n, n + s));
      n = n + s;
      let c = t.decode(a.slice(n, n + o));
      n = n + o;
      let f = t.decode(a.slice(n, n + r));
      n = n + r;
      let C = a.slice(n, a.byteLength),
        x = { status: f, response: C };
      return { join_ref: h, ref: l, topic: c, event: m.reply, payload: x };
    },
    decodeBroadcast(a, e, t) {
      let i = e.getUint8(1),
        s = e.getUint8(2),
        o = this.HEADER_LENGTH + 2,
        r = t.decode(a.slice(o, o + i));
      o = o + i;
      let n = t.decode(a.slice(o, o + s));
      o = o + s;
      let h = a.slice(o, a.byteLength);
      return { join_ref: null, ref: null, topic: r, event: n, payload: h };
    },
  };
  var L = class {
    constructor(e, t = {}) {
      ((this.stateChangeCallbacks = {
        open: [],
        close: [],
        error: [],
        message: [],
      }),
        (this.channels = []),
        (this.sendBuffer = []),
        (this.ref = 0),
        (this.fallbackRef = null),
        (this.timeout = t.timeout || O),
        (this.transport = t.transport || d.WebSocket || g),
        (this.primaryPassedHealthCheck = !1),
        (this.longPollFallbackMs = t.longPollFallbackMs),
        (this.fallbackTimer = null),
        (this.sessionStore = t.sessionStorage || (d && d.sessionStorage)),
        (this.establishedConnections = 0),
        (this.defaultEncoder = y.encode.bind(y)),
        (this.defaultDecoder = y.decode.bind(y)),
        (this.closeWasClean = !0),
        (this.disconnecting = !1),
        (this.binaryType = t.binaryType || "arraybuffer"),
        (this.connectClock = 1),
        (this.pageHidden = !1),
        this.transport !== g
          ? ((this.encode = t.encode || this.defaultEncoder),
            (this.decode = t.decode || this.defaultDecoder))
          : ((this.encode = this.defaultEncoder),
            (this.decode = this.defaultDecoder)));
      let i = null;
      (R &&
        R.addEventListener &&
        (R.addEventListener("pagehide", (s) => {
          this.conn && (this.disconnect(), (i = this.connectClock));
        }),
        R.addEventListener("pageshow", (s) => {
          i === this.connectClock && ((i = null), this.connect());
        }),
        R.addEventListener("visibilitychange", () => {
          document.visibilityState === "hidden"
            ? (this.pageHidden = !0)
            : ((this.pageHidden = !1),
              !this.isConnected() &&
                !this.closeWasClean &&
                this.teardown(() => this.connect()));
        })),
        (this.heartbeatIntervalMs = t.heartbeatIntervalMs || 3e4),
        (this.rejoinAfterMs = (s) =>
          t.rejoinAfterMs ? t.rejoinAfterMs(s) : [1e3, 2e3, 5e3][s - 1] || 1e4),
        (this.reconnectAfterMs = (s) =>
          t.reconnectAfterMs
            ? t.reconnectAfterMs(s)
            : [10, 50, 100, 150, 200, 250, 500, 1e3, 2e3][s - 1] || 5e3),
        (this.logger = t.logger || null),
        !this.logger &&
          t.debug &&
          (this.logger = (s, o, r) => {
            console.log(`${s}: ${o}`, r);
          }),
        (this.longpollerTimeout = t.longpollerTimeout || 2e4),
        (this.params = S(t.params || {})),
        (this.endPoint = `${e}/${j.websocket}`),
        (this.vsn = t.vsn || H),
        (this.heartbeatTimeoutTimer = null),
        (this.heartbeatTimer = null),
        (this.pendingHeartbeatRef = null),
        (this.reconnectTimer = new v(() => {
          if (this.pageHidden) {
            (this.log("Not reconnecting as page is hidden!"), this.teardown());
            return;
          }
          this.teardown(() => this.connect());
        }, this.reconnectAfterMs)),
        (this.authToken = t.authToken));
    }
    getLongPollTransport() {
      return g;
    }
    replaceTransport(e) {
      (this.connectClock++,
        (this.closeWasClean = !0),
        clearTimeout(this.fallbackTimer),
        this.reconnectTimer.reset(),
        this.conn && (this.conn.close(), (this.conn = null)),
        (this.transport = e));
    }
    protocol() {
      return location.protocol.match(/^https/) ? "wss" : "ws";
    }
    endPointURL() {
      let e = T.appendParams(T.appendParams(this.endPoint, this.params()), {
        vsn: this.vsn,
      });
      return e.charAt(0) !== "/"
        ? e
        : e.charAt(1) === "/"
          ? `${this.protocol()}:${e}`
          : `${this.protocol()}://${location.host}${e}`;
    }
    disconnect(e, t, i) {
      (this.connectClock++,
        (this.disconnecting = !0),
        (this.closeWasClean = !0),
        clearTimeout(this.fallbackTimer),
        this.reconnectTimer.reset(),
        this.teardown(
          () => {
            ((this.disconnecting = !1), e && e());
          },
          t,
          i,
        ));
    }
    connect(e) {
      (e &&
        (console &&
          console.log(
            "passing params to connect is deprecated. Instead pass :params to the Socket constructor",
          ),
        (this.params = S(e))),
        !(this.conn && !this.disconnecting) &&
          (this.longPollFallbackMs && this.transport !== g
            ? this.connectWithFallback(g, this.longPollFallbackMs)
            : this.transportConnect()));
    }
    log(e, t, i) {
      this.logger && this.logger(e, t, i);
    }
    hasLogger() {
      return this.logger !== null;
    }
    onOpen(e) {
      let t = this.makeRef();
      return (this.stateChangeCallbacks.open.push([t, e]), t);
    }
    onClose(e) {
      let t = this.makeRef();
      return (this.stateChangeCallbacks.close.push([t, e]), t);
    }
    onError(e) {
      let t = this.makeRef();
      return (this.stateChangeCallbacks.error.push([t, e]), t);
    }
    onMessage(e) {
      let t = this.makeRef();
      return (this.stateChangeCallbacks.message.push([t, e]), t);
    }
    ping(e) {
      if (!this.isConnected()) return !1;
      let t = this.makeRef(),
        i = Date.now();
      this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref: t });
      let s = this.onMessage((o) => {
        o.ref === t && (this.off([s]), e(Date.now() - i));
      });
      return !0;
    }
    transportName(e) {
      switch (e) {
        case g:
          return "LongPoll";
        default:
          return e.name;
      }
    }
    transportConnect() {
      (this.connectClock++, (this.closeWasClean = !1));
      let e;
      (this.authToken &&
        (e = ["phoenix", `${A}${btoa(this.authToken).replace(/=/g, "")}`]),
        (this.conn = new this.transport(this.endPointURL(), e)),
        (this.conn.binaryType = this.binaryType),
        (this.conn.timeout = this.longpollerTimeout),
        (this.conn.onopen = () => this.onConnOpen()),
        (this.conn.onerror = (t) => this.onConnError(t)),
        (this.conn.onmessage = (t) => this.onConnMessage(t)),
        (this.conn.onclose = (t) => this.onConnClose(t)));
    }
    getSession(e) {
      return this.sessionStore && this.sessionStore.getItem(e);
    }
    storeSession(e, t) {
      this.sessionStore && this.sessionStore.setItem(e, t);
    }
    connectWithFallback(e, t = 2500) {
      clearTimeout(this.fallbackTimer);
      let i = !1,
        s = !0,
        o,
        r,
        n = this.transportName(e),
        h = (l) => {
          (this.log("transport", `falling back to ${n}...`, l),
            this.off([o, r]),
            (s = !1),
            this.replaceTransport(e),
            this.transportConnect());
        };
      if (this.getSession(`phx:fallback:${n}`)) return h("memorized");
      ((this.fallbackTimer = setTimeout(h, t)),
        (r = this.onError((l) => {
          (this.log("transport", "error", l),
            s && !i && (clearTimeout(this.fallbackTimer), h(l)));
        })),
        this.fallbackRef && this.off([this.fallbackRef]),
        (this.fallbackRef = this.onOpen(() => {
          if (((i = !0), !s)) {
            let l = this.transportName(e);
            return (
              this.primaryPassedHealthCheck ||
                this.storeSession(`phx:fallback:${l}`, "true"),
              this.log("transport", `established ${l} fallback`)
            );
          }
          (clearTimeout(this.fallbackTimer),
            (this.fallbackTimer = setTimeout(h, t)),
            this.ping((l) => {
              (this.log("transport", "connected to primary after", l),
                (this.primaryPassedHealthCheck = !0),
                clearTimeout(this.fallbackTimer));
            }));
        })),
        this.transportConnect());
    }
    clearHeartbeats() {
      (clearTimeout(this.heartbeatTimer),
        clearTimeout(this.heartbeatTimeoutTimer));
    }
    onConnOpen() {
      (this.hasLogger() &&
        this.log(
          "transport",
          `${this.transportName(this.transport)} connected to ${this.endPointURL()}`,
        ),
        (this.closeWasClean = !1),
        (this.disconnecting = !1),
        this.establishedConnections++,
        this.flushSendBuffer(),
        this.reconnectTimer.reset(),
        this.resetHeartbeat(),
        this.stateChangeCallbacks.open.forEach(([, e]) => e()));
    }
    heartbeatTimeout() {
      this.pendingHeartbeatRef &&
        ((this.pendingHeartbeatRef = null),
        this.hasLogger() &&
          this.log(
            "transport",
            "heartbeat timeout. Attempting to re-establish connection",
          ),
        this.triggerChanError(),
        (this.closeWasClean = !1),
        this.teardown(
          () => this.reconnectTimer.scheduleTimeout(),
          P,
          "heartbeat timeout",
        ));
    }
    resetHeartbeat() {
      (this.conn && this.conn.skipHeartbeat) ||
        ((this.pendingHeartbeatRef = null),
        this.clearHeartbeats(),
        (this.heartbeatTimer = setTimeout(
          () => this.sendHeartbeat(),
          this.heartbeatIntervalMs,
        )));
    }
    teardown(e, t, i) {
      if (!this.conn) return e && e();
      let s = this.conn;
      this.waitForBufferDone(s, () => {
        (t ? s.close(t, i || "") : s.close(),
          this.waitForSocketClosed(s, () => {
            (this.conn === s &&
              ((this.conn.onopen = function () {}),
              (this.conn.onerror = function () {}),
              (this.conn.onmessage = function () {}),
              (this.conn.onclose = function () {}),
              (this.conn = null)),
              e && e());
          }));
      });
    }
    waitForBufferDone(e, t, i = 1) {
      if (i === 5 || !e.bufferedAmount) {
        t();
        return;
      }
      setTimeout(() => {
        this.waitForBufferDone(e, t, i + 1);
      }, 150 * i);
    }
    waitForSocketClosed(e, t, i = 1) {
      if (i === 5 || e.readyState === p.closed) {
        t();
        return;
      }
      setTimeout(() => {
        this.waitForSocketClosed(e, t, i + 1);
      }, 150 * i);
    }
    onConnClose(e) {
      this.conn && (this.conn.onclose = () => {});
      let t = e && e.code;
      (this.hasLogger() && this.log("transport", "close", e),
        this.triggerChanError(),
        this.clearHeartbeats(),
        !this.closeWasClean &&
          t !== 1e3 &&
          this.reconnectTimer.scheduleTimeout(),
        this.stateChangeCallbacks.close.forEach(([, i]) => i(e)));
    }
    onConnError(e) {
      this.hasLogger() && this.log("transport", e);
      let t = this.transport,
        i = this.establishedConnections;
      (this.stateChangeCallbacks.error.forEach(([, s]) => {
        s(e, t, i);
      }),
        (t === this.transport || i > 0) && this.triggerChanError());
    }
    triggerChanError() {
      this.channels.forEach((e) => {
        e.isErrored() || e.isLeaving() || e.isClosed() || e.trigger(m.error);
      });
    }
    connectionState() {
      switch (this.conn && this.conn.readyState) {
        case p.connecting:
          return "connecting";
        case p.open:
          return "open";
        case p.closing:
          return "closing";
        default:
          return "closed";
      }
    }
    isConnected() {
      return this.connectionState() === "open";
    }
    remove(e) {
      (this.off(e.stateChangeRefs),
        (this.channels = this.channels.filter((t) => t !== e)));
    }
    off(e) {
      for (let t in this.stateChangeCallbacks)
        this.stateChangeCallbacks[t] = this.stateChangeCallbacks[t].filter(
          ([i]) => e.indexOf(i) === -1,
        );
    }
    channel(e, t = {}) {
      let i = new k(e, t, this);
      return (this.channels.push(i), i);
    }
    push(e) {
      if (this.hasLogger()) {
        let { topic: t, event: i, payload: s, ref: o, join_ref: r } = e;
        this.log("push", `${t} ${i} (${r}, ${o})`, s);
      }
      this.isConnected()
        ? this.encode(e, (t) => this.conn.send(t))
        : this.sendBuffer.push(() => this.encode(e, (t) => this.conn.send(t)));
    }
    makeRef() {
      let e = this.ref + 1;
      return (
        e === this.ref ? (this.ref = 0) : (this.ref = e),
        this.ref.toString()
      );
    }
    sendHeartbeat() {
      (this.pendingHeartbeatRef && !this.isConnected()) ||
        ((this.pendingHeartbeatRef = this.makeRef()),
        this.push({
          topic: "phoenix",
          event: "heartbeat",
          payload: {},
          ref: this.pendingHeartbeatRef,
        }),
        (this.heartbeatTimeoutTimer = setTimeout(
          () => this.heartbeatTimeout(),
          this.heartbeatIntervalMs,
        )));
    }
    flushSendBuffer() {
      this.isConnected() &&
        this.sendBuffer.length > 0 &&
        (this.sendBuffer.forEach((e) => e()), (this.sendBuffer = []));
    }
    onConnMessage(e) {
      this.decode(e.data, (t) => {
        let { topic: i, event: s, payload: o, ref: r, join_ref: n } = t;
        (r &&
          r === this.pendingHeartbeatRef &&
          (this.clearHeartbeats(),
          (this.pendingHeartbeatRef = null),
          (this.heartbeatTimer = setTimeout(
            () => this.sendHeartbeat(),
            this.heartbeatIntervalMs,
          ))),
          this.hasLogger() &&
            this.log(
              "receive",
              `${o.status || ""} ${i} ${s} ${(r && "(" + r + ")") || ""}`,
              o,
            ));
        for (let h = 0; h < this.channels.length; h++) {
          let l = this.channels[h];
          l.isMember(i, s, o, n) && l.trigger(s, o, r, n);
        }
        for (let h = 0; h < this.stateChangeCallbacks.message.length; h++) {
          let [, l] = this.stateChangeCallbacks.message[h];
          l(t);
        }
      });
    }
    leaveOpenTopic(e) {
      let t = this.channels.find(
        (i) => i.topic === e && (i.isJoined() || i.isJoining()),
      );
      t &&
        (this.hasLogger() &&
          this.log("transport", `leaving duplicate topic "${e}"`),
        t.leave());
    }
  };
  return F(W);
})();
var LiveView = (() => {
  var ct = Object.defineProperty,
    Fi = Object.defineProperties,
    Ui = Object.getOwnPropertyDescriptor,
    Xi = Object.getOwnPropertyDescriptors,
    $i = Object.getOwnPropertyNames,
    zt = Object.getOwnPropertySymbols;
  var Qt = Object.prototype.hasOwnProperty,
    Vi = Object.prototype.propertyIsEnumerable;
  var Yt = (s, e, t) =>
      e in s
        ? ct(s, e, { enumerable: !0, configurable: !0, writable: !0, value: t })
        : (s[e] = t),
    L = (s, e) => {
      for (var t in e || (e = {})) Qt.call(e, t) && Yt(s, t, e[t]);
      if (zt) for (var t of zt(e)) Vi.call(e, t) && Yt(s, t, e[t]);
      return s;
    },
    le = (s, e) => Fi(s, Xi(e));
  var Bi = (s, e) => {
      for (var t in e) ct(s, t, { get: e[t], enumerable: !0 });
    },
    ji = (s, e, t, i) => {
      if ((e && typeof e == "object") || typeof e == "function")
        for (let n of $i(e))
          !Qt.call(s, n) &&
            n !== t &&
            ct(s, n, {
              get: () => e[n],
              enumerable: !(i = Ui(e, n)) || i.enumerable,
            });
      return s;
    };
  var Ji = (s) => ji(ct({}, "__esModule", { value: !0 }), s);
  var _n = {};
  Bi(_n, {
    LiveSocket: () => yn,
    ViewHook: () => Q,
    createHook: () => An,
    isUsedInput: () => Mi,
  });
  var ht = "consecutive-reloads";
  var dt = [
      "phx-click-loading",
      "phx-change-loading",
      "phx-submit-loading",
      "phx-keydown-loading",
      "phx-keyup-loading",
      "phx-blur-loading",
      "phx-focus-loading",
      "phx-hook-loading",
    ],
    ut = "phx-drop-target-active",
    K = "data-phx-component",
    ce = "data-phx-view",
    ft = "data-phx-link",
    Zt = "track-static",
    ei = "data-phx-link-state",
    ve = "data-phx-ref-loading",
    N = "data-phx-ref-src",
    C = "data-phx-ref-lock",
    Ct = "phx-pending-refs",
    pt = "track-uploads",
    G = "data-phx-upload-ref",
    Oe = "data-phx-preflighted-refs",
    ti = "data-phx-done-refs",
    qe = "drop-target",
    Ge = "data-phx-active-refs",
    Le = "phx:live-file:updated",
    mt = "data-phx-skip",
    gt = "data-phx-id",
    Rt = "data-phx-prune",
    xt = "phx-connected",
    be = "phx-loading",
    Se = "phx-error",
    It = "phx-client-error",
    He = "phx-server-error",
    se = "data-phx-parent-id",
    De = "data-phx-main",
    z = "data-phx-root-id",
    ze = "viewport-top",
    Ye = "viewport-bottom",
    ii = "viewport-overrun-target",
    ni = "trigger-action",
    we = "phx-has-focused",
    si = [
      "text",
      "textarea",
      "number",
      "email",
      "password",
      "search",
      "tel",
      "url",
      "date",
      "time",
      "datetime-local",
      "color",
      "range",
    ],
    vt = ["checkbox", "radio"],
    Pe = "phx-has-submitted",
    q = "data-phx-session",
    he = `[${q}]`,
    Qe = "data-phx-sticky",
    re = "data-phx-static",
    Ze = "data-phx-readonly",
    Ee = "data-phx-disabled",
    Ot = "disable-with",
    Me = "data-phx-disable-with-restore",
    Ne = "hook",
    ri = "debounce",
    oi = "throttle",
    Fe = "update",
    Ue = "stream",
    Xe = "data-phx-stream",
    $e = "data-phx-portal",
    oe = "data-phx-teleported",
    te = "data-phx-teleported-src",
    Ve = "data-phx-runtime-hook",
    ai = "data-phx-pid",
    li = "key",
    ie = "phxPrivate",
    Lt = "auto-recover",
    et = "phx:live-socket:debug",
    bt = "phx:live-socket:profiling",
    Et = "phx:live-socket:latency-sim",
    tt = "phx:nav-history-position",
    ci = "progress",
    Ht = "mounted",
    Dt = "__phoenix_reload_status__",
    hi = 1,
    Mt = 3,
    di = 200,
    ui = 500,
    fi = "phx-",
    pi = 3e4;
  var Be = "debounce-trigger",
    je = "throttled",
    Nt = "debounce-prev-key",
    mi = { debounce: 300, throttle: 300 },
    Ft = [ve, N, C],
    Y = "s",
    yt = "r",
    X = "c",
    x = "k",
    ne = "kc",
    Ut = "e",
    Xt = "r",
    $t = "t",
    de = "p",
    ke = "stream";
  var it = class {
    constructor(e, t, i) {
      let { chunk_size: n, chunk_timeout: r } = t;
      ((this.liveSocket = i),
        (this.entry = e),
        (this.offset = 0),
        (this.chunkSize = n),
        (this.chunkTimeout = r),
        (this.chunkTimer = null),
        (this.errored = !1),
        (this.uploadChannel = i.channel(`lvu:${e.ref}`, {
          token: e.metadata(),
        })));
    }
    error(e) {
      this.errored ||
        (this.uploadChannel.leave(),
        (this.errored = !0),
        clearTimeout(this.chunkTimer),
        this.entry.error(e));
    }
    upload() {
      (this.uploadChannel.onError((e) => this.error(e)),
        this.uploadChannel
          .join()
          .receive("ok", (e) => this.readNextChunk())
          .receive("error", (e) => this.error(e)));
    }
    isDone() {
      return this.offset >= this.entry.file.size;
    }
    readNextChunk() {
      let e = new window.FileReader(),
        t = this.entry.file.slice(this.offset, this.chunkSize + this.offset);
      ((e.onload = (i) => {
        if (i.target.error === null)
          ((this.offset += i.target.result.byteLength),
            this.pushChunk(i.target.result));
        else return w("Read error: " + i.target.error);
      }),
        e.readAsArrayBuffer(t));
    }
    pushChunk(e) {
      this.uploadChannel.isJoined() &&
        this.uploadChannel
          .push("chunk", e, this.chunkTimeout)
          .receive("ok", () => {
            (this.entry.progress((this.offset / this.entry.file.size) * 100),
              this.isDone() ||
                (this.chunkTimer = setTimeout(
                  () => this.readNextChunk(),
                  this.liveSocket.getLatencySim() || 0,
                )));
          })
          .receive("error", ({ reason: t }) => this.error(t));
    }
  };
  var w = (s, e) => console.error && console.error(s, e),
    ee = (s) => {
      let e = typeof s;
      return e === "number" || (e === "string" && /^(0|[1-9]\d*)$/.test(s));
    };
  function gi() {
    let s = new Set(),
      e = document.querySelectorAll("*[id]");
    for (let t = 0, i = e.length; t < i; t++)
      s.has(e[t].id)
        ? console.error(
            `Multiple IDs detected: ${e[t].id}. Ensure unique element ids.`,
          )
        : s.add(e[t].id);
  }
  function vi(s) {
    let e = new Set();
    (Object.keys(s).forEach((t) => {
      let i = document.getElementById(t);
      i &&
        i.parentElement &&
        i.parentElement.getAttribute("phx-update") !== "stream" &&
        e.add(
          `The stream container with id "${i.parentElement.id}" is missing the phx-update="stream" attribute. Ensure it is set for streams to work properly.`,
        );
    }),
      e.forEach((t) => console.error(t)));
  }
  var bi = (s, e, t, i) => {
      s.liveSocket.isDebugEnabled() && console.log(`${s.id} ${e}: ${t} - `, i);
    },
    Je = (s) =>
      typeof s == "function"
        ? s
        : function () {
            return s;
          },
    We = (s) => JSON.parse(JSON.stringify(s)),
    ue = (s, e, t) => {
      do {
        if (s.matches(`[${e}]`) && !s.disabled) return s;
        s = s.parentElement || s.parentNode;
      } while (
        s !== null &&
        s.nodeType === 1 &&
        !((t && t.isSameNode(s)) || s.matches(he))
      );
      return null;
    },
    Te = (s) => s !== null && typeof s == "object" && !(s instanceof Array),
    Ei = (s, e) => JSON.stringify(s) === JSON.stringify(e),
    Vt = (s) => {
      for (let e in s) return !1;
      return !0;
    },
    fe = (s, e) => s && e(s),
    yi = function (s, e, t, i) {
      s.forEach((n) => {
        new it(n, t.config, i).upload();
      });
    },
    Ai = (s) => {
      if (s.dataTransfer.types) {
        for (let e = 0; e < s.dataTransfer.types.length; e++)
          if (s.dataTransfer.types[e] === "Files") return !0;
      }
      return !1;
    };
  var Wi = {
      canPushState() {
        return typeof history.pushState != "undefined";
      },
      dropLocal(s, e, t) {
        return s.removeItem(this.localKey(e, t));
      },
      updateLocal(s, e, t, i, n) {
        let r = this.getLocal(s, e, t),
          o = this.localKey(e, t),
          a = r === null ? i : n(r);
        return (s.setItem(o, JSON.stringify(a)), a);
      },
      getLocal(s, e, t) {
        return JSON.parse(s.getItem(this.localKey(e, t)));
      },
      updateCurrentState(s) {
        this.canPushState() &&
          history.replaceState(
            s(history.state || {}),
            "",
            window.location.href,
          );
      },
      pushState(s, e, t) {
        if (this.canPushState()) {
          if (t !== window.location.href) {
            if (e.type == "redirect" && e.scroll) {
              let i = history.state || {};
              ((i.scroll = e.scroll),
                history.replaceState(i, "", window.location.href));
            }
            (delete e.scroll,
              history[s + "State"](e, "", t || null),
              window.requestAnimationFrame(() => {
                let i = this.getHashTargetEl(window.location.hash);
                i
                  ? i.scrollIntoView()
                  : e.type === "redirect" && window.scroll(0, 0);
              }));
          }
        } else this.redirect(t);
      },
      setCookie(s, e, t) {
        let i = typeof t == "number" ? ` max-age=${t};` : "";
        document.cookie = `${s}=${e};${i} path=/`;
      },
      getCookie(s) {
        return document.cookie.replace(
          new RegExp(`(?:(?:^|.*;s*)${s}s*=s*([^;]*).*$)|^.*$`),
          "$1",
        );
      },
      deleteCookie(s) {
        document.cookie = `${s}=; max-age=-1; path=/`;
      },
      redirect(
        s,
        e,
        t = (i) => {
          window.location.href = i;
        },
      ) {
        (e && this.setCookie("__phoenix_flash__", e, 60), t(s));
      },
      localKey(s, e) {
        return `${s}-${e}`;
      },
      getHashTargetEl(s) {
        let e = s.toString().substring(1);
        if (e !== "")
          return (
            document.getElementById(e) ||
            document.querySelector(`a[name="${e}"]`)
          );
      },
    },
    $ = Wi;
  var Ce = {
      byId(s) {
        return document.getElementById(s) || w(`no id found for ${s}`);
      },
      removeClass(s, e) {
        (s.classList.remove(e),
          s.classList.length === 0 && s.removeAttribute("class"));
      },
      all(s, e, t) {
        if (!s) return [];
        let i = Array.from(s.querySelectorAll(e));
        return (t && i.forEach(t), i);
      },
      childNodeLength(s) {
        let e = document.createElement("template");
        return ((e.innerHTML = s), e.content.childElementCount);
      },
      isUploadInput(s) {
        return s.type === "file" && s.getAttribute(G) !== null;
      },
      isAutoUpload(s) {
        return s.hasAttribute("data-phx-auto-upload");
      },
      findUploadInputs(s) {
        let e = s.id,
          t = this.all(document, `input[type="file"][${G}][form="${e}"]`);
        return this.all(s, `input[type="file"][${G}]`).concat(t);
      },
      findComponentNodeList(s, e, t = document) {
        return this.all(t, `[${ce}="${s}"][${K}="${e}"]`);
      },
      isPhxDestroyed(s) {
        return !!(s.id && Ce.private(s, "destroyed"));
      },
      wantsNewTab(s) {
        let e =
            s.ctrlKey ||
            s.shiftKey ||
            s.metaKey ||
            (s.button && s.button === 1),
          t =
            s.target instanceof HTMLAnchorElement &&
            s.target.hasAttribute("download"),
          i =
            s.target.hasAttribute("target") &&
            s.target.getAttribute("target").toLowerCase() === "_blank",
          n =
            s.target.hasAttribute("target") &&
            !s.target.getAttribute("target").startsWith("_");
        return e || i || t || n;
      },
      isUnloadableFormSubmit(s) {
        return (s.target && s.target.getAttribute("method") === "dialog") ||
          (s.submitter && s.submitter.getAttribute("formmethod") === "dialog")
          ? !1
          : !s.defaultPrevented && !this.wantsNewTab(s);
      },
      isNewPageClick(s, e) {
        let t =
            s.target instanceof HTMLAnchorElement
              ? s.target.getAttribute("href")
              : null,
          i;
        if (
          s.defaultPrevented ||
          t === null ||
          this.wantsNewTab(s) ||
          t.startsWith("mailto:") ||
          t.startsWith("tel:") ||
          s.target.isContentEditable
        )
          return !1;
        try {
          i = new URL(t);
        } catch (n) {
          try {
            i = new URL(t, e);
          } catch (r) {
            return !0;
          }
        }
        return i.host === e.host &&
          i.protocol === e.protocol &&
          i.pathname === e.pathname &&
          i.search === e.search
          ? i.hash === "" && !i.href.endsWith("#")
          : i.protocol.startsWith("http");
      },
      markPhxChildDestroyed(s) {
        (this.isPhxChild(s) && s.setAttribute(q, ""),
          this.putPrivate(s, "destroyed", !0));
      },
      findPhxChildrenInFragment(s, e) {
        let t = document.createElement("template");
        return ((t.innerHTML = s), this.findPhxChildren(t.content, e));
      },
      isIgnored(s, e) {
        return (
          (s.getAttribute(e) || s.getAttribute("data-phx-update")) === "ignore"
        );
      },
      isPhxUpdate(s, e, t) {
        return s.getAttribute && t.indexOf(s.getAttribute(e)) >= 0;
      },
      findPhxSticky(s) {
        return this.all(s, `[${Qe}]`);
      },
      findPhxChildren(s, e) {
        return this.all(s, `${he}[${se}="${e}"]`);
      },
      findExistingParentCIDs(s, e) {
        let t = new Set(),
          i = new Set();
        return (
          e.forEach((n) => {
            this.all(document, `[${ce}="${s}"][${K}="${n}"]`).forEach((r) => {
              (t.add(n),
                this.all(r, `[${ce}="${s}"][${K}]`)
                  .map((o) => parseInt(o.getAttribute(K)))
                  .forEach((o) => i.add(o)));
            });
          }),
          i.forEach((n) => t.delete(n)),
          t
        );
      },
      private(s, e) {
        return s[ie] && s[ie][e];
      },
      deletePrivate(s, e) {
        s[ie] && delete s[ie][e];
      },
      putPrivate(s, e, t) {
        (s[ie] || (s[ie] = {}), (s[ie][e] = t));
      },
      updatePrivate(s, e, t, i) {
        let n = this.private(s, e);
        n === void 0
          ? this.putPrivate(s, e, i(t))
          : this.putPrivate(s, e, i(n));
      },
      syncPendingAttrs(s, e) {
        s.hasAttribute(N) &&
          (dt.forEach((t) => {
            s.classList.contains(t) && e.classList.add(t);
          }),
          Ft.filter((t) => s.hasAttribute(t)).forEach((t) => {
            e.setAttribute(t, s.getAttribute(t));
          }));
      },
      copyPrivates(s, e) {
        e[ie] && (s[ie] = e[ie]);
      },
      putTitle(s) {
        let e = document.querySelector("title");
        if (e) {
          let { prefix: t, suffix: i, default: n } = e.dataset,
            r = typeof s != "string" || s.trim() === "";
          if (r && typeof n != "string") return;
          let o = r ? n : s;
          document.title = `${t || ""}${o || ""}${i || ""}`;
        } else document.title = s;
      },
      debounce(s, e, t, i, n, r, o, a) {
        let l = s.getAttribute(t),
          h = s.getAttribute(n);
        (l === "" && (l = i), h === "" && (h = r));
        let d = l || h;
        switch (d) {
          case null:
            return a();
          case "blur":
            (this.incCycle(s, "debounce-blur-cycle", () => {
              o() && a();
            }),
              this.once(s, "debounce-blur") &&
                s.addEventListener("blur", () =>
                  this.triggerCycle(s, "debounce-blur-cycle"),
                ));
            return;
          default:
            let p = parseInt(d),
              m = () => (h ? this.deletePrivate(s, je) : a()),
              g = this.incCycle(s, Be, m);
            if (isNaN(p)) return w(`invalid throttle/debounce value: ${d}`);
            if (h) {
              let v = !1;
              if (e.type === "keydown") {
                let E = this.private(s, Nt);
                (this.putPrivate(s, Nt, e.key), (v = E !== e.key));
              }
              if (!v && this.private(s, je)) return !1;
              {
                a();
                let E = setTimeout(() => {
                  o() && this.triggerCycle(s, Be);
                }, p);
                this.putPrivate(s, je, E);
              }
            } else
              setTimeout(() => {
                o() && this.triggerCycle(s, Be, g);
              }, p);
            let u = s.form;
            (u &&
              this.once(u, "bind-debounce") &&
              u.addEventListener("submit", () => {
                Array.from(new FormData(u).entries(), ([v]) => {
                  let E = u.elements.namedItem(v),
                    M = E instanceof RadioNodeList ? E[0] : E;
                  M && (this.incCycle(M, Be), this.deletePrivate(M, je));
                });
              }),
              this.once(s, "bind-debounce") &&
                s.addEventListener("blur", () => {
                  (clearTimeout(this.private(s, je)), this.triggerCycle(s, Be));
                }));
        }
      },
      triggerCycle(s, e, t) {
        let [i, n] = this.private(s, e);
        (t || (t = i), t === i && (this.incCycle(s, e), n()));
      },
      once(s, e) {
        return this.private(s, e) === !0 ? !1 : (this.putPrivate(s, e, !0), !0);
      },
      incCycle(s, e, t = function () {}) {
        let [i] = this.private(s, e) || [0, t];
        return (i++, this.putPrivate(s, e, [i, t]), i);
      },
      maintainPrivateHooks(s, e, t, i) {
        (s.hasAttribute &&
          s.hasAttribute("data-phx-hook") &&
          !e.hasAttribute("data-phx-hook") &&
          e.setAttribute("data-phx-hook", s.getAttribute("data-phx-hook")),
          e.hasAttribute &&
            (e.hasAttribute(t) || e.hasAttribute(i)) &&
            e.setAttribute("data-phx-hook", "Phoenix.InfiniteScroll"));
      },
      putCustomElHook(s, e) {
        (s.isConnected
          ? s.setAttribute("data-phx-hook", "")
          : console.error(`
        hook attached to non-connected DOM element
        ensure you are calling createHook within your connectedCallback. ${s.outerHTML}
      `),
          this.putPrivate(s, "custom-el-hook", e));
      },
      getCustomElHook(s) {
        return this.private(s, "custom-el-hook");
      },
      isUsedInput(s) {
        return (
          s.nodeType === Node.ELEMENT_NODE &&
          (this.private(s, we) || this.private(s, Pe))
        );
      },
      resetForm(s) {
        Array.from(s.elements).forEach((e) => {
          (this.deletePrivate(e, we), this.deletePrivate(e, Pe));
        });
      },
      isPhxChild(s) {
        return s.getAttribute && s.getAttribute(se);
      },
      isPhxSticky(s) {
        return s.getAttribute && s.getAttribute(Qe) !== null;
      },
      isChildOfAny(s, e) {
        return !!e.find((t) => t.contains(s));
      },
      firstPhxChild(s) {
        return this.isPhxChild(s) ? s : this.all(s, `[${se}]`)[0];
      },
      isPortalTemplate(s) {
        return s.tagName === "TEMPLATE" && s.hasAttribute($e);
      },
      closestViewEl(s) {
        let e = s.closest(`[${oe}],${he}`);
        return e
          ? e.hasAttribute(oe)
            ? this.byId(e.getAttribute(oe))
            : e.hasAttribute(q)
              ? e
              : null
          : null;
      },
      dispatchEvent(s, e, t = {}) {
        let i = !0;
        s.nodeName === "INPUT" &&
          s.type === "file" &&
          e === "click" &&
          (i = !1);
        let o = {
            bubbles: t.bubbles === void 0 ? i : !!t.bubbles,
            cancelable: !0,
            detail: t.detail || {},
          },
          a =
            e === "click" ? new MouseEvent("click", o) : new CustomEvent(e, o);
        s.dispatchEvent(a);
      },
      cloneNode(s, e) {
        if (typeof e == "undefined") return s.cloneNode(!0);
        {
          let t = s.cloneNode(!1);
          return ((t.innerHTML = e), t);
        }
      },
      mergeAttrs(s, e, t = {}) {
        var a;
        let i = new Set(t.exclude || []),
          n = t.isIgnored,
          r = e.attributes;
        for (let l = r.length - 1; l >= 0; l--) {
          let h = r[l].name;
          if (i.has(h)) {
            if (h === "value") {
              let d = (a = e.value) != null ? a : e.getAttribute(h);
              s.value === d && s.setAttribute("value", e.getAttribute(h));
            }
          } else {
            let d = e.getAttribute(h);
            s.getAttribute(h) !== d &&
              (!n || (n && h.startsWith("data-"))) &&
              s.setAttribute(h, d);
          }
        }
        let o = s.attributes;
        for (let l = o.length - 1; l >= 0; l--) {
          let h = o[l].name;
          n
            ? h.startsWith("data-") &&
              !e.hasAttribute(h) &&
              !Ft.includes(h) &&
              s.removeAttribute(h)
            : e.hasAttribute(h) || s.removeAttribute(h);
        }
      },
      mergeFocusedInput(s, e) {
        (s instanceof HTMLSelectElement ||
          Ce.mergeAttrs(s, e, { exclude: ["value"] }),
          e.readOnly
            ? s.setAttribute("readonly", !0)
            : s.removeAttribute("readonly"));
      },
      hasSelectionRange(s) {
        return (
          s.setSelectionRange && (s.type === "text" || s.type === "textarea")
        );
      },
      restoreFocus(s, e, t) {
        if (
          (s instanceof HTMLSelectElement && s.focus(), !Ce.isTextualInput(s))
        )
          return;
        (s.matches(":focus") || s.focus(),
          this.hasSelectionRange(s) && s.setSelectionRange(e, t));
      },
      isFormInput(s) {
        return s.localName && customElements.get(s.localName)
          ? customElements.get(s.localName).formAssociated
          : /^(?:input|select|textarea)$/i.test(s.tagName) &&
              s.type !== "button";
      },
      syncAttrsToProps(s) {
        s instanceof HTMLInputElement &&
          vt.indexOf(s.type.toLocaleLowerCase()) >= 0 &&
          (s.checked = s.getAttribute("checked") !== null);
      },
      isTextualInput(s) {
        return si.indexOf(s.type) >= 0;
      },
      isNowTriggerFormExternal(s, e) {
        return (
          s.getAttribute &&
          s.getAttribute(e) !== null &&
          document.body.contains(s)
        );
      },
      cleanChildNodes(s, e) {
        if (Ce.isPhxUpdate(s, e, ["append", "prepend", Ue])) {
          let t = [];
          (s.childNodes.forEach((i) => {
            i.id ||
              (!(i.nodeType === Node.TEXT_NODE && i.nodeValue.trim() === "") &&
                i.nodeType !== Node.COMMENT_NODE &&
                w(`only HTML element tags with an id are allowed inside containers with phx-update.

removing illegal node: "${(i.outerHTML || i.nodeValue).trim()}"

`),
              t.push(i));
          }),
            t.forEach((i) => i.remove()));
        }
      },
      replaceRootContainer(s, e, t) {
        let i = new Set(["id", q, re, De, z]);
        if (s.tagName.toLowerCase() === e.toLowerCase())
          return (
            Array.from(s.attributes)
              .filter((n) => !i.has(n.name.toLowerCase()))
              .forEach((n) => s.removeAttribute(n.name)),
            Object.keys(t)
              .filter((n) => !i.has(n.toLowerCase()))
              .forEach((n) => s.setAttribute(n, t[n])),
            s
          );
        {
          let n = document.createElement(e);
          return (
            Object.keys(t).forEach((r) => n.setAttribute(r, t[r])),
            i.forEach((r) => n.setAttribute(r, s.getAttribute(r))),
            (n.innerHTML = s.innerHTML),
            s.replaceWith(n),
            n
          );
        }
      },
      getSticky(s, e, t) {
        let i = (Ce.private(s, "sticky") || []).find(([n]) => e === n);
        if (i) {
          let [n, r, o] = i;
          return o;
        } else return typeof t == "function" ? t() : t;
      },
      deleteSticky(s, e) {
        this.updatePrivate(s, "sticky", [], (t) =>
          t.filter(([i, n]) => i !== e),
        );
      },
      putSticky(s, e, t) {
        let i = t(s);
        this.updatePrivate(s, "sticky", [], (n) => {
          let r = n.findIndex(([o]) => e === o);
          return (r >= 0 ? (n[r] = [e, t, i]) : n.push([e, t, i]), n);
        });
      },
      applyStickyOperations(s) {
        let e = Ce.private(s, "sticky");
        e && e.forEach(([t, i, n]) => this.putSticky(s, t, i));
      },
      isLocked(s) {
        return s.hasAttribute && s.hasAttribute(C);
      },
      attributeIgnored(s, e) {
        return e.some(
          (t) =>
            s.name == t ||
            t === "*" ||
            (t.includes("*") && s.name.match(t) != null),
        );
      },
    },
    c = Ce;
  var pe = class {
    static isActive(e, t) {
      let i = t._phxRef === void 0,
        r = e.getAttribute(Ge).split(",").indexOf(R.genFileRef(t)) >= 0;
      return t.size > 0 && (i || r);
    }
    static isPreflighted(e, t) {
      return (
        e.getAttribute(Oe).split(",").indexOf(R.genFileRef(t)) >= 0 &&
        this.isActive(e, t)
      );
    }
    static isPreflightInProgress(e) {
      return e._preflightInProgress === !0;
    }
    static markPreflightInProgress(e) {
      e._preflightInProgress = !0;
    }
    constructor(e, t, i, n) {
      ((this.ref = R.genFileRef(t)),
        (this.fileEl = e),
        (this.file = t),
        (this.view = i),
        (this.meta = null),
        (this._isCancelled = !1),
        (this._isDone = !1),
        (this._progress = 0),
        (this._lastProgressSent = -1),
        (this._onDone = function () {}),
        (this._onElUpdated = this.onElUpdated.bind(this)),
        this.fileEl.addEventListener(Le, this._onElUpdated),
        (this.autoUpload = n));
    }
    metadata() {
      return this.meta;
    }
    progress(e) {
      ((this._progress = Math.floor(e)),
        this._progress > this._lastProgressSent &&
          (this._progress >= 100
            ? ((this._progress = 100),
              (this._lastProgressSent = 100),
              (this._isDone = !0),
              this.view.pushFileProgress(this.fileEl, this.ref, 100, () => {
                (R.untrackFile(this.fileEl, this.file), this._onDone());
              }))
            : ((this._lastProgressSent = this._progress),
              this.view.pushFileProgress(
                this.fileEl,
                this.ref,
                this._progress,
              ))));
    }
    isCancelled() {
      return this._isCancelled;
    }
    cancel() {
      ((this.file._preflightInProgress = !1),
        (this._isCancelled = !0),
        (this._isDone = !0),
        this._onDone());
    }
    isDone() {
      return this._isDone;
    }
    error(e = "failed") {
      (this.fileEl.removeEventListener(Le, this._onElUpdated),
        this.view.pushFileProgress(this.fileEl, this.ref, { error: e }),
        this.isAutoUpload() || R.clearFiles(this.fileEl));
    }
    isAutoUpload() {
      return this.autoUpload;
    }
    onDone(e) {
      this._onDone = () => {
        (this.fileEl.removeEventListener(Le, this._onElUpdated), e());
      };
    }
    onElUpdated() {
      this.fileEl.getAttribute(Ge).split(",").indexOf(this.ref) === -1 &&
        (R.untrackFile(this.fileEl, this.file), this.cancel());
    }
    toPreflightPayload() {
      return {
        last_modified: this.file.lastModified,
        name: this.file.name,
        relative_path: this.file.webkitRelativePath,
        size: this.file.size,
        type: this.file.type,
        ref: this.ref,
        meta: typeof this.file.meta == "function" ? this.file.meta() : void 0,
      };
    }
    uploader(e) {
      if (this.meta.uploader) {
        let t =
          e[this.meta.uploader] ||
          w(`no uploader configured for ${this.meta.uploader}`);
        return { name: this.meta.uploader, callback: t };
      } else return { name: "channel", callback: yi };
    }
    zipPostFlight(e) {
      ((this.meta = e.entries[this.ref]),
        this.meta ||
          w(`no preflight upload response returned with ref ${this.ref}`, {
            input: this.fileEl,
            response: e,
          }));
    }
  };
  var Ki = 0,
    R = class s {
      static genFileRef(e) {
        let t = e._phxRef;
        return t !== void 0 ? t : ((e._phxRef = (Ki++).toString()), e._phxRef);
      }
      static getEntryDataURL(e, t, i) {
        let n = this.activeFiles(e).find((r) => this.genFileRef(r) === t);
        i(URL.createObjectURL(n));
      }
      static hasUploadsInProgress(e) {
        let t = 0;
        return (
          c.findUploadInputs(e).forEach((i) => {
            i.getAttribute(Oe) !== i.getAttribute(ti) && t++;
          }),
          t > 0
        );
      }
      static serializeUploads(e) {
        let t = this.activeFiles(e),
          i = {};
        return (
          t.forEach((n) => {
            let r = { path: e.name },
              o = e.getAttribute(G);
            ((i[o] = i[o] || []),
              (r.ref = this.genFileRef(n)),
              (r.last_modified = n.lastModified),
              (r.name = n.name || r.ref),
              (r.relative_path = n.webkitRelativePath),
              (r.type = n.type),
              (r.size = n.size),
              typeof n.meta == "function" && (r.meta = n.meta()),
              i[o].push(r));
          }),
          i
        );
      }
      static clearFiles(e) {
        ((e.value = null), e.removeAttribute(G), c.putPrivate(e, "files", []));
      }
      static untrackFile(e, t) {
        c.putPrivate(
          e,
          "files",
          c.private(e, "files").filter((i) => !Object.is(i, t)),
        );
      }
      static trackFiles(e, t, i) {
        if (e.getAttribute("multiple") !== null) {
          let n = t.filter(
            (r) => !this.activeFiles(e).find((o) => Object.is(o, r)),
          );
          (c.updatePrivate(e, "files", [], (r) => r.concat(n)),
            (e.value = null));
        } else
          (i && i.files.length > 0 && (e.files = i.files),
            c.putPrivate(e, "files", t));
      }
      static activeFileInputs(e) {
        let t = c.findUploadInputs(e);
        return Array.from(t).filter(
          (i) => i.files && this.activeFiles(i).length > 0,
        );
      }
      static activeFiles(e) {
        return (c.private(e, "files") || []).filter((t) => pe.isActive(e, t));
      }
      static inputsAwaitingPreflight(e) {
        let t = c.findUploadInputs(e);
        return Array.from(t).filter(
          (i) => this.filesAwaitingPreflight(i).length > 0,
        );
      }
      static filesAwaitingPreflight(e) {
        return this.activeFiles(e).filter(
          (t) => !pe.isPreflighted(e, t) && !pe.isPreflightInProgress(t),
        );
      }
      static markPreflightInProgress(e) {
        e.forEach((t) => pe.markPreflightInProgress(t.file));
      }
      constructor(e, t, i) {
        ((this.autoUpload = c.isAutoUpload(e)),
          (this.view = t),
          (this.onComplete = i),
          (this._entries = Array.from(s.filesAwaitingPreflight(e) || []).map(
            (n) => new pe(e, n, t, this.autoUpload),
          )),
          s.markPreflightInProgress(this._entries),
          (this.numEntriesInProgress = this._entries.length));
      }
      isAutoUpload() {
        return this.autoUpload;
      }
      entries() {
        return this._entries;
      }
      initAdapterUpload(e, t, i) {
        this._entries = this._entries.map(
          (r) => (
            r.isCancelled()
              ? (this.numEntriesInProgress--,
                this.numEntriesInProgress === 0 && this.onComplete())
              : (r.zipPostFlight(e),
                r.onDone(() => {
                  (this.numEntriesInProgress--,
                    this.numEntriesInProgress === 0 && this.onComplete());
                })),
            r
          ),
        );
        let n = this._entries.reduce((r, o) => {
          if (!o.meta) return r;
          let { name: a, callback: l } = o.uploader(i.uploaders);
          return (
            (r[a] = r[a] || { callback: l, entries: [] }),
            r[a].entries.push(o),
            r
          );
        }, {});
        for (let r in n) {
          let { callback: o, entries: a } = n[r];
          o(a, t, e, i);
        }
      }
    };
  var qi = {
      anyOf(s, e) {
        return e.find((t) => s instanceof t);
      },
      isFocusable(s, e) {
        return (
          (s instanceof HTMLAnchorElement && s.rel !== "ignore") ||
          (s instanceof HTMLAreaElement && s.href !== void 0) ||
          (!s.disabled &&
            this.anyOf(s, [
              HTMLInputElement,
              HTMLSelectElement,
              HTMLTextAreaElement,
              HTMLButtonElement,
            ])) ||
          s instanceof HTMLIFrameElement ||
          (s.tabIndex >= 0 && s.getAttribute("aria-hidden") !== "true") ||
          (!e &&
            s.getAttribute("tabindex") !== null &&
            s.getAttribute("aria-hidden") !== "true")
        );
      },
      attemptFocus(s, e) {
        if (this.isFocusable(s, e))
          try {
            s.focus();
          } catch (t) {}
        return !!document.activeElement && document.activeElement.isSameNode(s);
      },
      focusFirstInteractive(s) {
        let e = s.firstElementChild;
        for (; e; ) {
          if (this.attemptFocus(e, !0) || this.focusFirstInteractive(e))
            return !0;
          e = e.nextElementSibling;
        }
      },
      focusFirst(s) {
        let e = s.firstElementChild;
        for (; e; ) {
          if (this.attemptFocus(e) || this.focusFirst(e)) return !0;
          e = e.nextElementSibling;
        }
      },
      focusLast(s) {
        let e = s.lastElementChild;
        for (; e; ) {
          if (this.attemptFocus(e) || this.focusLast(e)) return !0;
          e = e.previousElementSibling;
        }
      },
    },
    V = qi;
  var wi = {
      LiveFileUpload: {
        activeRefs() {
          return this.el.getAttribute(Ge);
        },
        preflightedRefs() {
          return this.el.getAttribute(Oe);
        },
        mounted() {
          (this.js().ignoreAttributes(this.el, ["value"]),
            (this.preflightedWas = this.preflightedRefs()));
        },
        updated() {
          let s = this.preflightedRefs();
          (this.preflightedWas !== s &&
            ((this.preflightedWas = s),
            s === "" && this.__view().cancelSubmit(this.el.form)),
            this.activeRefs() === "" && (this.el.value = null),
            this.el.dispatchEvent(new CustomEvent(Le)));
        },
      },
      LiveImgPreview: {
        mounted() {
          ((this.ref = this.el.getAttribute("data-phx-entry-ref")),
            (this.inputEl = document.getElementById(this.el.getAttribute(G))),
            R.getEntryDataURL(this.inputEl, this.ref, (s) => {
              ((this.url = s), (this.el.src = s));
            }));
        },
        destroyed() {
          URL.revokeObjectURL(this.url);
        },
      },
      FocusWrap: {
        mounted() {
          ((this.focusStart = this.el.firstElementChild),
            (this.focusEnd = this.el.lastElementChild),
            this.focusStart.addEventListener("focus", (s) => {
              if (!s.relatedTarget || !this.el.contains(s.relatedTarget)) {
                let e = s.target.nextElementSibling;
                V.attemptFocus(e) || V.focusFirst(e);
              } else V.focusLast(this.el);
            }),
            this.focusEnd.addEventListener("focus", (s) => {
              if (!s.relatedTarget || !this.el.contains(s.relatedTarget)) {
                let e = s.target.previousElementSibling;
                V.attemptFocus(e) || V.focusLast(e);
              } else V.focusFirst(this.el);
            }),
            this.el.contains(document.activeElement) ||
              (this.el.addEventListener("phx:show-end", () => this.el.focus()),
              window.getComputedStyle(this.el).display !== "none" &&
                V.focusFirst(this.el)));
        },
      },
    },
    Pi = (s) =>
      ["HTML", "BODY"].indexOf(s.nodeName.toUpperCase()) >= 0
        ? null
        : ["scroll", "auto"].indexOf(getComputedStyle(s).overflowY) >= 0
          ? s
          : Pi(s.parentElement),
    _i = (s) =>
      s
        ? s.scrollTop
        : document.documentElement.scrollTop || document.body.scrollTop,
    Bt = (s) =>
      s
        ? s.getBoundingClientRect().bottom
        : window.innerHeight || document.documentElement.clientHeight,
    jt = (s) => (s ? s.getBoundingClientRect().top : 0),
    Gi = (s, e) => {
      let t = s.getBoundingClientRect();
      return (
        Math.ceil(t.top) >= jt(e) &&
        Math.ceil(t.left) >= 0 &&
        Math.floor(t.top) <= Bt(e)
      );
    },
    zi = (s, e) => {
      let t = s.getBoundingClientRect();
      return (
        Math.ceil(t.bottom) >= jt(e) &&
        Math.ceil(t.left) >= 0 &&
        Math.floor(t.bottom) <= Bt(e)
      );
    },
    Si = (s, e) => {
      let t = s.getBoundingClientRect();
      return (
        Math.ceil(t.top) >= jt(e) &&
        Math.ceil(t.left) >= 0 &&
        Math.floor(t.top) <= Bt(e)
      );
    };
  wi.InfiniteScroll = {
    mounted() {
      this.scrollContainer = Pi(this.el);
      let s = _i(this.scrollContainer),
        e = !1,
        t = 500,
        i = null,
        n = this.throttle(t, (a, l) => {
          ((i = () => !0),
            this.liveSocket.js().push(this.el, a, {
              value: { id: l.id, _overran: !0 },
              callback: () => {
                i = null;
              },
            }));
        }),
        r = this.throttle(t, (a, l) => {
          ((i = () => l.scrollIntoView({ block: "start" })),
            this.liveSocket.js().push(this.el, a, {
              value: { id: l.id },
              callback: () => {
                ((i = null),
                  window.requestAnimationFrame(() => {
                    Si(l, this.scrollContainer) ||
                      l.scrollIntoView({ block: "start" });
                  }));
              },
            }));
        }),
        o = this.throttle(t, (a, l) => {
          ((i = () => l.scrollIntoView({ block: "end" })),
            this.liveSocket.js().push(this.el, a, {
              value: { id: l.id },
              callback: () => {
                ((i = null),
                  window.requestAnimationFrame(() => {
                    Si(l, this.scrollContainer) ||
                      l.scrollIntoView({ block: "end" });
                  }));
              },
            }));
        });
      ((this.onScroll = (a) => {
        let l = _i(this.scrollContainer);
        if (i) return ((s = l), i());
        let h = this.findOverrunTarget(),
          d = this.el.getAttribute(this.liveSocket.binding("viewport-top")),
          p = this.el.getAttribute(this.liveSocket.binding("viewport-bottom")),
          m = this.el.lastElementChild,
          g = this.el.firstElementChild,
          u = l < s,
          v = l > s;
        (u && d && !e && h.top >= 0
          ? ((e = !0), n(d, g))
          : v && e && h.top <= 0 && (e = !1),
          d && u && Gi(g, this.scrollContainer)
            ? r(d, g)
            : p && v && zi(m, this.scrollContainer) && o(p, m),
          (s = l));
      }),
        this.scrollContainer
          ? this.scrollContainer.addEventListener("scroll", this.onScroll)
          : window.addEventListener("scroll", this.onScroll));
    },
    destroyed() {
      this.scrollContainer
        ? this.scrollContainer.removeEventListener("scroll", this.onScroll)
        : window.removeEventListener("scroll", this.onScroll);
    },
    throttle(s, e) {
      let t = 0,
        i;
      return (...n) => {
        let r = Date.now(),
          o = s - (r - t);
        o <= 0 || o > s
          ? (i && (clearTimeout(i), (i = null)), (t = r), e(...n))
          : i ||
            (i = setTimeout(() => {
              ((t = Date.now()), (i = null), e(...n));
            }, o));
      };
    },
    findOverrunTarget() {
      let s,
        e = this.el.getAttribute(this.liveSocket.binding(ii));
      if (e) {
        let t = document.getElementById(e);
        if (t) s = t.getBoundingClientRect();
        else throw new Error("did not find element with id " + e);
      } else s = this.el.getBoundingClientRect();
      return s;
    },
  };
  var ki = wi;
  var ye = class {
    static onUnlock(e, t) {
      if (!c.isLocked(e) && !e.closest(`[${C}]`)) return t();
      let i = e.closest(`[${C}]`),
        n = i.closest(`[${C}]`).getAttribute(C);
      i.addEventListener(
        `phx:undo-lock:${n}`,
        () => {
          t();
        },
        { once: !0 },
      );
    }
    constructor(e) {
      ((this.el = e),
        (this.loadingRef = e.hasAttribute(ve)
          ? parseInt(e.getAttribute(ve), 10)
          : null),
        (this.lockRef = e.hasAttribute(C)
          ? parseInt(e.getAttribute(C), 10)
          : null));
    }
    maybeUndo(e, t, i) {
      if (!this.isWithin(e)) {
        c.updatePrivate(this.el, Ct, [], (n) => (n.push(e), n));
        return;
      }
      (this.undoLocks(e, t, i),
        this.undoLoading(e, t),
        c.updatePrivate(this.el, Ct, [], (n) =>
          n.filter((r) => {
            let o = {
              detail: { ref: r, event: t },
              bubbles: !0,
              cancelable: !1,
            };
            return (
              this.loadingRef &&
                this.loadingRef > r &&
                this.el.dispatchEvent(
                  new CustomEvent(`phx:undo-loading:${r}`, o),
                ),
              this.lockRef &&
                this.lockRef > r &&
                this.el.dispatchEvent(new CustomEvent(`phx:undo-lock:${r}`, o)),
              r > e
            );
          }),
        ),
        this.isFullyResolvedBy(e) && this.el.removeAttribute(N));
    }
    isWithin(e) {
      return !(
        this.loadingRef !== null &&
        this.loadingRef > e &&
        this.lockRef !== null &&
        this.lockRef > e
      );
    }
    undoLocks(e, t, i) {
      if (!this.isLockUndoneBy(e)) return;
      let n = c.private(this.el, C);
      (n && (i(n), c.deletePrivate(this.el, C)), this.el.removeAttribute(C));
      let r = { detail: { ref: e, event: t }, bubbles: !0, cancelable: !1 };
      this.el.dispatchEvent(
        new CustomEvent(`phx:undo-lock:${this.lockRef}`, r),
      );
    }
    undoLoading(e, t) {
      if (!this.isLoadingUndoneBy(e)) {
        this.canUndoLoading(e) &&
          this.el.classList.contains("phx-submit-loading") &&
          this.el.classList.remove("phx-change-loading");
        return;
      }
      if (this.canUndoLoading(e)) {
        this.el.removeAttribute(ve);
        let i = this.el.getAttribute(Ee),
          n = this.el.getAttribute(Ze);
        (n !== null &&
          ((this.el.readOnly = n === "true"), this.el.removeAttribute(Ze)),
          i !== null &&
            ((this.el.disabled = i === "true"), this.el.removeAttribute(Ee)));
        let r = this.el.getAttribute(Me);
        r !== null && ((this.el.textContent = r), this.el.removeAttribute(Me));
        let o = { detail: { ref: e, event: t }, bubbles: !0, cancelable: !1 };
        this.el.dispatchEvent(
          new CustomEvent(`phx:undo-loading:${this.loadingRef}`, o),
        );
      }
      dt.forEach((i) => {
        (i !== "phx-submit-loading" || this.canUndoLoading(e)) &&
          c.removeClass(this.el, i);
      });
    }
    isLoadingUndoneBy(e) {
      return this.loadingRef === null ? !1 : this.loadingRef <= e;
    }
    isLockUndoneBy(e) {
      return this.lockRef === null ? !1 : this.lockRef <= e;
    }
    isFullyResolvedBy(e) {
      return (
        (this.loadingRef === null || this.loadingRef <= e) &&
        (this.lockRef === null || this.lockRef <= e)
      );
    }
    canUndoLoading(e) {
      return this.lockRef === null || this.lockRef <= e;
    }
  };
  var nt = class {
    constructor(e, t, i) {
      let n = new Set(),
        r = new Set([...t.children].map((a) => a.id)),
        o = [];
      (Array.from(e.children).forEach((a) => {
        if (a.id && (n.add(a.id), r.has(a.id))) {
          let l = a.previousElementSibling && a.previousElementSibling.id;
          o.push({ elementId: a.id, previousElementId: l });
        }
      }),
        (this.containerId = t.id),
        (this.updateType = i),
        (this.elementsToModify = o),
        (this.elementIdsToAdd = [...r].filter((a) => !n.has(a))));
    }
    perform() {
      let e = c.byId(this.containerId);
      e &&
        (this.elementsToModify.forEach((t) => {
          t.previousElementId
            ? fe(document.getElementById(t.previousElementId), (i) => {
                fe(document.getElementById(t.elementId), (n) => {
                  (n.previousElementSibling &&
                    n.previousElementSibling.id == i.id) ||
                    i.insertAdjacentElement("afterend", n);
                });
              })
            : fe(document.getElementById(t.elementId), (i) => {
                i.previousElementSibling == null ||
                  e.insertAdjacentElement("afterbegin", i);
              });
        }),
        this.updateType == "prepend" &&
          this.elementIdsToAdd.reverse().forEach((t) => {
            fe(document.getElementById(t), (i) =>
              e.insertAdjacentElement("afterbegin", i),
            );
          }));
    }
  };
  var Ti = 11;
  function Yi(s, e) {
    var t = e.attributes,
      i,
      n,
      r,
      o,
      a;
    if (!(e.nodeType === Ti || s.nodeType === Ti)) {
      for (var l = t.length - 1; l >= 0; l--)
        ((i = t[l]),
          (n = i.name),
          (r = i.namespaceURI),
          (o = i.value),
          r
            ? ((n = i.localName || n),
              (a = s.getAttributeNS(r, n)),
              a !== o &&
                (i.prefix === "xmlns" && (n = i.name),
                s.setAttributeNS(r, n, o)))
            : ((a = s.getAttribute(n)), a !== o && s.setAttribute(n, o)));
      for (var h = s.attributes, d = h.length - 1; d >= 0; d--)
        ((i = h[d]),
          (n = i.name),
          (r = i.namespaceURI),
          r
            ? ((n = i.localName || n),
              e.hasAttributeNS(r, n) || s.removeAttributeNS(r, n))
            : e.hasAttribute(n) || s.removeAttribute(n));
    }
  }
  var At,
    Qi = "http://www.w3.org/1999/xhtml",
    B = typeof document == "undefined" ? void 0 : document,
    Zi = !!B && "content" in B.createElement("template"),
    en = !!B && B.createRange && "createContextualFragment" in B.createRange();
  function tn(s) {
    var e = B.createElement("template");
    return ((e.innerHTML = s), e.content.childNodes[0]);
  }
  function nn(s) {
    At || ((At = B.createRange()), At.selectNode(B.body));
    var e = At.createContextualFragment(s);
    return e.childNodes[0];
  }
  function sn(s) {
    var e = B.createElement("body");
    return ((e.innerHTML = s), e.childNodes[0]);
  }
  function rn(s) {
    return ((s = s.trim()), Zi ? tn(s) : en ? nn(s) : sn(s));
  }
  function _t(s, e) {
    var t = s.nodeName,
      i = e.nodeName,
      n,
      r;
    return t === i
      ? !0
      : ((n = t.charCodeAt(0)),
        (r = i.charCodeAt(0)),
        n <= 90 && r >= 97
          ? t === i.toUpperCase()
          : r <= 90 && n >= 97
            ? i === t.toUpperCase()
            : !1);
  }
  function on(s, e) {
    return !e || e === Qi ? B.createElement(s) : B.createElementNS(e, s);
  }
  function an(s, e) {
    for (var t = s.firstChild; t; ) {
      var i = t.nextSibling;
      (e.appendChild(t), (t = i));
    }
    return e;
  }
  function Jt(s, e, t) {
    s[t] !== e[t] &&
      ((s[t] = e[t]), s[t] ? s.setAttribute(t, "") : s.removeAttribute(t));
  }
  var Ci = {
      OPTION: function (s, e) {
        var t = s.parentNode;
        if (t) {
          var i = t.nodeName.toUpperCase();
          (i === "OPTGROUP" &&
            ((t = t.parentNode), (i = t && t.nodeName.toUpperCase())),
            i === "SELECT" &&
              !t.hasAttribute("multiple") &&
              (s.hasAttribute("selected") &&
                !e.selected &&
                (s.setAttribute("selected", "selected"),
                s.removeAttribute("selected")),
              (t.selectedIndex = -1)));
        }
        Jt(s, e, "selected");
      },
      INPUT: function (s, e) {
        (Jt(s, e, "checked"),
          Jt(s, e, "disabled"),
          s.value !== e.value && (s.value = e.value),
          e.hasAttribute("value") || s.removeAttribute("value"));
      },
      TEXTAREA: function (s, e) {
        var t = e.value;
        s.value !== t && (s.value = t);
        var i = s.firstChild;
        if (i) {
          var n = i.nodeValue;
          if (n == t || (!t && n == s.placeholder)) return;
          i.nodeValue = t;
        }
      },
      SELECT: function (s, e) {
        if (!e.hasAttribute("multiple")) {
          for (var t = -1, i = 0, n = s.firstChild, r, o; n; )
            if (
              ((o = n.nodeName && n.nodeName.toUpperCase()), o === "OPTGROUP")
            )
              ((r = n),
                (n = r.firstChild),
                n || ((n = r.nextSibling), (r = null)));
            else {
              if (o === "OPTION") {
                if (n.hasAttribute("selected")) {
                  t = i;
                  break;
                }
                i++;
              }
              ((n = n.nextSibling),
                !n && r && ((n = r.nextSibling), (r = null)));
            }
          s.selectedIndex = t;
        }
      },
    },
    st = 1,
    Ri = 11,
    xi = 3,
    Ii = 8;
  function Ae() {}
  function ln(s) {
    if (s) return (s.getAttribute && s.getAttribute("id")) || s.id;
  }
  function cn(s) {
    return function (t, i, n) {
      if ((n || (n = {}), typeof i == "string"))
        if (t.nodeName === "#document" || t.nodeName === "HTML") {
          var r = i;
          ((i = B.createElement("html")), (i.innerHTML = r));
        } else if (t.nodeName === "BODY") {
          var o = i;
          ((i = B.createElement("html")), (i.innerHTML = o));
          var a = i.querySelector("body");
          a && (i = a);
        } else i = rn(i);
      else i.nodeType === Ri && (i = i.firstElementChild);
      var l = n.getNodeKey || ln,
        h = n.onBeforeNodeAdded || Ae,
        d = n.onNodeAdded || Ae,
        p = n.onBeforeElUpdated || Ae,
        m = n.onElUpdated || Ae,
        g = n.onBeforeNodeDiscarded || Ae,
        u = n.onNodeDiscarded || Ae,
        v = n.onBeforeElChildrenUpdated || Ae,
        E = n.skipFromChildren || Ae,
        M =
          n.addChild ||
          function (y, A) {
            return y.appendChild(A);
          },
        j = n.childrenOnly === !0,
        F = Object.create(null),
        _ = [];
      function k(y) {
        _.push(y);
      }
      function I(y, A) {
        if (y.nodeType === st)
          for (var O = y.firstChild; O; ) {
            var P = void 0;
            (A && (P = l(O)) ? k(P) : (u(O), O.firstChild && I(O, A)),
              (O = O.nextSibling));
          }
      }
      function Z(y, A, O) {
        g(y) !== !1 && (A && A.removeChild(y), u(y), I(y, O));
      }
      function f(y) {
        if (y.nodeType === st || y.nodeType === Ri)
          for (var A = y.firstChild; A; ) {
            var O = l(A);
            (O && (F[O] = A), f(A), (A = A.nextSibling));
          }
      }
      f(t);
      function b(y) {
        d(y);
        for (var A = y.firstChild; A; ) {
          var O = A.nextSibling,
            P = l(A);
          if (P) {
            var T = F[P];
            T && _t(A, T) ? (A.parentNode.replaceChild(T, A), J(T, A)) : b(A);
          } else b(A);
          A = O;
        }
      }
      function U(y, A, O) {
        for (; A; ) {
          var P = A.nextSibling;
          ((O = l(A)) ? k(O) : Z(A, y, !0), (A = P));
        }
      }
      function J(y, A, O) {
        var P = l(A);
        if ((P && delete F[P], !O)) {
          var T = p(y, A);
          if (
            T === !1 ||
            (T instanceof HTMLElement && ((y = T), f(y)),
            s(y, A),
            m(y),
            v(y, A) === !1)
          )
            return;
        }
        y.nodeName !== "TEXTAREA" ? D(y, A) : Ci.TEXTAREA(y, A);
      }
      function D(y, A) {
        var O = E(y, A),
          P = A.firstChild,
          T = y.firstChild,
          xe,
          ae,
          Ie,
          at,
          me;
        e: for (; P; ) {
          for (at = P.nextSibling, xe = l(P); !O && T; ) {
            if (((Ie = T.nextSibling), P.isSameNode && P.isSameNode(T))) {
              ((P = at), (T = Ie));
              continue e;
            }
            ae = l(T);
            var lt = T.nodeType,
              ge = void 0;
            if (
              (lt === P.nodeType &&
                (lt === st
                  ? (xe
                      ? xe !== ae &&
                        ((me = F[xe])
                          ? Ie === me
                            ? (ge = !1)
                            : (y.insertBefore(me, T),
                              ae ? k(ae) : Z(T, y, !0),
                              (T = me),
                              (ae = l(T)))
                          : (ge = !1))
                      : ae && (ge = !1),
                    (ge = ge !== !1 && _t(T, P)),
                    ge && J(T, P))
                  : (lt === xi || lt == Ii) &&
                    ((ge = !0),
                    T.nodeValue !== P.nodeValue &&
                      (T.nodeValue = P.nodeValue))),
              ge)
            ) {
              ((P = at), (T = Ie));
              continue e;
            }
            (ae ? k(ae) : Z(T, y, !0), (T = Ie));
          }
          if (xe && (me = F[xe]) && _t(me, P)) (O || M(y, me), J(me, P));
          else {
            var Tt = h(P);
            Tt !== !1 &&
              (Tt && (P = Tt),
              P.actualize && (P = P.actualize(y.ownerDocument || B)),
              M(y, P),
              b(P));
          }
          ((P = at), (T = Ie));
        }
        U(y, T, ae);
        var Gt = Ci[y.nodeName];
        Gt && Gt(y, A);
      }
      var H = t,
        W = H.nodeType,
        qt = i.nodeType;
      if (!j) {
        if (W === st)
          qt === st
            ? _t(t, i) || (u(t), (H = an(t, on(i.nodeName, i.namespaceURI))))
            : (H = i);
        else if (W === xi || W === Ii) {
          if (qt === W)
            return (
              H.nodeValue !== i.nodeValue && (H.nodeValue = i.nodeValue),
              H
            );
          H = i;
        }
      }
      if (H === i) u(t);
      else {
        if (i.isSameNode && i.isSameNode(H)) return;
        if ((J(H, i, j), _))
          for (var Pt = 0, Ni = _.length; Pt < Ni; Pt++) {
            var kt = F[_[Pt]];
            kt && Z(kt, kt.parentNode, !1);
          }
      }
      return (
        !j &&
          H !== t &&
          t.parentNode &&
          (H.actualize && (H = H.actualize(t.ownerDocument || B)),
          t.parentNode.replaceChild(H, t)),
        H
      );
    };
  }
  var hn = cn(Yi),
    rt = hn;
  var _e = class {
    constructor(e, t, i, n, r, o, a = {}) {
      ((this.view = e),
        (this.liveSocket = e.liveSocket),
        (this.container = t),
        (this.id = i),
        (this.rootID = e.root.id),
        (this.html = n),
        (this.streams = r),
        (this.streamInserts = {}),
        (this.streamComponentRestore = {}),
        (this.targetCID = o),
        (this.cidPatch = ee(this.targetCID)),
        (this.pendingRemoves = []),
        (this.phxRemove = this.liveSocket.binding("remove")),
        (this.targetContainer = this.isCIDPatch()
          ? this.targetCIDContainer(n)
          : t),
        (this.callbacks = {
          beforeadded: [],
          beforeupdated: [],
          beforephxChildAdded: [],
          afteradded: [],
          afterupdated: [],
          afterdiscarded: [],
          afterphxChildAdded: [],
          aftertransitionsDiscarded: [],
        }),
        (this.withChildren = a.withChildren || a.undoRef || !1),
        (this.undoRef = a.undoRef));
    }
    before(e, t) {
      this.callbacks[`before${e}`].push(t);
    }
    after(e, t) {
      this.callbacks[`after${e}`].push(t);
    }
    trackBefore(e, ...t) {
      this.callbacks[`before${e}`].forEach((i) => i(...t));
    }
    trackAfter(e, ...t) {
      this.callbacks[`after${e}`].forEach((i) => i(...t));
    }
    markPrunableContentForRemoval() {
      let e = this.liveSocket.binding(Fe);
      c.all(this.container, `[${e}=append] > *, [${e}=prepend] > *`, (t) => {
        t.setAttribute(Rt, "");
      });
    }
    perform(e) {
      let { view: t, liveSocket: i, html: n, container: r } = this,
        o = this.targetContainer;
      if (this.isCIDPatch() && !this.targetContainer) return;
      if (this.isCIDPatch()) {
        let _ = o.closest(`[${C}]`);
        if (_ && !_.isSameNode(o)) {
          let k = c.private(_, C);
          k &&
            (o = k.querySelector(`[data-phx-component="${this.targetCID}"]`));
        }
      }
      let a = i.getActiveElement(),
        { selectionStart: l, selectionEnd: h } =
          a && c.hasSelectionRange(a) ? a : {},
        d = i.binding(Fe),
        p = i.binding(ze),
        m = i.binding(Ye),
        g = i.binding(ni),
        u = [],
        v = [],
        E = [],
        M = [],
        j = null,
        F = (_, k, I = this.withChildren) => {
          let Z = {
            childrenOnly: _.getAttribute(K) === null && !I,
            getNodeKey: (f) =>
              c.isPhxDestroyed(f)
                ? null
                : e
                  ? f.id
                  : f.id || (f.getAttribute && f.getAttribute(gt)),
            skipFromChildren: (f) => f.getAttribute(d) === Ue,
            addChild: (f, b) => {
              let { ref: U, streamAt: J } = this.getStreamInsert(b);
              if (U === void 0) return f.appendChild(b);
              if ((this.setStreamRef(b, U), J === 0))
                f.insertAdjacentElement("afterbegin", b);
              else if (J === -1) {
                let D = f.lastElementChild;
                if (D && !D.hasAttribute(Xe)) {
                  let H = Array.from(f.children).find(
                    (W) => !W.hasAttribute(Xe),
                  );
                  f.insertBefore(b, H);
                } else f.appendChild(b);
              } else if (J > 0) {
                let D = Array.from(f.children)[J];
                f.insertBefore(b, D);
              }
            },
            onBeforeNodeAdded: (f) => {
              var U;
              if (
                (U = this.getStreamInsert(f)) != null &&
                U.updateOnly &&
                !this.streamComponentRestore[f.id]
              )
                return !1;
              (c.maintainPrivateHooks(f, f, p, m),
                this.trackBefore("added", f));
              let b = f;
              return (
                this.streamComponentRestore[f.id] &&
                  ((b = this.streamComponentRestore[f.id]),
                  delete this.streamComponentRestore[f.id],
                  F(b, f, !0)),
                b
              );
            },
            onNodeAdded: (f) => {
              (f.getAttribute && this.maybeReOrderStream(f, !0),
                c.isPortalTemplate(f) && M.push(() => this.teleport(f, F)),
                f instanceof HTMLImageElement && f.srcset
                  ? (f.srcset = f.srcset)
                  : f instanceof HTMLVideoElement && f.autoplay && f.play(),
                c.isNowTriggerFormExternal(f, g) && (j = f),
                ((c.isPhxChild(f) && t.ownsElement(f)) ||
                  (c.isPhxSticky(f) && t.ownsElement(f.parentNode))) &&
                  this.trackAfter("phxChildAdded", f),
                f.nodeName === "SCRIPT" &&
                  f.hasAttribute(Ve) &&
                  this.handleRuntimeHook(f, k),
                u.push(f));
            },
            onNodeDiscarded: (f) => this.onNodeDiscarded(f),
            onBeforeNodeDiscarded: (f) => {
              if (f.getAttribute && f.getAttribute(Rt) !== null) return !0;
              if (
                (f.parentElement !== null &&
                  f.id &&
                  c.isPhxUpdate(f.parentElement, d, [
                    Ue,
                    "append",
                    "prepend",
                  ])) ||
                (f.getAttribute && f.getAttribute(oe)) ||
                this.maybePendingRemove(f) ||
                this.skipCIDSibling(f)
              )
                return !1;
              if (c.isPortalTemplate(f)) {
                let b = document.getElementById(f.content.firstElementChild.id);
                b &&
                  (b.remove(),
                  Z.onNodeDiscarded(b),
                  this.view.dropPortalElementId(b.id));
              }
              return !0;
            },
            onElUpdated: (f) => {
              (c.isNowTriggerFormExternal(f, g) && (j = f),
                v.push(f),
                this.maybeReOrderStream(f, !1));
            },
            onBeforeElUpdated: (f, b) => {
              if (f.id && f.isSameNode(_) && f.id !== b.id)
                return (
                  Z.onNodeDiscarded(f),
                  f.replaceWith(b),
                  Z.onNodeAdded(b)
                );
              if (
                (c.syncPendingAttrs(f, b),
                c.maintainPrivateHooks(f, b, p, m),
                c.cleanChildNodes(b, d),
                this.skipCIDSibling(b))
              )
                return (this.maybeReOrderStream(f), !1);
              if (c.isPhxSticky(f))
                return (
                  [q, re, z]
                    .map((D) => [D, f.getAttribute(D), b.getAttribute(D)])
                    .forEach(([D, H, W]) => {
                      W && H !== W && f.setAttribute(D, W);
                    }),
                  !1
                );
              if (c.isIgnored(f, d) || (f.form && f.form.isSameNode(j)))
                return (
                  this.trackBefore("updated", f, b),
                  c.mergeAttrs(f, b, { isIgnored: c.isIgnored(f, d) }),
                  v.push(f),
                  c.applyStickyOperations(f),
                  !1
                );
              if (f.type === "number" && f.validity && f.validity.badInput)
                return !1;
              let U = a && f.isSameNode(a) && c.isFormInput(f),
                J = U && this.isChangedSelect(f, b);
              if (f.hasAttribute(N)) {
                let D = new ye(f);
                if (
                  D.lockRef &&
                  (!this.undoRef || !D.isLockUndoneBy(this.undoRef))
                ) {
                  c.applyStickyOperations(f);
                  let W = f.hasAttribute(C)
                    ? c.private(f, C) || f.cloneNode(!0)
                    : null;
                  W && (c.putPrivate(f, C, W), U || (f = W));
                }
              }
              if (c.isPhxChild(b)) {
                let D = f.getAttribute(q);
                return (
                  c.mergeAttrs(f, b, { exclude: [re] }),
                  D !== "" && f.setAttribute(q, D),
                  f.setAttribute(z, this.rootID),
                  c.applyStickyOperations(f),
                  !1
                );
              }
              return (
                this.undoRef &&
                  c.private(b, C) &&
                  c.putPrivate(f, C, c.private(b, C)),
                c.copyPrivates(b, f),
                c.isPortalTemplate(b)
                  ? (M.push(() => this.teleport(b, F)),
                    f.content.replaceChildren(b.content.cloneNode(!0)),
                    !1)
                  : U && f.type !== "hidden" && !J
                    ? (this.trackBefore("updated", f, b),
                      c.mergeFocusedInput(f, b),
                      c.syncAttrsToProps(f),
                      v.push(f),
                      c.applyStickyOperations(f),
                      !1)
                    : (J && f.blur(),
                      c.isPhxUpdate(b, d, ["append", "prepend"]) &&
                        E.push(new nt(f, b, b.getAttribute(d))),
                      c.syncAttrsToProps(b),
                      c.applyStickyOperations(b),
                      this.trackBefore("updated", f, b),
                      f)
              );
            },
          };
          rt(_, k, Z);
        };
      if (
        (this.trackBefore("added", r),
        this.trackBefore("updated", r, r),
        i.time("morphdom", () => {
          (this.streams.forEach(([k, I, Z, f]) => {
            (I.forEach(([b, U, J, D]) => {
              this.streamInserts[b] = {
                ref: k,
                streamAt: U,
                limit: J,
                reset: f,
                updateOnly: D,
              };
            }),
              f !== void 0 &&
                c.all(document, `[${Xe}="${k}"]`, (b) => {
                  this.removeStreamChildElement(b);
                }),
              Z.forEach((b) => {
                let U = document.getElementById(b);
                U && this.removeStreamChildElement(U);
              }));
          }),
            e &&
              c
                .all(this.container, `[${d}=${Ue}]`)
                .filter((k) => this.view.ownsElement(k))
                .forEach((k) => {
                  Array.from(k.children).forEach((I) => {
                    this.removeStreamChildElement(I, !0);
                  });
                }),
            F(o, n));
          let _ = 0;
          for (; M.length > 0 && _ < 5; ) {
            let k = M.slice();
            ((M = []), k.forEach((I) => I()), _++);
          }
          this.view.portalElementIds.forEach((k) => {
            let I = document.getElementById(k);
            I &&
              (document.getElementById(I.getAttribute(te)) ||
                (I.remove(),
                this.onNodeDiscarded(I),
                this.view.dropPortalElementId(k)));
          });
        }),
        i.isDebugEnabled() &&
          (gi(),
          vi(this.streamInserts),
          Array.from(document.querySelectorAll("input[name=id]")).forEach(
            (_) => {
              _ instanceof HTMLInputElement &&
                _.form &&
                console.error(
                  `Detected an input with name="id" inside a form! This will cause problems when patching the DOM.
`,
                  _,
                );
            },
          )),
        E.length > 0 &&
          i.time("post-morph append/prepend restoration", () => {
            E.forEach((_) => _.perform());
          }),
        i.silenceEvents(() => c.restoreFocus(a, l, h)),
        c.dispatchEvent(document, "phx:update"),
        u.forEach((_) => this.trackAfter("added", _)),
        v.forEach((_) => this.trackAfter("updated", _)),
        this.transitionPendingRemoves(),
        j)
      ) {
        i.unload();
        let _ = c.private(j, "submitter");
        if (_ && _.name && o.contains(_)) {
          let k = document.createElement("input");
          k.type = "hidden";
          let I = _.getAttribute("form");
          (I && k.setAttribute("form", I),
            (k.name = _.name),
            (k.value = _.value),
            _.parentElement.insertBefore(k, _));
        }
        Object.getPrototypeOf(j).submit.call(j);
      }
      return !0;
    }
    onNodeDiscarded(e) {
      ((c.isPhxChild(e) || c.isPhxSticky(e)) &&
        this.liveSocket.destroyViewByEl(e),
        this.trackAfter("discarded", e));
    }
    maybePendingRemove(e) {
      return e.getAttribute && e.getAttribute(this.phxRemove) !== null
        ? (this.pendingRemoves.push(e), !0)
        : !1;
    }
    removeStreamChildElement(e, t = !1) {
      (!t && !this.view.ownsElement(e)) ||
        (this.streamInserts[e.id]
          ? ((this.streamComponentRestore[e.id] = e), e.remove())
          : this.maybePendingRemove(e) ||
            (e.remove(), this.onNodeDiscarded(e)));
    }
    getStreamInsert(e) {
      return (e.id ? this.streamInserts[e.id] : {}) || {};
    }
    setStreamRef(e, t) {
      c.putSticky(e, Xe, (i) => i.setAttribute(Xe, t));
    }
    maybeReOrderStream(e, t) {
      let { ref: i, streamAt: n, reset: r } = this.getStreamInsert(e);
      if (
        n !== void 0 &&
        (this.setStreamRef(e, i), !(!r && !t) && e.parentElement)
      ) {
        if (n === 0)
          e.parentElement.insertBefore(e, e.parentElement.firstElementChild);
        else if (n > 0) {
          let o = Array.from(e.parentElement.children),
            a = o.indexOf(e);
          if (n >= o.length - 1) e.parentElement.appendChild(e);
          else {
            let l = o[n];
            a > n
              ? e.parentElement.insertBefore(e, l)
              : e.parentElement.insertBefore(e, l.nextElementSibling);
          }
        }
        this.maybeLimitStream(e);
      }
    }
    maybeLimitStream(e) {
      let { limit: t } = this.getStreamInsert(e),
        i = t !== null && Array.from(e.parentElement.children);
      t && t < 0 && i.length > t * -1
        ? i
            .slice(0, i.length + t)
            .forEach((n) => this.removeStreamChildElement(n))
        : t &&
          t >= 0 &&
          i.length > t &&
          i.slice(t).forEach((n) => this.removeStreamChildElement(n));
    }
    transitionPendingRemoves() {
      let { pendingRemoves: e, liveSocket: t } = this;
      e.length > 0 &&
        t.transitionRemoves(e, () => {
          (e.forEach((i) => {
            let n = c.firstPhxChild(i);
            (n && t.destroyViewByEl(n), i.remove());
          }),
            this.trackAfter("transitionsDiscarded", e));
        });
    }
    isChangedSelect(e, t) {
      return !(e instanceof HTMLSelectElement) || e.multiple
        ? !1
        : e.options.length !== t.options.length
          ? !0
          : ((t.value = e.value), !e.isEqualNode(t));
    }
    isCIDPatch() {
      return this.cidPatch;
    }
    skipCIDSibling(e) {
      return e.nodeType === Node.ELEMENT_NODE && e.hasAttribute(mt);
    }
    targetCIDContainer(e) {
      if (!this.isCIDPatch()) return;
      let [t, ...i] = c.findComponentNodeList(this.view.id, this.targetCID);
      return i.length === 0 && c.childNodeLength(e) === 1
        ? t
        : t && t.parentNode;
    }
    indexOf(e, t) {
      return Array.from(e.children).indexOf(t);
    }
    teleport(e, t) {
      let i = e.getAttribute($e),
        n = document.querySelector(i);
      if (!n)
        throw new Error("portal target with selector " + i + " not found");
      let r = e.content.firstElementChild;
      if (this.skipCIDSibling(r)) return;
      if (!(r != null && r.id))
        throw new Error(
          "phx-portal template must have a single root element with ID!",
        );
      let o = document.getElementById(r.id),
        a;
      (o
        ? (n.contains(o) || n.appendChild(o), (a = o))
        : ((a = document.createElement(r.tagName)), n.appendChild(a)),
        r.setAttribute(oe, this.view.id),
        r.setAttribute(te, e.id),
        t(a, r, !0),
        r.removeAttribute(oe),
        r.removeAttribute(te),
        this.view.pushPortalElementId(r.id));
    }
    handleRuntimeHook(e, t) {
      let i = e.getAttribute(Ve),
        n = e.hasAttribute("nonce") ? e.getAttribute("nonce") : null;
      if (e.hasAttribute("nonce")) {
        let o = document.createElement("template");
        ((o.innerHTML = t),
          (n = o.content
            .querySelector(`script[${Ve}="${CSS.escape(i)}"]`)
            .getAttribute("nonce")));
      }
      let r = document.createElement("script");
      ((r.textContent = e.textContent),
        c.mergeAttrs(r, e, { isIgnored: !1 }),
        n && (r.nonce = n),
        e.replaceWith(r),
        (e = r));
    }
  };
  var dn = new Set([
      "area",
      "base",
      "br",
      "col",
      "command",
      "embed",
      "hr",
      "img",
      "input",
      "keygen",
      "link",
      "meta",
      "param",
      "source",
      "track",
      "wbr",
    ]),
    un = new Set(["'", '"']),
    Oi = (s, e, t) => {
      let i = 0,
        n = !1,
        r,
        o,
        a,
        l,
        h,
        d,
        p = s.match(/^(\s*(?:<!--.*?-->\s*)*)<([^\s\/>]+)/);
      if (p === null) throw new Error(`malformed html ${s}`);
      for (
        i = p[0].length, r = p[1], a = p[2], l = i, i;
        i < s.length && s.charAt(i) !== ">";
        i++
      )
        if (s.charAt(i) === "=") {
          let u = s.slice(i - 3, i) === " id";
          i++;
          let v = s.charAt(i);
          if (un.has(v)) {
            let E = i;
            for (i++, i; i < s.length && s.charAt(i) !== v; i++);
            if (u) {
              h = s.slice(E + 1, i);
              break;
            }
          }
        }
      let m = s.length - 1;
      for (n = !1; m >= r.length + a.length; ) {
        let u = s.charAt(m);
        if (n)
          u === "-" && s.slice(m - 3, m) === "<!-"
            ? ((n = !1), (m -= 4))
            : (m -= 1);
        else if (u === ">" && s.slice(m - 2, m) === "--") ((n = !0), (m -= 3));
        else {
          if (u === ">") break;
          m -= 1;
        }
      }
      o = s.slice(m + 1, s.length);
      let g = Object.keys(e)
        .map((u) => (e[u] === !0 ? u : `${u}="${e[u]}"`))
        .join(" ");
      if (t) {
        let u = h ? ` id="${h}"` : "";
        dn.has(a)
          ? (d = `<${a}${u}${g === "" ? "" : " "}${g}/>`)
          : (d = `<${a}${u}${g === "" ? "" : " "}${g}></${a}>`);
      } else {
        let u = s.slice(l, m + 1);
        d = `<${a}${g === "" ? "" : " "}${g}${u}`;
      }
      return [d, r, o];
    },
    Ke = class {
      static extract(e) {
        let { [Xt]: t, [Ut]: i, [$t]: n } = e;
        return (
          delete e[Xt],
          delete e[Ut],
          delete e[$t],
          { diff: e, title: n, reply: t || null, events: i || [] }
        );
      }
      constructor(e, t) {
        ((this.viewId = e),
          (this.rendered = {}),
          (this.magicId = 0),
          this.mergeDiff(t));
      }
      parentViewId() {
        return this.viewId;
      }
      toString(e) {
        let { buffer: t, streams: i } = this.recursiveToString(
          this.rendered,
          this.rendered[X],
          e,
          !0,
          {},
        );
        return { buffer: t, streams: i };
      }
      recursiveToString(e, t = e[X], i, n, r) {
        i = i ? new Set(i) : null;
        let o = { buffer: "", components: t, onlyCids: i, streams: new Set() };
        return (
          this.toOutputBuffer(e, null, o, n, r),
          { buffer: o.buffer, streams: o.streams }
        );
      }
      componentCIDs(e) {
        return Object.keys(e[X] || {}).map((t) => parseInt(t));
      }
      isComponentOnlyDiff(e) {
        return e[X] ? Object.keys(e).length === 1 : !1;
      }
      getComponent(e, t) {
        return e[X][t];
      }
      resetRender(e) {
        this.rendered[X][e] && (this.rendered[X][e].reset = !0);
      }
      mergeDiff(e) {
        let t = e[X],
          i = {};
        if (
          (delete e[X],
          (this.rendered = this.mutableMerge(this.rendered, e)),
          (this.rendered[X] = this.rendered[X] || {}),
          t)
        ) {
          let n = this.rendered[X];
          for (let r in t) t[r] = this.cachedFindComponent(r, t[r], n, t, i);
          for (let r in t) n[r] = t[r];
          e[X] = t;
        }
      }
      cachedFindComponent(e, t, i, n, r) {
        if (r[e]) return r[e];
        {
          let o,
            a,
            l = t[Y];
          if (ee(l)) {
            let h;
            (l > 0
              ? (h = this.cachedFindComponent(l, n[l], i, n, r))
              : (h = i[-l]),
              (a = h[Y]),
              (o = this.cloneMerge(h, t, !0)),
              (o[Y] = a));
          } else
            o =
              t[Y] !== void 0 || i[e] === void 0
                ? t
                : this.cloneMerge(i[e], t, !1);
          return ((r[e] = o), o);
        }
      }
      mutableMerge(e, t) {
        return t[Y] !== void 0 ? t : (this.doMutableMerge(e, t), e);
      }
      doMutableMerge(e, t) {
        if (t[x]) this.mergeKeyed(e, t);
        else
          for (let i in t) {
            let n = t[i],
              r = e[i];
            Te(n) && n[Y] === void 0 && Te(r)
              ? this.doMutableMerge(r, n)
              : (e[i] = n);
          }
        e[yt] && (e.newRender = !0);
      }
      clone(e) {
        return "structuredClone" in window
          ? structuredClone(e)
          : JSON.parse(JSON.stringify(e));
      }
      mergeKeyed(e, t) {
        let i = this.clone(e);
        if (
          (Object.entries(t[x]).forEach(([n, r]) => {
            if (n !== ne)
              if (Array.isArray(r)) {
                let [o, a] = r;
                ((e[x][n] = i[x][o]), this.doMutableMerge(e[x][n], a));
              } else if (typeof r == "number") {
                let o = r;
                e[x][n] = i[x][o];
              } else
                typeof r == "object" &&
                  (e[x][n] || (e[x][n] = {}), this.doMutableMerge(e[x][n], r));
          }),
          t[x][ne] < e[x][ne])
        )
          for (let n = t[x][ne]; n < e[x][ne]; n++) delete e[x][n];
        ((e[x][ne] = t[x][ne]),
          t[ke] && (e[ke] = t[ke]),
          t[de] && (e[de] = t[de]));
      }
      cloneMerge(e, t, i) {
        let n;
        if (t[x]) ((n = this.clone(e)), this.mergeKeyed(n, t));
        else {
          n = L(L({}, e), t);
          for (let r in n) {
            let o = t[r],
              a = e[r];
            Te(o) && o[Y] === void 0 && Te(a)
              ? (n[r] = this.cloneMerge(a, o, i))
              : o === void 0 && Te(a) && (n[r] = this.cloneMerge(a, {}, i));
          }
        }
        return (
          i
            ? (delete n.magicId, delete n.newRender)
            : e[yt] && (n.newRender = !0),
          n
        );
      }
      componentToString(e) {
        let { buffer: t, streams: i } = this.recursiveCIDToString(
            this.rendered[X],
            e,
            null,
          ),
          [n, r, o] = Oi(t, {});
        return { buffer: n, streams: i };
      }
      pruneCIDs(e) {
        e.forEach((t) => delete this.rendered[X][t]);
      }
      get() {
        return this.rendered;
      }
      isNewFingerprint(e = {}) {
        return !!e[Y];
      }
      templateStatic(e, t) {
        return typeof e == "number" ? t[e] : e;
      }
      nextMagicID() {
        return (this.magicId++, `m${this.magicId}-${this.parentViewId()}`);
      }
      toOutputBuffer(e, t, i, n, r = {}) {
        if (e[x]) return this.comprehensionToBuffer(e, t, i, n);
        e[de] && ((t = e[de]), delete e[de]);
        let { [Y]: o } = e;
        ((o = this.templateStatic(o, t)), (e[Y] = o));
        let a = e[yt],
          l = i.buffer;
        (a && (i.buffer = ""),
          n &&
            a &&
            !e.magicId &&
            ((e.newRender = !0), (e.magicId = this.nextMagicID())),
          (i.buffer += o[0]));
        for (let h = 1; h < o.length; h++)
          (this.dynamicToBuffer(e[h - 1], t, i, n), (i.buffer += o[h]));
        if (a) {
          let h = !1,
            d;
          (n || e.magicId
            ? ((h = n && !e.newRender), (d = L({ [gt]: e.magicId }, r)))
            : (d = r),
            h && (d[mt] = !0));
          let [p, m, g] = Oi(i.buffer, d, h);
          ((e.newRender = !1), (i.buffer = l + m + p + g));
        }
      }
      comprehensionToBuffer(e, t, i, n) {
        let r = t || e[de],
          o = this.templateStatic(e[Y], t);
        ((e[Y] = o), delete e[de]);
        for (let a = 0; a < e[x][ne]; a++) {
          i.buffer += o[0];
          for (let l = 1; l < o.length; l++)
            (this.dynamicToBuffer(e[x][a][l - 1], r, i, n), (i.buffer += o[l]));
        }
        if (e[ke]) {
          let a = e[ke],
            [l, h, d, p] = a || [null, {}, [], null];
          a !== void 0 &&
            (e[x][ne] > 0 || d.length > 0 || p) &&
            (delete e[ke], (e[x] = { [ne]: 0 }), i.streams.add(a));
        }
      }
      dynamicToBuffer(e, t, i, n) {
        if (typeof e == "number") {
          let { buffer: r, streams: o } = this.recursiveCIDToString(
            i.components,
            e,
            i.onlyCids,
          );
          ((i.buffer += r), (i.streams = new Set([...i.streams, ...o])));
        } else Te(e) ? this.toOutputBuffer(e, t, i, n, {}) : (i.buffer += e);
      }
      recursiveCIDToString(e, t, i) {
        let n = e[t] || w(`no component for CID ${t}`, e),
          r = { [K]: t, [ce]: this.viewId },
          o = i && !i.has(t);
        ((n.newRender = !o), (n.magicId = `c${t}-${this.parentViewId()}`));
        let a = !n.reset,
          { buffer: l, streams: h } = this.recursiveToString(n, e, i, a, r);
        return (delete n.reset, { buffer: l, streams: h });
      }
    };
  var Li = [],
    Hi = 200,
    fn = {
      exec(s, e, t, i, n, r) {
        let [o, a] = r || [null, { callback: r && r.callback }];
        (t.charAt(0) === "[" ? JSON.parse(t) : [[o, a]]).forEach(([h, d]) => {
          (h === o &&
            ((d = L(L({}, a), d)), (d.callback = d.callback || a.callback)),
            this.filterToEls(i.liveSocket, n, d).forEach((p) => {
              this[`exec_${h}`](s, e, t, i, n, p, d);
            }));
        });
      },
      isVisible(s) {
        return !!(
          s.offsetWidth ||
          s.offsetHeight ||
          s.getClientRects().length > 0
        );
      },
      isInViewport(s) {
        let e = s.getBoundingClientRect(),
          t = window.innerHeight || document.documentElement.clientHeight,
          i = window.innerWidth || document.documentElement.clientWidth;
        return e.right > 0 && e.bottom > 0 && e.left < i && e.top < t;
      },
      exec_exec(s, e, t, i, n, r, { attr: o, to: a }) {
        let l = r.getAttribute(o);
        if (!l)
          throw new Error(`expected ${o} to contain JS command on "${a}"`);
        i.liveSocket.execJS(r, l, e);
      },
      exec_dispatch(
        s,
        e,
        t,
        i,
        n,
        r,
        { event: o, detail: a, bubbles: l, blocking: h },
      ) {
        if (((a = a || {}), (a.dispatcher = n), h)) {
          let d = new Promise((p, m) => {
            a.done = p;
          });
          i.liveSocket.asyncTransition(d);
        }
        c.dispatchEvent(r, o, { detail: a, bubbles: l });
      },
      exec_push(s, e, t, i, n, r, o) {
        let {
            event: a,
            data: l,
            target: h,
            page_loading: d,
            loading: p,
            value: m,
            dispatcher: g,
            callback: u,
          } = o,
          v = {
            loading: p,
            value: m,
            target: h,
            page_loading: !!d,
            originalEvent: s,
          },
          E = e === "change" && g ? g : n,
          M = h || E.getAttribute(i.binding("target")) || E,
          j = (F, _) => {
            if (F.isConnected())
              if (e === "change") {
                let { newCid: k, _target: I } = o;
                ((I = I || (c.isFormInput(n) ? n.name : void 0)),
                  I && (v._target = I),
                  F.pushInput(n, _, k, a || t, v, u));
              } else if (e === "submit") {
                let { submitter: k } = o;
                F.submitForm(n, _, a || t, k, v, u);
              } else F.pushEvent(e, n, _, a || t, l, v, u);
          };
        o.targetView && o.targetCtx
          ? j(o.targetView, o.targetCtx)
          : i.withinTargets(M, j);
      },
      exec_navigate(s, e, t, i, n, r, { href: o, replace: a }) {
        i.liveSocket.historyRedirect(s, o, a ? "replace" : "push", null, n);
      },
      exec_patch(s, e, t, i, n, r, { href: o, replace: a }) {
        i.liveSocket.pushHistoryPatch(s, o, a ? "replace" : "push", n);
      },
      exec_focus(s, e, t, i, n, r) {
        (V.attemptFocus(r),
          window.requestAnimationFrame(() => {
            window.requestAnimationFrame(() => V.attemptFocus(r));
          }));
      },
      exec_focus_first(s, e, t, i, n, r) {
        (V.focusFirstInteractive(r) || V.focusFirst(r),
          window.requestAnimationFrame(() => {
            window.requestAnimationFrame(
              () => V.focusFirstInteractive(r) || V.focusFirst(r),
            );
          }));
      },
      exec_push_focus(s, e, t, i, n, r) {
        Li.push(r || n);
      },
      exec_pop_focus(s, e, t, i, n, r) {
        let o = Li.pop();
        o &&
          (o.focus(),
          window.requestAnimationFrame(() => {
            window.requestAnimationFrame(() => o.focus());
          }));
      },
      exec_add_class(
        s,
        e,
        t,
        i,
        n,
        r,
        { names: o, transition: a, time: l, blocking: h },
      ) {
        this.addOrRemoveClasses(r, o, [], a, l, i, h);
      },
      exec_remove_class(
        s,
        e,
        t,
        i,
        n,
        r,
        { names: o, transition: a, time: l, blocking: h },
      ) {
        this.addOrRemoveClasses(r, [], o, a, l, i, h);
      },
      exec_toggle_class(
        s,
        e,
        t,
        i,
        n,
        r,
        { names: o, transition: a, time: l, blocking: h },
      ) {
        this.toggleClasses(r, o, a, l, i, h);
      },
      exec_toggle_attr(s, e, t, i, n, r, { attr: [o, a, l] }) {
        this.toggleAttr(r, o, a, l);
      },
      exec_ignore_attrs(s, e, t, i, n, r, { attrs: o }) {
        this.ignoreAttrs(r, o);
      },
      exec_transition(
        s,
        e,
        t,
        i,
        n,
        r,
        { time: o, transition: a, blocking: l },
      ) {
        this.addOrRemoveClasses(r, [], [], a, o, i, l);
      },
      exec_toggle(
        s,
        e,
        t,
        i,
        n,
        r,
        { display: o, ins: a, outs: l, time: h, blocking: d },
      ) {
        this.toggle(e, i, r, o, a, l, h, d);
      },
      exec_show(
        s,
        e,
        t,
        i,
        n,
        r,
        { display: o, transition: a, time: l, blocking: h },
      ) {
        this.show(e, i, r, o, a, l, h);
      },
      exec_hide(
        s,
        e,
        t,
        i,
        n,
        r,
        { display: o, transition: a, time: l, blocking: h },
      ) {
        this.hide(e, i, r, o, a, l, h);
      },
      exec_set_attr(s, e, t, i, n, r, { attr: [o, a] }) {
        this.setOrRemoveAttrs(r, [[o, a]], []);
      },
      exec_remove_attr(s, e, t, i, n, r, { attr: o }) {
        this.setOrRemoveAttrs(r, [], [o]);
      },
      ignoreAttrs(s, e) {
        c.putPrivate(s, "JS:ignore_attrs", {
          apply: (t, i) => {
            let n = Array.from(t.attributes),
              r = n.map((o) => o.name);
            (Array.from(i.attributes)
              .filter((o) => !r.includes(o.name))
              .forEach((o) => {
                c.attributeIgnored(o, e) && i.removeAttribute(o.name);
              }),
              n.forEach((o) => {
                c.attributeIgnored(o, e) && i.setAttribute(o.name, o.value);
              }));
          },
        });
      },
      onBeforeElUpdated(s, e) {
        let t = c.private(s, "JS:ignore_attrs");
        t && t.apply(s, e);
      },
      show(s, e, t, i, n, r, o) {
        this.isVisible(t) || this.toggle(s, e, t, i, n, null, r, o);
      },
      hide(s, e, t, i, n, r, o) {
        this.isVisible(t) && this.toggle(s, e, t, i, null, n, r, o);
      },
      toggle(s, e, t, i, n, r, o, a) {
        o = o || Hi;
        let [l, h, d] = n || [[], [], []],
          [p, m, g] = r || [[], [], []];
        if (l.length > 0 || p.length > 0)
          if (this.isVisible(t)) {
            let u = () => {
                (this.addOrRemoveClasses(t, m, l.concat(h).concat(d)),
                  window.requestAnimationFrame(() => {
                    (this.addOrRemoveClasses(t, p, []),
                      window.requestAnimationFrame(() =>
                        this.addOrRemoveClasses(t, g, m),
                      ));
                  }));
              },
              v = () => {
                (this.addOrRemoveClasses(t, [], p.concat(g)),
                  c.putSticky(t, "toggle", (E) => (E.style.display = "none")),
                  t.dispatchEvent(new Event("phx:hide-end")));
              };
            (t.dispatchEvent(new Event("phx:hide-start")),
              a === !1 ? (u(), setTimeout(v, o)) : e.transition(o, u, v));
          } else {
            if (s === "remove") return;
            let u = () => {
                this.addOrRemoveClasses(t, h, p.concat(m).concat(g));
                let E = i || this.defaultDisplay(t);
                window.requestAnimationFrame(() => {
                  (this.addOrRemoveClasses(t, l, []),
                    window.requestAnimationFrame(() => {
                      (c.putSticky(t, "toggle", (M) => (M.style.display = E)),
                        this.addOrRemoveClasses(t, d, h));
                    }));
                });
              },
              v = () => {
                (this.addOrRemoveClasses(t, [], l.concat(d)),
                  t.dispatchEvent(new Event("phx:show-end")));
              };
            (t.dispatchEvent(new Event("phx:show-start")),
              a === !1 ? (u(), setTimeout(v, o)) : e.transition(o, u, v));
          }
        else
          this.isVisible(t)
            ? window.requestAnimationFrame(() => {
                (t.dispatchEvent(new Event("phx:hide-start")),
                  c.putSticky(t, "toggle", (u) => (u.style.display = "none")),
                  t.dispatchEvent(new Event("phx:hide-end")));
              })
            : window.requestAnimationFrame(() => {
                t.dispatchEvent(new Event("phx:show-start"));
                let u = i || this.defaultDisplay(t);
                (c.putSticky(t, "toggle", (v) => (v.style.display = u)),
                  t.dispatchEvent(new Event("phx:show-end")));
              });
      },
      toggleClasses(s, e, t, i, n, r) {
        window.requestAnimationFrame(() => {
          let [o, a] = c.getSticky(s, "classes", [[], []]),
            l = e.filter((d) => o.indexOf(d) < 0 && !s.classList.contains(d)),
            h = e.filter((d) => a.indexOf(d) < 0 && s.classList.contains(d));
          this.addOrRemoveClasses(s, l, h, t, i, n, r);
        });
      },
      toggleAttr(s, e, t, i) {
        s.hasAttribute(e)
          ? i !== void 0
            ? s.getAttribute(e) === t
              ? this.setOrRemoveAttrs(s, [[e, i]], [])
              : this.setOrRemoveAttrs(s, [[e, t]], [])
            : this.setOrRemoveAttrs(s, [], [e])
          : this.setOrRemoveAttrs(s, [[e, t]], []);
      },
      addOrRemoveClasses(s, e, t, i, n, r, o) {
        n = n || Hi;
        let [a, l, h] = i || [[], [], []];
        if (a.length > 0) {
          let d = () => {
              (this.addOrRemoveClasses(s, l, [].concat(a).concat(h)),
                window.requestAnimationFrame(() => {
                  (this.addOrRemoveClasses(s, a, []),
                    window.requestAnimationFrame(() =>
                      this.addOrRemoveClasses(s, h, l),
                    ));
                }));
            },
            p = () =>
              this.addOrRemoveClasses(s, e.concat(h), t.concat(a).concat(l));
          o === !1 ? (d(), setTimeout(p, n)) : r.transition(n, d, p);
          return;
        }
        window.requestAnimationFrame(() => {
          let [d, p] = c.getSticky(s, "classes", [[], []]),
            m = e.filter((E) => d.indexOf(E) < 0 && !s.classList.contains(E)),
            g = t.filter((E) => p.indexOf(E) < 0 && s.classList.contains(E)),
            u = d.filter((E) => t.indexOf(E) < 0).concat(m),
            v = p.filter((E) => e.indexOf(E) < 0).concat(g);
          c.putSticky(
            s,
            "classes",
            (E) => (E.classList.remove(...v), E.classList.add(...u), [u, v]),
          );
        });
      },
      setOrRemoveAttrs(s, e, t) {
        let [i, n] = c.getSticky(s, "attrs", [[], []]),
          r = e.map(([l, h]) => l).concat(t),
          o = i.filter(([l, h]) => !r.includes(l)).concat(e),
          a = n.filter((l) => !r.includes(l)).concat(t);
        c.putSticky(
          s,
          "attrs",
          (l) => (
            a.forEach((h) => l.removeAttribute(h)),
            o.forEach(([h, d]) => l.setAttribute(h, d)),
            [o, a]
          ),
        );
      },
      hasAllClasses(s, e) {
        return e.every((t) => s.classList.contains(t));
      },
      isToggledOut(s, e) {
        return !this.isVisible(s) || this.hasAllClasses(s, e);
      },
      filterToEls(s, e, { to: t }) {
        let i = () => {
          if (typeof t == "string") return document.querySelectorAll(t);
          if (t.closest) {
            let n = e.closest(t.closest);
            return n ? [n] : [];
          } else if (t.inner) return e.querySelectorAll(t.inner);
        };
        return t ? s.jsQuerySelectorAll(e, t, i) : [e];
      },
      defaultDisplay(s) {
        return (
          { tr: "table-row", td: "table-cell" }[s.tagName.toLowerCase()] ||
          "block"
        );
      },
      transitionClasses(s) {
        if (!s) return null;
        let [e, t, i] = Array.isArray(s) ? s : [s.split(" "), [], []];
        return (
          (e = Array.isArray(e) ? e : e.split(" ")),
          (t = Array.isArray(t) ? t : t.split(" ")),
          (i = Array.isArray(i) ? i : i.split(" ")),
          [e, t, i]
        );
      },
    },
    S = fn;
  var St = (s, e) => ({
    exec(t, i) {
      s.execJS(t, i, e);
    },
    show(t, i = {}) {
      let n = s.owner(t);
      S.show(
        e,
        n,
        t,
        i.display,
        S.transitionClasses(i.transition),
        i.time,
        i.blocking,
      );
    },
    hide(t, i = {}) {
      let n = s.owner(t);
      S.hide(
        e,
        n,
        t,
        null,
        S.transitionClasses(i.transition),
        i.time,
        i.blocking,
      );
    },
    toggle(t, i = {}) {
      let n = s.owner(t),
        r = S.transitionClasses(i.in),
        o = S.transitionClasses(i.out);
      S.toggle(e, n, t, i.display, r, o, i.time, i.blocking);
    },
    addClass(t, i, n = {}) {
      let r = Array.isArray(i) ? i : i.split(" "),
        o = s.owner(t);
      S.addOrRemoveClasses(
        t,
        r,
        [],
        S.transitionClasses(n.transition),
        n.time,
        o,
        n.blocking,
      );
    },
    removeClass(t, i, n = {}) {
      let r = Array.isArray(i) ? i : i.split(" "),
        o = s.owner(t);
      S.addOrRemoveClasses(
        t,
        [],
        r,
        S.transitionClasses(n.transition),
        n.time,
        o,
        n.blocking,
      );
    },
    toggleClass(t, i, n = {}) {
      let r = Array.isArray(i) ? i : i.split(" "),
        o = s.owner(t);
      S.toggleClasses(
        t,
        r,
        S.transitionClasses(n.transition),
        n.time,
        o,
        n.blocking,
      );
    },
    transition(t, i, n = {}) {
      let r = s.owner(t);
      S.addOrRemoveClasses(
        t,
        [],
        [],
        S.transitionClasses(i),
        n.time,
        r,
        n.blocking,
      );
    },
    setAttribute(t, i, n) {
      S.setOrRemoveAttrs(t, [[i, n]], []);
    },
    removeAttribute(t, i) {
      S.setOrRemoveAttrs(t, [], [i]);
    },
    toggleAttribute(t, i, n, r) {
      S.toggleAttr(t, i, n, r);
    },
    push(t, i, n = {}) {
      s.withinOwners(t, (r) => {
        let o = n.value || {};
        delete n.value;
        let a = new CustomEvent("phx:exec", { detail: { sourceElement: t } });
        S.exec(a, e, i, r, t, ["push", L({ data: o }, n)]);
      });
    },
    navigate(t, i = {}) {
      let n = new CustomEvent("phx:exec");
      s.historyRedirect(n, t, i.replace ? "replace" : "push", null, null);
    },
    patch(t, i = {}) {
      let n = new CustomEvent("phx:exec");
      s.pushHistoryPatch(n, t, i.replace ? "replace" : "push", null);
    },
    ignoreAttributes(t, i) {
      S.ignoreAttrs(t, Array.isArray(i) ? i : [i]);
    },
  });
  var Wt = "hookId",
    Di = "deadHook",
    pn = 1,
    Q = class s {
      get liveSocket() {
        return this.__liveSocket();
      }
      static makeID() {
        return pn++;
      }
      static elementID(e) {
        return c.private(e, Wt);
      }
      static deadHook(e) {
        return c.private(e, Di) === !0;
      }
      constructor(e, t, i) {
        if (
          ((this.el = t),
          this.__attachView(e),
          (this.__listeners = new Set()),
          (this.__isDisconnected = !1),
          c.putPrivate(this.el, Wt, s.makeID()),
          e && e.isDead && c.putPrivate(this.el, Di, !0),
          i)
        ) {
          let n = new Set([
            "el",
            "liveSocket",
            "__view",
            "__listeners",
            "__isDisconnected",
            "constructor",
            "js",
            "pushEvent",
            "pushEventTo",
            "handleEvent",
            "removeHandleEvent",
            "upload",
            "uploadTo",
            "__mounted",
            "__updated",
            "__beforeUpdate",
            "__destroyed",
            "__reconnected",
            "__disconnected",
            "__cleanup__",
          ]);
          for (let o in i)
            Object.prototype.hasOwnProperty.call(i, o) &&
              ((this[o] = i[o]),
              n.has(o) &&
                console.warn(
                  `Hook object for element #${t.id} overwrites core property '${o}'!`,
                ));
          [
            "mounted",
            "beforeUpdate",
            "updated",
            "destroyed",
            "disconnected",
            "reconnected",
          ].forEach((o) => {
            i[o] && typeof i[o] == "function" && (this[o] = i[o]);
          });
        }
      }
      __attachView(e) {
        e
          ? ((this.__view = () => e), (this.__liveSocket = () => e.liveSocket))
          : ((this.__view = () => {
              throw new Error(
                `hook not yet attached to a live view: ${this.el.outerHTML}`,
              );
            }),
            (this.__liveSocket = () => {
              throw new Error(
                `hook not yet attached to a live view: ${this.el.outerHTML}`,
              );
            }));
      }
      mounted() {}
      beforeUpdate() {}
      updated() {}
      destroyed() {}
      disconnected() {}
      reconnected() {}
      __mounted() {
        this.mounted();
      }
      __updated() {
        this.updated();
      }
      __beforeUpdate() {
        this.beforeUpdate();
      }
      __destroyed() {
        (this.destroyed(), c.deletePrivate(this.el, Wt));
      }
      __reconnected() {
        this.__isDisconnected &&
          ((this.__isDisconnected = !1), this.reconnected());
      }
      __disconnected() {
        ((this.__isDisconnected = !0), this.disconnected());
      }
      js() {
        return le(L({}, St(this.__view().liveSocket, "hook")), {
          exec: (e) => {
            this.__view().liveSocket.execJS(this.el, e, "hook");
          },
        });
      }
      pushEvent(e, t, i) {
        let n = this.__view().pushHookEvent(this.el, null, e, t || {});
        if (i === void 0) return n.then(({ reply: r }) => r);
        n.then(({ reply: r, ref: o }) => i(r, o)).catch(() => {});
      }
      pushEventTo(e, t, i, n) {
        if (n === void 0) {
          let r = [];
          this.__view().withinTargets(e, (a, l) => {
            r.push({ view: a, targetCtx: l });
          });
          let o = r.map(({ view: a, targetCtx: l }) =>
            a.pushHookEvent(this.el, l, t, i || {}),
          );
          return Promise.allSettled(o);
        }
        this.__view().withinTargets(e, (r, o) => {
          r.pushHookEvent(this.el, o, t, i || {})
            .then(({ reply: a, ref: l }) => n(a, l))
            .catch(() => {});
        });
      }
      handleEvent(e, t) {
        let i = { event: e, callback: (n) => t(n.detail) };
        return (
          window.addEventListener(`phx:${e}`, i.callback),
          this.__listeners.add(i),
          i
        );
      }
      removeHandleEvent(e) {
        (window.removeEventListener(`phx:${e.event}`, e.callback),
          this.__listeners.delete(e));
      }
      upload(e, t) {
        return this.__view().dispatchUploads(null, e, t);
      }
      uploadTo(e, t, i) {
        return this.__view().withinTargets(e, (n, r) => {
          n.dispatchUploads(r, t, i);
        });
      }
      __cleanup__() {
        this.__listeners.forEach((e) => this.removeHandleEvent(e));
      }
    };
  var mn = (s, e) => {
      let t = s.endsWith("[]"),
        i = t ? s.slice(0, -2) : s;
      return (
        (i = i.replace(/([^\[\]]+)(\]?$)/, `${e}$1$2`)),
        t && (i += "[]"),
        i
      );
    },
    wt = (s, e, t = []) => {
      let { submitter: i } = e,
        n;
      if (i && i.name) {
        let d = document.createElement("input");
        d.type = "hidden";
        let p = i.getAttribute("form");
        (p && d.setAttribute("form", p),
          (d.name = i.name),
          (d.value = i.value),
          i.parentElement.insertBefore(d, i),
          (n = d));
      }
      let r = new FormData(s),
        o = [];
      (r.forEach((d, p, m) => {
        d instanceof File && o.push(p);
      }),
        o.forEach((d) => r.delete(d)));
      let a = new URLSearchParams(),
        { inputsUnused: l, onlyHiddenInputs: h } = Array.from(
          s.elements,
        ).reduce(
          (d, p) => {
            let { inputsUnused: m, onlyHiddenInputs: g } = d,
              u = p.name;
            if (!u) return d;
            (m[u] === void 0 && (m[u] = !0), g[u] === void 0 && (g[u] = !0));
            let v = c.private(p, we) || c.private(p, Pe),
              E = p.type === "hidden";
            return ((m[u] = m[u] && !v), (g[u] = g[u] && E), d);
          },
          { inputsUnused: {}, onlyHiddenInputs: {} },
        );
      for (let [d, p] of r.entries())
        if (t.length === 0 || t.indexOf(d) >= 0) {
          let m = l[d],
            g = h[d];
          (m && !(i && i.name == d) && !g && a.append(mn(d, "_unused_"), ""),
            typeof p == "string" && a.append(d, p));
        }
      return (i && n && i.parentElement.removeChild(n), a.toString());
    },
    Re = class s {
      static closestView(e) {
        let t = e.closest(he);
        return t ? c.private(t, "view") : null;
      }
      constructor(e, t, i, n, r) {
        ((this.isDead = !1),
          (this.liveSocket = t),
          (this.flash = n),
          (this.parent = i),
          (this.root = i ? i.root : this),
          (this.el = e));
        let o = c.private(this.el, "view");
        if (o !== void 0 && o.isDead !== !0)
          throw (
            w(
              `The DOM element for this view has already been bound to a view.

        An element can only ever be associated with a single view!
        Please ensure that you are not trying to initialize multiple LiveSockets on the same page.
        This could happen if you're accidentally trying to render your root layout more than once.
        Ensure that the template set on the LiveView is different than the root layout.
      `,
              { view: o },
            ),
            new Error("Cannot bind multiple views to the same DOM element.")
          );
        (c.putPrivate(this.el, "view", this),
          (this.id = this.el.id),
          this.el.setAttribute(z, this.root.id),
          (this.ref = 0),
          (this.lastAckRef = null),
          (this.childJoins = 0),
          (this.loaderTimer = null),
          (this.disconnectedTimer = null),
          (this.pendingDiffs = []),
          (this.pendingForms = new Set()),
          (this.redirect = !1),
          (this.href = null),
          (this.joinCount = this.parent ? this.parent.joinCount - 1 : 0),
          (this.joinAttempts = 0),
          (this.joinPending = !0),
          (this.destroyed = !1),
          (this.joinCallback = function (a) {
            a && a();
          }),
          (this.stopCallback = function () {}),
          (this.pendingJoinOps = []),
          (this.viewHooks = {}),
          (this.formSubmits = []),
          (this.children = this.parent ? null : {}),
          (this.root.children[this.id] = {}),
          (this.formsForRecovery = {}),
          (this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
            let a = this.href && this.expandURL(this.href);
            return {
              redirect: this.redirect ? a : void 0,
              url: this.redirect ? void 0 : a || void 0,
              params: this.connectParams(r),
              session: this.getSession(),
              static: this.getStatic(),
              flash: this.flash,
              sticky: this.el.hasAttribute(Qe),
            };
          })),
          (this.portalElementIds = new Set()));
      }
      setHref(e) {
        this.href = e;
      }
      setRedirect(e) {
        ((this.redirect = !0), (this.href = e));
      }
      isMain() {
        return this.el.hasAttribute(De);
      }
      connectParams(e) {
        let t = this.liveSocket.params(this.el),
          i = c
            .all(document, `[${this.binding(Zt)}]`)
            .map((n) => n.src || n.href)
            .filter((n) => typeof n == "string");
        return (
          i.length > 0 && (t._track_static = i),
          (t._mounts = this.joinCount),
          (t._mount_attempts = this.joinAttempts),
          (t._live_referer = e),
          this.joinAttempts++,
          t
        );
      }
      isConnected() {
        return this.channel.canPush();
      }
      getSession() {
        return this.el.getAttribute(q);
      }
      getStatic() {
        let e = this.el.getAttribute(re);
        return e === "" ? null : e;
      }
      destroy(e = function () {}) {
        (this.destroyAllChildren(),
          this.destroyPortalElements(),
          (this.destroyed = !0),
          c.deletePrivate(this.el, "view"),
          delete this.root.children[this.id],
          this.parent && delete this.root.children[this.parent.id][this.id],
          clearTimeout(this.loaderTimer));
        let t = () => {
          e();
          for (let i in this.viewHooks) this.destroyHook(this.viewHooks[i]);
        };
        (c.markPhxChildDestroyed(this.el),
          this.log("destroyed", () => [
            "the child has been removed from the parent",
          ]),
          this.channel
            .leave()
            .receive("ok", t)
            .receive("error", t)
            .receive("timeout", t));
      }
      setContainerClasses(...e) {
        (this.el.classList.remove(xt, be, Se, It, He),
          this.el.classList.add(...e));
      }
      showLoader(e) {
        if ((clearTimeout(this.loaderTimer), e))
          this.loaderTimer = setTimeout(() => this.showLoader(), e);
        else {
          for (let t in this.viewHooks) this.viewHooks[t].__disconnected();
          this.setContainerClasses(be);
        }
      }
      execAll(e) {
        c.all(this.el, `[${e}]`, (t) =>
          this.liveSocket.execJS(t, t.getAttribute(e)),
        );
      }
      hideLoader() {
        (clearTimeout(this.loaderTimer),
          clearTimeout(this.disconnectedTimer),
          this.setContainerClasses(xt),
          this.execAll(this.binding("connected")));
      }
      triggerReconnected() {
        for (let e in this.viewHooks) this.viewHooks[e].__reconnected();
      }
      log(e, t) {
        this.liveSocket.log(this, e, t);
      }
      transition(e, t, i = function () {}) {
        this.liveSocket.transition(e, t, i);
      }
      withinTargets(e, t, i = document) {
        if (e instanceof HTMLElement || e instanceof SVGElement)
          return this.liveSocket.owner(e, (n) => t(n, e));
        if (ee(e))
          c.findComponentNodeList(this.id, e, i).length === 0
            ? w(`no component found matching phx-target of ${e}`)
            : t(this, parseInt(e));
        else {
          let n = Array.from(i.querySelectorAll(e));
          (n.length === 0 &&
            w(`nothing found matching the phx-target selector "${e}"`),
            n.forEach((r) => this.liveSocket.owner(r, (o) => t(o, r))));
        }
      }
      applyDiff(e, t, i) {
        this.log(e, () => ["", We(t)]);
        let { diff: n, reply: r, events: o, title: a } = Ke.extract(t),
          l = o.reduce(
            (d, p) => (
              p.length === 3 && p[2] == !0
                ? d.pre.push(p.slice(0, -1))
                : d.post.push(p),
              d
            ),
            { pre: [], post: [] },
          );
        this.liveSocket.dispatchEvents(l.pre);
        let h = () => {
          (i({ diff: n, reply: r, events: l.post }),
            (typeof a == "string" || (e == "mount" && this.isMain())) &&
              window.requestAnimationFrame(() => c.putTitle(a)));
        };
        "onDocumentPatch" in this.liveSocket.domCallbacks
          ? this.liveSocket.triggerDOM("onDocumentPatch", [h])
          : h();
      }
      onJoin(e) {
        let { rendered: t, container: i, liveview_version: n, pid: r } = e;
        if (i) {
          let [o, a] = i;
          this.el = c.replaceRootContainer(this.el, o, a);
        }
        ((this.childJoins = 0),
          (this.joinPending = !0),
          (this.flash = null),
          this.root === this &&
            (this.formsForRecovery = this.getFormsForRecovery()),
          this.isMain() &&
            window.history.state === null &&
            $.pushState("replace", {
              type: "patch",
              id: this.id,
              position: this.liveSocket.currentHistoryPosition,
            }),
          n !== this.liveSocket.version() &&
            console.warn(
              `LiveView asset version mismatch. JavaScript version ${this.liveSocket.version()} vs. server ${n}. To avoid issues, please ensure that your assets use the same version as the server.`,
            ),
          r && this.el.setAttribute(ai, r),
          $.dropLocal(
            this.liveSocket.localStorage,
            window.location.pathname,
            ht,
          ),
          this.applyDiff("mount", t, ({ diff: o, events: a }) => {
            this.rendered = new Ke(this.id, o);
            let [l, h] = this.renderContainer(null, "join");
            (this.dropPendingRefs(),
              this.joinCount++,
              (this.joinAttempts = 0),
              this.maybeRecoverForms(l, () => {
                this.onJoinComplete(e, l, h, a);
              }));
          }));
      }
      dropPendingRefs() {
        c.all(document, `[${N}="${this.refSrc()}"]`, (e) => {
          (e.removeAttribute(ve), e.removeAttribute(N), e.removeAttribute(C));
        });
      }
      onJoinComplete({ live_patch: e }, t, i, n) {
        if (this.joinCount > 1 || (this.parent && !this.parent.isJoinPending()))
          return this.applyJoinPatch(e, t, i, n);
        c.findPhxChildrenInFragment(t, this.id).filter((o) => {
          let a = o.id && this.el.querySelector(`[id="${o.id}"]`),
            l = a && a.getAttribute(re);
          return (
            l && o.setAttribute(re, l),
            a && a.setAttribute(z, this.root.id),
            this.joinChild(o)
          );
        }).length === 0
          ? this.parent
            ? (this.root.pendingJoinOps.push([
                this,
                () => this.applyJoinPatch(e, t, i, n),
              ]),
              this.parent.ackJoin(this))
            : (this.onAllChildJoinsComplete(), this.applyJoinPatch(e, t, i, n))
          : this.root.pendingJoinOps.push([
              this,
              () => this.applyJoinPatch(e, t, i, n),
            ]);
      }
      attachTrueDocEl() {
        ((this.el = c.byId(this.id)), this.el.setAttribute(z, this.root.id));
      }
      execNewMounted(e = document) {
        let t = this.binding(ze),
          i = this.binding(Ye);
        (this.all(e, `[${t}], [${i}]`, (n) => {
          (c.maintainPrivateHooks(n, n, t, i), this.maybeAddNewHook(n));
        }),
          this.all(e, `[${this.binding(Ne)}], [data-phx-${Ne}]`, (n) => {
            this.maybeAddNewHook(n);
          }),
          this.all(e, `[${this.binding(Ht)}]`, (n) => {
            this.maybeMounted(n);
          }));
      }
      all(e, t, i) {
        c.all(e, t, (n) => {
          this.ownsElement(n) && i(n);
        });
      }
      applyJoinPatch(e, t, i, n) {
        (this.joinCount > 1 &&
          this.pendingJoinOps.length &&
          (this.pendingJoinOps.forEach((o) => typeof o == "function" && o()),
          (this.pendingJoinOps = [])),
          this.attachTrueDocEl());
        let r = new _e(this, this.el, this.id, t, i, null);
        if (
          (r.markPrunableContentForRemoval(),
          this.performPatch(r, !1, !0),
          this.joinNewChildren(),
          this.execNewMounted(),
          (this.joinPending = !1),
          this.liveSocket.dispatchEvents(n),
          this.applyPendingUpdates(),
          e)
        ) {
          let { kind: o, to: a } = e;
          this.liveSocket.historyPatch(a, o);
        }
        (this.hideLoader(),
          this.joinCount > 1 && this.triggerReconnected(),
          this.stopCallback());
      }
      triggerBeforeUpdateHook(e, t) {
        this.liveSocket.triggerDOM("onBeforeElUpdated", [e, t]);
        let i = this.getHook(e),
          n = i && c.isIgnored(e, this.binding(Fe));
        if (i && !e.isEqualNode(t) && !(n && Ei(e.dataset, t.dataset)))
          return (i.__beforeUpdate(), i);
      }
      maybeMounted(e) {
        let t = e.getAttribute(this.binding(Ht)),
          i = t && c.private(e, "mounted");
        t &&
          !i &&
          (this.liveSocket.execJS(e, t), c.putPrivate(e, "mounted", !0));
      }
      maybeAddNewHook(e) {
        let t = this.addHook(e);
        t && t.__mounted();
      }
      performPatch(e, t, i = !1) {
        let n = [],
          r = !1,
          o = new Set();
        return (
          this.liveSocket.triggerDOM("onPatchStart", [e.targetContainer]),
          e.after("added", (a) => {
            this.liveSocket.triggerDOM("onNodeAdded", [a]);
            let l = this.binding(ze),
              h = this.binding(Ye);
            (c.maintainPrivateHooks(a, a, l, h),
              this.maybeAddNewHook(a),
              a.getAttribute && this.maybeMounted(a));
          }),
          e.after("phxChildAdded", (a) => {
            c.isPhxSticky(a) ? this.liveSocket.joinRootViews() : (r = !0);
          }),
          e.before("updated", (a, l) => {
            (this.triggerBeforeUpdateHook(a, l) && o.add(a.id),
              S.onBeforeElUpdated(a, l));
          }),
          e.after("updated", (a) => {
            o.has(a.id) && this.getHook(a).__updated();
          }),
          e.after("discarded", (a) => {
            a.nodeType === Node.ELEMENT_NODE && n.push(a);
          }),
          e.after("transitionsDiscarded", (a) =>
            this.afterElementsRemoved(a, t),
          ),
          e.perform(i),
          this.afterElementsRemoved(n, t),
          this.liveSocket.triggerDOM("onPatchEnd", [e.targetContainer]),
          r
        );
      }
      afterElementsRemoved(e, t) {
        let i = [];
        (e.forEach((n) => {
          let r = c.all(n, `[${ce}="${this.id}"][${K}]`),
            o = c.all(n, `[${this.binding(Ne)}], [data-phx-hook]`);
          (r.concat(n).forEach((a) => {
            let l = this.componentID(a);
            ee(l) &&
              i.indexOf(l) === -1 &&
              a.getAttribute(ce) === this.id &&
              i.push(l);
          }),
            o.concat(n).forEach((a) => {
              let l = this.getHook(a);
              l && this.destroyHook(l);
            }));
        }),
          t && this.maybePushComponentsDestroyed(i));
      }
      joinNewChildren() {
        c.findPhxChildren(document, this.id).forEach((e) => this.joinChild(e));
      }
      maybeRecoverForms(e, t) {
        let i = this.binding("change"),
          n = this.root.formsForRecovery,
          r = document.createElement("template");
        ((r.innerHTML = e),
          c.all(r.content, `[${$e}]`).forEach((l) => {
            r.content.firstElementChild.appendChild(
              l.content.firstElementChild,
            );
          }));
        let o = r.content.firstElementChild;
        ((o.id = this.id),
          o.setAttribute(z, this.root.id),
          o.setAttribute(q, this.getSession()),
          o.setAttribute(re, this.getStatic()),
          o.setAttribute(se, this.parent ? this.parent.id : null));
        let a = c
          .all(r.content, "form")
          .filter((l) => l.id && n[l.id])
          .filter((l) => !this.pendingForms.has(l.id))
          .filter((l) => n[l.id].getAttribute(i) === l.getAttribute(i))
          .map((l) => [n[l.id], l]);
        if (a.length === 0) return t();
        a.forEach(([l, h], d) => {
          (this.pendingForms.add(h.id),
            this.pushFormRecovery(l, h, r.content.firstElementChild, () => {
              (this.pendingForms.delete(h.id), d === a.length - 1 && t());
            }));
        });
      }
      getChildById(e) {
        return this.root.children[this.id][e];
      }
      getDescendentByEl(e) {
        var t;
        return e.id === this.id
          ? this
          : (t = this.children[e.getAttribute(se)]) == null
            ? void 0
            : t[e.id];
      }
      destroyDescendent(e) {
        for (let t in this.root.children)
          for (let i in this.root.children[t])
            if (i === e) return this.root.children[t][i].destroy();
      }
      joinChild(e) {
        if (!this.getChildById(e.id)) {
          let i = new s(e, this.liveSocket, this);
          return (
            (this.root.children[this.id][i.id] = i),
            i.join(),
            this.childJoins++,
            !0
          );
        }
      }
      isJoinPending() {
        return this.joinPending;
      }
      ackJoin(e) {
        (this.childJoins--,
          this.childJoins === 0 &&
            (this.parent
              ? this.parent.ackJoin(this)
              : this.onAllChildJoinsComplete()));
      }
      onAllChildJoinsComplete() {
        (this.pendingForms.clear(),
          (this.formsForRecovery = {}),
          this.joinCallback(() => {
            (this.pendingJoinOps.forEach(([e, t]) => {
              e.isDestroyed() || t();
            }),
              (this.pendingJoinOps = []));
          }));
      }
      update(e, t, i = !1) {
        if (
          this.isJoinPending() ||
          (this.liveSocket.hasPendingLink() && this.root.isMain())
        )
          return (i || this.pendingDiffs.push({ diff: e, events: t }), !1);
        this.rendered.mergeDiff(e);
        let n = !1;
        return (
          this.rendered.isComponentOnlyDiff(e)
            ? this.liveSocket.time("component patch complete", () => {
                c.findExistingParentCIDs(
                  this.id,
                  this.rendered.componentCIDs(e),
                ).forEach((o) => {
                  this.componentPatch(this.rendered.getComponent(e, o), o) &&
                    (n = !0);
                });
              })
            : Vt(e) ||
              this.liveSocket.time("full patch complete", () => {
                let [r, o] = this.renderContainer(e, "update"),
                  a = new _e(this, this.el, this.id, r, o, null);
                n = this.performPatch(a, !0);
              }),
          this.liveSocket.dispatchEvents(t),
          n && this.joinNewChildren(),
          !0
        );
      }
      renderContainer(e, t) {
        return this.liveSocket.time(`toString diff (${t})`, () => {
          let i = this.el.tagName,
            n = e ? this.rendered.componentCIDs(e) : null,
            { buffer: r, streams: o } = this.rendered.toString(n);
          return [`<${i}>${r}</${i}>`, o];
        });
      }
      componentPatch(e, t) {
        if (Vt(e)) return !1;
        let { buffer: i, streams: n } = this.rendered.componentToString(t),
          r = new _e(this, this.el, this.id, i, n, t);
        return this.performPatch(r, !0);
      }
      getHook(e) {
        return this.viewHooks[Q.elementID(e)];
      }
      addHook(e) {
        let t = Q.elementID(e);
        if (!(e.getAttribute && !this.ownsElement(e)))
          if (t && !this.viewHooks[t]) {
            if (Q.deadHook(e)) return;
            let i =
              c.getCustomElHook(e) ||
              w(`no hook found for custom element: ${e.id}`);
            return ((this.viewHooks[t] = i), i.__attachView(this), i);
          } else {
            if (t || !e.getAttribute) return;
            {
              let i =
                e.getAttribute(`data-phx-${Ne}`) ||
                e.getAttribute(this.binding(Ne));
              if (!i) return;
              let n = this.liveSocket.getHookDefinition(i);
              if (n) {
                if (!e.id) {
                  w(
                    `no DOM ID for hook "${i}". Hooks require a unique ID on each element.`,
                    e,
                  );
                  return;
                }
                let r;
                try {
                  if (typeof n == "function" && n.prototype instanceof Q)
                    r = new n(this, e);
                  else if (typeof n == "object" && n !== null)
                    r = new Q(this, e, n);
                  else {
                    w(
                      `Invalid hook definition for "${i}". Expected a class extending ViewHook or an object definition.`,
                      e,
                    );
                    return;
                  }
                } catch (o) {
                  let a = o instanceof Error ? o.message : String(o);
                  w(`Failed to create hook "${i}": ${a}`, e);
                  return;
                }
                return ((this.viewHooks[Q.elementID(r.el)] = r), r);
              } else i !== null && w(`unknown hook found for "${i}"`, e);
            }
          }
      }
      destroyHook(e) {
        let t = Q.elementID(e.el);
        (e.__destroyed(), e.__cleanup__(), delete this.viewHooks[t]);
      }
      applyPendingUpdates() {
        ((this.pendingDiffs = this.pendingDiffs.filter(
          ({ diff: e, events: t }) => !this.update(e, t, !0),
        )),
          this.eachChild((e) => e.applyPendingUpdates()));
      }
      eachChild(e) {
        let t = this.root.children[this.id] || {};
        for (let i in t) e(this.getChildById(i));
      }
      onChannel(e, t) {
        this.liveSocket.onChannel(this.channel, e, (i) => {
          this.isJoinPending()
            ? this.joinCount > 1
              ? this.pendingJoinOps.push(() => t(i))
              : this.root.pendingJoinOps.push([this, () => t(i)])
            : this.liveSocket.requestDOMUpdate(() => t(i));
        });
      }
      bindChannel() {
        (this.liveSocket.onChannel(this.channel, "diff", (e) => {
          this.liveSocket.requestDOMUpdate(() => {
            this.applyDiff("update", e, ({ diff: t, events: i }) =>
              this.update(t, i),
            );
          });
        }),
          this.onChannel("redirect", ({ to: e, flash: t }) =>
            this.onRedirect({ to: e, flash: t }),
          ),
          this.onChannel("live_patch", (e) => this.onLivePatch(e)),
          this.onChannel("live_redirect", (e) => this.onLiveRedirect(e)),
          this.channel.onError((e) => this.onError(e)),
          this.channel.onClose((e) => this.onClose(e)));
      }
      destroyAllChildren() {
        this.eachChild((e) => e.destroy());
      }
      onLiveRedirect(e) {
        let { to: t, kind: i, flash: n } = e,
          r = this.expandURL(t),
          o = new CustomEvent("phx:server-navigate", {
            detail: { to: t, kind: i, flash: n },
          });
        this.liveSocket.historyRedirect(o, r, i, n);
      }
      onLivePatch(e) {
        let { to: t, kind: i } = e;
        ((this.href = this.expandURL(t)), this.liveSocket.historyPatch(t, i));
      }
      expandURL(e) {
        return e.startsWith("/")
          ? `${window.location.protocol}//${window.location.host}${e}`
          : e;
      }
      onRedirect({ to: e, flash: t, reloadToken: i }) {
        this.liveSocket.redirect(e, t, i);
      }
      isDestroyed() {
        return this.destroyed;
      }
      joinDead() {
        this.isDead = !0;
      }
      joinPush() {
        return (
          (this.joinPush = this.joinPush || this.channel.join()),
          this.joinPush
        );
      }
      join(e) {
        (this.showLoader(this.liveSocket.loaderTimeout),
          this.bindChannel(),
          this.isMain() &&
            (this.stopCallback = this.liveSocket.withPageLoading({
              to: this.href,
              kind: "initial",
            })),
          (this.joinCallback = (t) => {
            ((t = t || function () {}), e ? e(this.joinCount, t) : t());
          }),
          this.wrapPush(() => this.channel.join(), {
            ok: (t) => this.liveSocket.requestDOMUpdate(() => this.onJoin(t)),
            error: (t) => this.onJoinError(t),
            timeout: () => this.onJoinError({ reason: "timeout" }),
          }));
      }
      onJoinError(e) {
        if (e.reason === "reload") {
          (this.log("error", () => [
            `failed mount with ${e.status}. Falling back to page reload`,
            e,
          ]),
            this.onRedirect({
              to: this.liveSocket.main.href,
              reloadToken: e.token,
            }));
          return;
        } else if (e.reason === "unauthorized" || e.reason === "stale") {
          (this.log("error", () => [
            "unauthorized live_redirect. Falling back to page request",
            e,
          ]),
            this.onRedirect({
              to: this.liveSocket.main.href,
              flash: this.flash,
            }));
          return;
        }
        if (
          ((e.redirect || e.live_redirect) &&
            ((this.joinPending = !1), this.channel.leave()),
          e.redirect)
        )
          return this.onRedirect(e.redirect);
        if (e.live_redirect) return this.onLiveRedirect(e.live_redirect);
        if ((this.log("error", () => ["unable to join", e]), this.isMain()))
          (this.displayError([be, Se, He], {
            unstructuredError: e,
            errorKind: "server",
          }),
            this.liveSocket.isConnected() &&
              this.liveSocket.reloadWithJitter(this));
        else {
          this.joinAttempts >= Mt &&
            (this.root.displayError([be, Se, He], {
              unstructuredError: e,
              errorKind: "server",
            }),
            this.log("error", () => [
              `giving up trying to mount after ${Mt} tries`,
              e,
            ]),
            this.destroy());
          let t = c.byId(this.el.id);
          t
            ? (c.mergeAttrs(t, this.el),
              this.displayError([be, Se, He], {
                unstructuredError: e,
                errorKind: "server",
              }),
              (this.el = t))
            : this.destroy();
        }
      }
      onClose(e) {
        if (!this.isDestroyed()) {
          if (
            this.isMain() &&
            this.liveSocket.hasPendingLink() &&
            e !== "leave"
          )
            return this.liveSocket.reloadWithJitter(this);
          (this.destroyAllChildren(),
            this.liveSocket.dropActiveElement(this),
            this.liveSocket.isUnloaded() && this.showLoader(di));
        }
      }
      onError(e) {
        (this.onClose(e),
          this.liveSocket.isConnected() &&
            this.log("error", () => ["view crashed", e]),
          this.liveSocket.isUnloaded() ||
            (this.liveSocket.isConnected()
              ? this.displayError([be, Se, He], {
                  unstructuredError: e,
                  errorKind: "server",
                })
              : this.displayError([be, Se, It], {
                  unstructuredError: e,
                  errorKind: "client",
                })));
      }
      displayError(e, t = {}) {
        (this.isMain() &&
          c.dispatchEvent(window, "phx:page-loading-start", {
            detail: L({ to: this.href, kind: "error" }, t),
          }),
          this.showLoader(),
          this.setContainerClasses(...e),
          this.delayedDisconnected());
      }
      delayedDisconnected() {
        this.disconnectedTimer = setTimeout(() => {
          this.execAll(this.binding("disconnected"));
        }, this.liveSocket.disconnectedTimeout);
      }
      wrapPush(e, t) {
        let i = this.liveSocket.getLatencySim(),
          n = i
            ? (r) => setTimeout(() => !this.isDestroyed() && r(), i)
            : (r) => !this.isDestroyed() && r();
        n(() => {
          e()
            .receive("ok", (r) => n(() => t.ok && t.ok(r)))
            .receive("error", (r) => n(() => t.error && t.error(r)))
            .receive("timeout", () => n(() => t.timeout && t.timeout()));
        });
      }
      pushWithReply(e, t, i) {
        if (!this.isConnected())
          return Promise.reject(new Error("no connection"));
        let [n, [r], o] = e ? e({ payload: i }) : [null, [], {}],
          a = this.joinCount,
          l = function () {};
        return (
          o.page_loading &&
            (l = this.liveSocket.withPageLoading({
              kind: "element",
              target: r,
            })),
          typeof i.cid != "number" && delete i.cid,
          new Promise((h, d) => {
            this.wrapPush(() => this.channel.push(t, i, pi), {
              ok: (p) => {
                n !== null && (this.lastAckRef = n);
                let m = (g) => {
                  (p.redirect && this.onRedirect(p.redirect),
                    p.live_patch && this.onLivePatch(p.live_patch),
                    p.live_redirect && this.onLiveRedirect(p.live_redirect),
                    l(),
                    h({ resp: p, reply: g, ref: n }));
                };
                p.diff
                  ? this.liveSocket.requestDOMUpdate(() => {
                      this.applyDiff(
                        "update",
                        p.diff,
                        ({ diff: g, reply: u, events: v }) => {
                          (n !== null && this.undoRefs(n, i.event),
                            this.update(g, v),
                            m(u));
                        },
                      );
                    })
                  : (n !== null && this.undoRefs(n, i.event), m(null));
              },
              error: (p) =>
                d(new Error(`failed with reason: ${JSON.stringify(p)}`)),
              timeout: () => {
                (d(new Error("timeout")),
                  this.joinCount === a &&
                    this.liveSocket.reloadWithJitter(this, () => {
                      this.log("timeout", () => [
                        "received timeout while communicating with server. Falling back to hard refresh for recovery",
                      ]);
                    }));
              },
            });
          })
        );
      }
      undoRefs(e, t, i) {
        if (!this.isConnected()) return;
        let n = `[${N}="${this.refSrc()}"]`;
        i
          ? ((i = new Set(i)),
            c.all(document, n, (r) => {
              (i && !i.has(r)) ||
                (c.all(r, n, (o) => this.undoElRef(o, e, t)),
                this.undoElRef(r, e, t));
            }))
          : c.all(document, n, (r) => this.undoElRef(r, e, t));
      }
      undoElRef(e, t, i) {
        new ye(e).maybeUndo(t, i, (r) => {
          let o = new _e(this, e, this.id, r, [], null, { undoRef: t }),
            a = this.performPatch(o, !0);
          (c.all(e, `[${N}="${this.refSrc()}"]`, (l) =>
            this.undoElRef(l, t, i),
          ),
            a && this.joinNewChildren());
        });
      }
      refSrc() {
        return this.el.id;
      }
      putRef(e, t, i, n = {}) {
        let r = this.ref++,
          o = this.binding(Ot);
        if (n.loading) {
          let a = c
            .all(document, n.loading)
            .map((l) => ({ el: l, lock: !0, loading: !0 }));
          e = e.concat(a);
        }
        for (let { el: a, lock: l, loading: h } of e) {
          if (!l && !h) throw new Error("putRef requires lock or loading");
          if (
            (a.setAttribute(N, this.refSrc()),
            h && a.setAttribute(ve, r),
            l && a.setAttribute(C, r),
            !h || (n.submitter && !(a === n.submitter || a === n.form)))
          )
            continue;
          let d = new Promise((u) => {
              a.addEventListener(`phx:undo-lock:${r}`, () => u(g), {
                once: !0,
              });
            }),
            p = new Promise((u) => {
              a.addEventListener(`phx:undo-loading:${r}`, () => u(g), {
                once: !0,
              });
            });
          a.classList.add(`phx-${i}-loading`);
          let m = a.getAttribute(o);
          m !== null &&
            (a.getAttribute(Me) || a.setAttribute(Me, a.textContent),
            m !== "" && (a.textContent = m),
            a.setAttribute(Ee, a.getAttribute(Ee) || a.disabled),
            a.setAttribute("disabled", ""));
          let g = {
            event: t,
            eventType: i,
            ref: r,
            isLoading: h,
            isLocked: l,
            lockElements: e.filter(({ lock: u }) => u).map(({ el: u }) => u),
            loadingElements: e
              .filter(({ loading: u }) => u)
              .map(({ el: u }) => u),
            unlock: (u) => {
              ((u = Array.isArray(u) ? u : [u]), this.undoRefs(r, t, u));
            },
            lockComplete: d,
            loadingComplete: p,
            lock: (u) =>
              new Promise((v) => {
                if (this.isAcked(r)) return v(g);
                (u.setAttribute(C, r),
                  u.setAttribute(N, this.refSrc()),
                  u.addEventListener(`phx:lock-stop:${r}`, () => v(g), {
                    once: !0,
                  }));
              }),
          };
          (n.payload && (g.payload = n.payload),
            n.target && (g.target = n.target),
            n.originalEvent && (g.originalEvent = n.originalEvent),
            a.dispatchEvent(
              new CustomEvent("phx:push", {
                detail: g,
                bubbles: !0,
                cancelable: !1,
              }),
            ),
            t &&
              a.dispatchEvent(
                new CustomEvent(`phx:push:${t}`, {
                  detail: g,
                  bubbles: !0,
                  cancelable: !1,
                }),
              ));
        }
        return [r, e.map(({ el: a }) => a), n];
      }
      isAcked(e) {
        return this.lastAckRef !== null && this.lastAckRef >= e;
      }
      componentID(e) {
        let t = e.getAttribute && e.getAttribute(K);
        return t ? parseInt(t) : null;
      }
      targetComponentID(e, t, i = {}) {
        if (ee(t)) return t;
        let n = i.target || e.getAttribute(this.binding("target"));
        return ee(n)
          ? parseInt(n)
          : t && (n !== null || i.target)
            ? this.closestComponentID(t)
            : null;
      }
      closestComponentID(e) {
        return ee(e)
          ? e
          : e
            ? fe(e.closest(`[${K}],[${te}]`), (t) => {
                if (t.hasAttribute(K))
                  return this.ownsElement(t) && this.componentID(t);
                if (t.hasAttribute(te)) {
                  let i = c.byId(t.getAttribute(te));
                  return this.closestComponentID(i);
                }
              })
            : null;
      }
      pushHookEvent(e, t, i, n) {
        if (!this.isConnected())
          return (
            this.log("hook", () => [
              "unable to push hook event. LiveView not connected",
              i,
              n,
            ]),
            Promise.reject(
              new Error("unable to push hook event. LiveView not connected"),
            )
          );
        let r = () =>
          this.putRef([{ el: e, loading: !0, lock: !0 }], i, "hook", {
            payload: n,
            target: t,
          });
        return this.pushWithReply(r, "event", {
          type: "hook",
          event: i,
          value: n,
          cid: this.closestComponentID(t),
        }).then(({ resp: o, reply: a, ref: l }) => ({ reply: a, ref: l }));
      }
      extractMeta(e, t, i) {
        let n = this.binding("value-");
        for (let r = 0; r < e.attributes.length; r++) {
          t || (t = {});
          let o = e.attributes[r].name;
          o.startsWith(n) && (t[o.replace(n, "")] = e.getAttribute(o));
        }
        if (
          (e.value !== void 0 &&
            !(e instanceof HTMLFormElement) &&
            (t || (t = {}),
            (t.value = e.value),
            e.tagName === "INPUT" &&
              vt.indexOf(e.type) >= 0 &&
              !e.checked &&
              delete t.value),
          i)
        ) {
          t || (t = {});
          for (let r in i) t[r] = i[r];
        }
        return t;
      }
      pushEvent(e, t, i, n, r, o = {}, a) {
        this.pushWithReply(
          (l) =>
            this.putRef(
              [{ el: t, loading: !0, lock: !0 }],
              n,
              e,
              le(L({}, o), { payload: l == null ? void 0 : l.payload }),
            ),
          "event",
          {
            type: e,
            event: n,
            value: this.extractMeta(t, r, o.value),
            cid: this.targetComponentID(t, i, o),
          },
        )
          .then(({ reply: l }) => a && a(l))
          .catch((l) => w("Failed to push event", l));
      }
      pushFileProgress(e, t, i, n = function () {}) {
        this.liveSocket.withinOwners(e.form, (r, o) => {
          r.pushWithReply(null, "progress", {
            event: e.getAttribute(r.binding(ci)),
            ref: e.getAttribute(G),
            entry_ref: t,
            progress: i,
            cid: r.targetComponentID(e.form, o),
          })
            .then(() => n())
            .catch((a) => w("Failed to push file progress", a));
        });
      }
      pushInput(e, t, i, n, r, o) {
        if (!e.form)
          throw new Error("form events require the input to be inside a form");
        let a,
          l = ee(i) ? i : this.targetComponentID(e.form, t, r),
          h = (u) =>
            this.putRef(
              [
                { el: e, loading: !0, lock: !0 },
                { el: e.form, loading: !0, lock: !0 },
              ],
              n,
              "change",
              le(L({}, r), { payload: u == null ? void 0 : u.payload }),
            ),
          d,
          p = this.extractMeta(e.form, {}, r.value),
          m = {};
        (e instanceof HTMLButtonElement && (m.submitter = e),
          e.getAttribute(this.binding("change"))
            ? (d = wt(e.form, m, [e.name]))
            : (d = wt(e.form, m)),
          c.isUploadInput(e) &&
            e.files &&
            e.files.length > 0 &&
            R.trackFiles(e, Array.from(e.files)),
          (a = R.serializeUploads(e)));
        let g = {
          type: "form",
          event: n,
          value: d,
          meta: L({ _target: r._target || "undefined" }, p),
          uploads: a,
          cid: l,
        };
        this.pushWithReply(h, "event", g)
          .then(({ resp: u }) => {
            c.isUploadInput(e) && c.isAutoUpload(e)
              ? ye.onUnlock(e, () => {
                  if (R.filesAwaitingPreflight(e).length > 0) {
                    let [v, E] = h();
                    (this.undoRefs(v, n, [e.form]),
                      this.uploadFiles(e.form, n, t, v, l, (M) => {
                        (o && o(u),
                          this.triggerAwaitingSubmit(e.form, n),
                          this.undoRefs(v, n));
                      }));
                  }
                })
              : o && o(u);
          })
          .catch((u) => w("Failed to push input event", u));
      }
      triggerAwaitingSubmit(e, t) {
        let i = this.getScheduledSubmit(e);
        if (i) {
          let [n, r, o, a] = i;
          (this.cancelSubmit(e, t), a());
        }
      }
      getScheduledSubmit(e) {
        return this.formSubmits.find(([t, i, n, r]) => t.isSameNode(e));
      }
      scheduleSubmit(e, t, i, n) {
        if (this.getScheduledSubmit(e)) return !0;
        this.formSubmits.push([e, t, i, n]);
      }
      cancelSubmit(e, t) {
        this.formSubmits = this.formSubmits.filter(([i, n, r, o]) =>
          i.isSameNode(e) ? (this.undoRefs(n, t), !1) : !0,
        );
      }
      disableForm(e, t, i = {}) {
        let n = (u) =>
            !(
              ue(u, `${this.binding(Fe)}=ignore`, u.form) ||
              ue(u, "data-phx-update=ignore", u.form)
            ),
          r = (u) => u.hasAttribute(this.binding(Ot)),
          o = (u) => u.tagName == "BUTTON",
          a = (u) => ["INPUT", "TEXTAREA", "SELECT"].includes(u.tagName),
          l = Array.from(e.elements),
          h = l.filter(r),
          d = l.filter(o).filter(n),
          p = l.filter(a).filter(n);
        (d.forEach((u) => {
          (u.setAttribute(Ee, u.disabled), (u.disabled = !0));
        }),
          p.forEach((u) => {
            (u.setAttribute(Ze, u.readOnly),
              (u.readOnly = !0),
              u.files && (u.setAttribute(Ee, u.disabled), (u.disabled = !0)));
          }));
        let m = h
            .concat(d)
            .concat(p)
            .map((u) => ({ el: u, loading: !0, lock: !0 })),
          g = [{ el: e, loading: !0, lock: !1 }].concat(m).reverse();
        return this.putRef(g, t, "submit", i);
      }
      pushFormSubmit(e, t, i, n, r, o) {
        let a = (h) =>
          this.disableForm(
            e,
            i,
            le(L({}, r), {
              form: e,
              payload: h == null ? void 0 : h.payload,
              submitter: n,
            }),
          );
        c.putPrivate(e, "submitter", n);
        let l = this.targetComponentID(e, t);
        if (R.hasUploadsInProgress(e)) {
          let [h, d] = a(),
            p = () => this.pushFormSubmit(e, t, i, n, r, o);
          return this.scheduleSubmit(e, h, r, p);
        } else if (R.inputsAwaitingPreflight(e).length > 0) {
          let [h, d] = a(),
            p = () => [h, d, r];
          this.uploadFiles(e, i, t, h, l, (m) => {
            if (R.inputsAwaitingPreflight(e).length > 0)
              return this.undoRefs(h, i);
            let g = this.extractMeta(e, {}, r.value),
              u = wt(e, { submitter: n });
            this.pushWithReply(p, "event", {
              type: "form",
              event: i,
              value: u,
              meta: g,
              cid: l,
            })
              .then(({ resp: v }) => o(v))
              .catch((v) => w("Failed to push form submit", v));
          });
        } else if (
          !(e.hasAttribute(N) && e.classList.contains("phx-submit-loading"))
        ) {
          let h = this.extractMeta(e, {}, r.value),
            d = wt(e, { submitter: n });
          this.pushWithReply(a, "event", {
            type: "form",
            event: i,
            value: d,
            meta: h,
            cid: l,
          })
            .then(({ resp: p }) => o(p))
            .catch((p) => w("Failed to push form submit", p));
        }
      }
      uploadFiles(e, t, i, n, r, o) {
        let a = this.joinCount,
          l = R.activeFileInputs(e),
          h = l.length;
        l.forEach((d) => {
          let p = new R(d, this, () => {
              (h--, h === 0 && o());
            }),
            m = p.entries().map((u) => u.toPreflightPayload());
          if (m.length === 0) {
            h--;
            return;
          }
          let g = {
            ref: d.getAttribute(G),
            entries: m,
            cid: this.targetComponentID(d.form, i),
          };
          (this.log("upload", () => ["sending preflight request", g]),
            this.pushWithReply(null, "allow_upload", g)
              .then(({ resp: u }) => {
                if (
                  (this.log("upload", () => ["got preflight response", u]),
                  p.entries().forEach((v) => {
                    u.entries &&
                      !u.entries[v.ref] &&
                      this.handleFailedEntryPreflight(
                        v.ref,
                        "failed preflight",
                        p,
                      );
                  }),
                  u.error || Object.keys(u.entries).length === 0)
                )
                  (this.undoRefs(n, t),
                    (u.error || []).map(([E, M]) => {
                      this.handleFailedEntryPreflight(E, M, p);
                    }));
                else {
                  let v = (E) => {
                    this.channel.onError(() => {
                      this.joinCount === a && E();
                    });
                  };
                  p.initAdapterUpload(u, v, this.liveSocket);
                }
              })
              .catch((u) => w("Failed to push upload", u)));
        });
      }
      handleFailedEntryPreflight(e, t, i) {
        if (i.isAutoUpload()) {
          let n = i.entries().find((r) => r.ref === e.toString());
          n && n.cancel();
        } else i.entries().map((n) => n.cancel());
        this.log("upload", () => [`error for entry ${e}`, t]);
      }
      dispatchUploads(e, t, i) {
        let n = this.targetCtxElement(e) || this.el,
          r = c.findUploadInputs(n).filter((o) => o.name === t);
        r.length === 0
          ? w(`no live file inputs found matching the name "${t}"`)
          : r.length > 1
            ? w(`duplicate live file inputs found matching the name "${t}"`)
            : c.dispatchEvent(r[0], pt, { detail: { files: i } });
      }
      targetCtxElement(e) {
        if (ee(e)) {
          let [t] = c.findComponentNodeList(this.id, e);
          return t;
        } else return e || null;
      }
      pushFormRecovery(e, t, i, n) {
        let r = this.binding("change"),
          o = t.getAttribute(this.binding("target")) || t,
          a =
            t.getAttribute(this.binding(Lt)) ||
            t.getAttribute(this.binding("change")),
          l = Array.from(e.elements).filter(
            (p) => c.isFormInput(p) && p.name && !p.hasAttribute(r),
          );
        if (l.length === 0) {
          n();
          return;
        }
        l.forEach((p) => p.hasAttribute(G) && R.clearFiles(p));
        let h = l.find((p) => p.type !== "hidden") || l[0],
          d = 0;
        this.withinTargets(
          o,
          (p, m) => {
            let g = this.targetComponentID(t, m);
            d++;
            let u = new CustomEvent("phx:form-recovery", {
              detail: { sourceElement: e },
            });
            S.exec(u, "change", a, this, h, [
              "push",
              {
                _target: h.name,
                targetView: p,
                targetCtx: m,
                newCid: g,
                callback: () => {
                  (d--, d === 0 && n());
                },
              },
            ]);
          },
          i,
        );
      }
      pushLinkPatch(e, t, i, n) {
        let r = this.liveSocket.setPendingLink(t),
          o = e.isTrusted && e.type !== "popstate",
          a = i
            ? () =>
                this.putRef([{ el: i, loading: o, lock: !0 }], null, "click")
            : null,
          l = () => this.liveSocket.redirect(window.location.href),
          h = t.startsWith("/")
            ? `${location.protocol}//${location.host}${t}`
            : t;
        this.pushWithReply(a, "live_patch", { url: h }).then(
          ({ resp: d }) => {
            this.liveSocket.requestDOMUpdate(() => {
              if (d.link_redirect) this.liveSocket.replaceMain(t, null, n, r);
              else {
                if (d.redirect) return;
                (this.liveSocket.commitPendingLink(r) && (this.href = t),
                  this.applyPendingUpdates(),
                  n && n(r));
              }
            });
          },
          ({ error: d, timeout: p }) => l(),
        );
      }
      getFormsForRecovery() {
        if (this.joinCount === 0) return {};
        let e = this.binding("change");
        return c
          .all(
            document,
            `#${CSS.escape(this.id)} form[${e}], [${oe}="${CSS.escape(this.id)}"] form[${e}]`,
          )
          .filter((t) => t.id)
          .filter((t) => t.elements.length > 0)
          .filter((t) => t.getAttribute(this.binding(Lt)) !== "ignore")
          .map((t) => {
            let i = t.cloneNode(!0);
            rt(i, t, {
              onBeforeElUpdated: (r, o) => (
                c.copyPrivates(r, o),
                r.getAttribute("form") === t.id
                  ? (r.parentNode.removeChild(r), !1)
                  : !0
              ),
            });
            let n = document.querySelectorAll(`[form="${CSS.escape(t.id)}"]`);
            return (
              Array.from(n).forEach((r) => {
                let o = r.cloneNode(!0);
                (rt(o, r),
                  c.copyPrivates(o, r),
                  o.removeAttribute("form"),
                  i.appendChild(o));
              }),
              i
            );
          })
          .reduce((t, i) => ((t[i.id] = i), t), {});
      }
      maybePushComponentsDestroyed(e) {
        let t = e.filter(
            (n) => c.findComponentNodeList(this.id, n).length === 0,
          ),
          i = (n) => {
            this.isDestroyed() || w("Failed to push components destroyed", n);
          };
        t.length > 0 &&
          (t.forEach((n) => this.rendered.resetRender(n)),
          this.pushWithReply(null, "cids_will_destroy", { cids: t })
            .then(() => {
              this.liveSocket.requestDOMUpdate(() => {
                let n = t.filter(
                  (r) => c.findComponentNodeList(this.id, r).length === 0,
                );
                n.length > 0 &&
                  this.pushWithReply(null, "cids_destroyed", { cids: n })
                    .then(({ resp: r }) => {
                      this.rendered.pruneCIDs(r.cids);
                    })
                    .catch(i);
              });
            })
            .catch(i));
      }
      ownsElement(e) {
        let t = c.closestViewEl(e);
        return (
          e.getAttribute(se) === this.id ||
          (t && t.id === this.id) ||
          (!t && this.isDead)
        );
      }
      submitForm(e, t, i, n, r = {}) {
        (c.putPrivate(e, Pe, !0),
          Array.from(e.elements).forEach((a) => c.putPrivate(a, Pe, !0)),
          this.liveSocket.blurActiveElement(this),
          this.pushFormSubmit(e, t, i, n, r, () => {
            this.liveSocket.restorePreviouslyActiveFocus();
          }));
      }
      binding(e) {
        return this.liveSocket.binding(e);
      }
      pushPortalElementId(e) {
        this.portalElementIds.add(e);
      }
      dropPortalElementId(e) {
        this.portalElementIds.delete(e);
      }
      destroyPortalElements() {
        this.liveSocket.unloaded ||
          this.portalElementIds.forEach((e) => {
            let t = document.getElementById(e);
            t && t.remove();
          });
      }
    };
  var Mi = (s) => c.isUsedInput(s),
    ot = class {
      constructor(e, t, i = {}) {
        if (((this.unloaded = !1), !t || t.constructor.name === "Object"))
          throw new Error(`
      a phoenix Socket must be provided as the second argument to the LiveSocket constructor. For example:

          import {Socket} from "phoenix"
          import {LiveSocket} from "phoenix_live_view"
          let liveSocket = new LiveSocket("/live", Socket, {...})
      `);
        ((this.socket = new t(e, i)),
          (this.bindingPrefix = i.bindingPrefix || fi),
          (this.opts = i),
          (this.params = Je(i.params || {})),
          (this.viewLogger = i.viewLogger),
          (this.metadataCallbacks = i.metadata || {}),
          (this.defaults = Object.assign(We(mi), i.defaults || {})),
          (this.prevActive = null),
          (this.silenced = !1),
          (this.main = null),
          (this.outgoingMainEl = null),
          (this.clickStartedAtTarget = null),
          (this.linkRef = 1),
          (this.roots = {}),
          (this.href = window.location.href),
          (this.pendingLink = null),
          (this.currentLocation = We(window.location)),
          (this.hooks = i.hooks || {}),
          (this.uploaders = i.uploaders || {}),
          (this.loaderTimeout = i.loaderTimeout || hi),
          (this.disconnectedTimeout = i.disconnectedTimeout || ui),
          (this.reloadWithJitterTimer = null),
          (this.maxReloads = i.maxReloads || 10),
          (this.reloadJitterMin = i.reloadJitterMin || 5e3),
          (this.reloadJitterMax = i.reloadJitterMax || 1e4),
          (this.failsafeJitter = i.failsafeJitter || 3e4),
          (this.localStorage = i.localStorage || window.localStorage),
          (this.sessionStorage = i.sessionStorage || window.sessionStorage),
          (this.boundTopLevelEvents = !1),
          (this.boundEventNames = new Set()),
          (this.blockPhxChangeWhileComposing =
            i.blockPhxChangeWhileComposing || !1),
          (this.serverCloseRef = null),
          (this.domCallbacks = Object.assign(
            {
              jsQuerySelectorAll: null,
              onPatchStart: Je(),
              onPatchEnd: Je(),
              onNodeAdded: Je(),
              onBeforeElUpdated: Je(),
            },
            i.dom || {},
          )),
          (this.transitions = new Kt()),
          (this.currentHistoryPosition =
            parseInt(this.sessionStorage.getItem(tt)) || 0),
          window.addEventListener("pagehide", (n) => {
            this.unloaded = !0;
          }),
          this.socket.onOpen(() => {
            this.isUnloaded() && window.location.reload();
          }));
      }
      version() {
        return "1.1.28";
      }
      isProfileEnabled() {
        return this.sessionStorage.getItem(bt) === "true";
      }
      isDebugEnabled() {
        return this.sessionStorage.getItem(et) === "true";
      }
      isDebugDisabled() {
        return this.sessionStorage.getItem(et) === "false";
      }
      enableDebug() {
        this.sessionStorage.setItem(et, "true");
      }
      enableProfiling() {
        this.sessionStorage.setItem(bt, "true");
      }
      disableDebug() {
        this.sessionStorage.setItem(et, "false");
      }
      disableProfiling() {
        this.sessionStorage.removeItem(bt);
      }
      enableLatencySim(e) {
        (this.enableDebug(),
          console.log(
            "latency simulator enabled for the duration of this browser session. Call disableLatencySim() to disable",
          ),
          this.sessionStorage.setItem(Et, e));
      }
      disableLatencySim() {
        this.sessionStorage.removeItem(Et);
      }
      getLatencySim() {
        let e = this.sessionStorage.getItem(Et);
        return e ? parseInt(e) : null;
      }
      getSocket() {
        return this.socket;
      }
      connect() {
        window.location.hostname === "localhost" &&
          !this.isDebugDisabled() &&
          this.enableDebug();
        let e = () => {
          (this.resetReloadStatus(),
            this.joinRootViews()
              ? (this.bindTopLevelEvents(), this.socket.connect())
              : this.main
                ? this.socket.connect()
                : this.bindTopLevelEvents({ dead: !0 }),
            this.joinDeadView());
        };
        ["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0
          ? e()
          : document.addEventListener("DOMContentLoaded", () => e());
      }
      disconnect(e) {
        (clearTimeout(this.reloadWithJitterTimer),
          this.serverCloseRef &&
            (this.socket.off(this.serverCloseRef),
            (this.serverCloseRef = null)),
          this.socket.disconnect(e));
      }
      replaceTransport(e) {
        (clearTimeout(this.reloadWithJitterTimer),
          this.socket.replaceTransport(e),
          this.connect());
      }
      execJS(e, t, i = null) {
        let n = new CustomEvent("phx:exec", { detail: { sourceElement: e } });
        this.owner(e, (r) => S.exec(n, i, t, r, e));
      }
      js() {
        return St(this, "js");
      }
      unload() {
        this.unloaded ||
          (this.main &&
            this.isConnected() &&
            this.log(this.main, "socket", () => ["disconnect for page nav"]),
          (this.unloaded = !0),
          this.destroyAllViews(),
          this.disconnect());
      }
      triggerDOM(e, t) {
        this.domCallbacks[e](...t);
      }
      time(e, t) {
        if (!this.isProfileEnabled() || !console.time) return t();
        console.time(e);
        let i = t();
        return (console.timeEnd(e), i);
      }
      log(e, t, i) {
        if (this.viewLogger) {
          let [n, r] = i();
          this.viewLogger(e, t, n, r);
        } else if (this.isDebugEnabled()) {
          let [n, r] = i();
          bi(e, t, n, r);
        }
      }
      requestDOMUpdate(e) {
        this.transitions.after(e);
      }
      asyncTransition(e) {
        this.transitions.addAsyncTransition(e);
      }
      transition(e, t, i = function () {}) {
        this.transitions.addTransition(e, t, i);
      }
      onChannel(e, t, i) {
        e.on(t, (n) => {
          let r = this.getLatencySim();
          r ? setTimeout(() => i(n), r) : i(n);
        });
      }
      reloadWithJitter(e, t) {
        (clearTimeout(this.reloadWithJitterTimer), this.disconnect());
        let i = this.reloadJitterMin,
          n = this.reloadJitterMax,
          r = Math.floor(Math.random() * (n - i + 1)) + i,
          o = $.updateLocal(
            this.localStorage,
            window.location.pathname,
            ht,
            0,
            (a) => a + 1,
          );
        (o >= this.maxReloads && (r = this.failsafeJitter),
          (this.reloadWithJitterTimer = setTimeout(() => {
            e.isDestroyed() ||
              e.isConnected() ||
              (e.destroy(),
              t
                ? t()
                : this.log(e, "join", () => [
                    `encountered ${o} consecutive reloads`,
                  ]),
              o >= this.maxReloads &&
                this.log(e, "join", () => [
                  `exceeded ${this.maxReloads} consecutive reloads. Entering failsafe mode`,
                ]),
              this.hasPendingLink()
                ? (window.location = this.pendingLink)
                : window.location.reload());
          }, r)));
      }
      getHookDefinition(e) {
        if (e)
          return (
            this.maybeInternalHook(e) ||
            this.hooks[e] ||
            this.maybeRuntimeHook(e)
          );
      }
      maybeInternalHook(e) {
        return e && e.startsWith("Phoenix.") && ki[e.split(".")[1]];
      }
      maybeRuntimeHook(e) {
        let t = document.querySelector(`script[${Ve}="${CSS.escape(e)}"]`);
        if (!t) return;
        let i = window[`phx_hook_${e}`];
        if (!i || typeof i != "function") {
          w("a runtime hook must be a function", t);
          return;
        }
        let n = i();
        if (n && (typeof n == "object" || typeof n == "function")) return n;
        w(
          "runtime hook must return an object with hook callbacks or an instance of ViewHook",
          t,
        );
      }
      isUnloaded() {
        return this.unloaded;
      }
      isConnected() {
        return this.socket.isConnected();
      }
      getBindingPrefix() {
        return this.bindingPrefix;
      }
      binding(e) {
        return `${this.getBindingPrefix()}${e}`;
      }
      channel(e, t) {
        return this.socket.channel(e, t);
      }
      joinDeadView() {
        let e = document.body;
        if (
          e &&
          !this.isPhxView(e) &&
          !this.isPhxView(document.firstElementChild)
        ) {
          let t = this.newRootView(e);
          (t.setHref(this.getHref()),
            t.joinDead(),
            this.main || (this.main = t),
            window.requestAnimationFrame(() => {
              var i;
              (t.execNewMounted(),
                this.maybeScroll(
                  (i = history.state) == null ? void 0 : i.scroll,
                ));
            }));
        }
      }
      joinRootViews() {
        let e = !1;
        return (
          c.all(document, `${he}:not([${se}])`, (t) => {
            if (!this.getRootById(t.id)) {
              let i = this.newRootView(t);
              (c.isPhxSticky(t) || i.setHref(this.getHref()),
                i.join(),
                t.hasAttribute(De) && (this.main = i));
            }
            e = !0;
          }),
          e
        );
      }
      redirect(e, t, i) {
        (i && $.setCookie(Dt, i, 60), this.unload(), $.redirect(e, t));
      }
      replaceMain(e, t, i = null, n = this.setPendingLink(e)) {
        let r = this.currentLocation.href;
        this.outgoingMainEl = this.outgoingMainEl || this.main.el;
        let o = c.findPhxSticky(document) || [],
          a = c
            .all(this.outgoingMainEl, `[${this.binding("remove")}]`)
            .filter((h) => !c.isChildOfAny(h, o)),
          l = c.cloneNode(this.outgoingMainEl, "");
        (this.main.showLoader(this.loaderTimeout),
          this.main.destroy(),
          (this.main = this.newRootView(l, t, r)),
          this.main.setRedirect(e),
          this.transitionRemoves(a),
          this.main.join((h, d) => {
            h === 1 &&
              this.commitPendingLink(n) &&
              this.requestDOMUpdate(() => {
                (a.forEach((p) => p.remove()),
                  o.forEach((p) => l.appendChild(p)),
                  this.outgoingMainEl.replaceWith(l),
                  (this.outgoingMainEl = null),
                  i && i(n),
                  d());
              });
          }));
      }
      transitionRemoves(e, t) {
        let i = this.binding("remove"),
          n = (r) => {
            (r.preventDefault(), r.stopImmediatePropagation());
          };
        (e.forEach((r) => {
          for (let o of this.boundEventNames) r.addEventListener(o, n, !0);
          this.execJS(r, r.getAttribute(i), "remove");
        }),
          this.requestDOMUpdate(() => {
            (e.forEach((r) => {
              for (let o of this.boundEventNames)
                r.removeEventListener(o, n, !0);
            }),
              t && t());
          }));
      }
      isPhxView(e) {
        return e.getAttribute && e.getAttribute(q) !== null;
      }
      newRootView(e, t, i) {
        let n = new Re(e, this, null, t, i);
        return ((this.roots[n.id] = n), n);
      }
      owner(e, t) {
        let i,
          n = c.closestViewEl(e);
        if (n) i = this.getViewByEl(n);
        else {
          if (!e.isConnected) return null;
          i = this.main;
        }
        return i && t ? t(i) : i;
      }
      withinOwners(e, t) {
        this.owner(e, (i) => t(i, e));
      }
      getViewByEl(e) {
        let t = e.getAttribute(z);
        return fe(this.getRootById(t), (i) => i.getDescendentByEl(e));
      }
      getRootById(e) {
        return this.roots[e];
      }
      destroyAllViews() {
        for (let e in this.roots)
          (this.roots[e].destroy(), delete this.roots[e]);
        this.main = null;
      }
      destroyViewByEl(e) {
        let t = this.getRootById(e.getAttribute(z));
        t && t.id === e.id
          ? (t.destroy(), delete this.roots[t.id])
          : t && t.destroyDescendent(e.id);
      }
      getActiveElement() {
        return document.activeElement;
      }
      dropActiveElement(e) {
        this.prevActive &&
          e.ownsElement(this.prevActive) &&
          (this.prevActive = null);
      }
      restorePreviouslyActiveFocus() {
        this.prevActive &&
          this.prevActive !== document.body &&
          this.prevActive instanceof HTMLElement &&
          this.prevActive.focus();
      }
      blurActiveElement() {
        ((this.prevActive = this.getActiveElement()),
          this.prevActive !== document.body &&
            this.prevActive instanceof HTMLElement &&
            this.prevActive.blur());
      }
      bindTopLevelEvents({ dead: e } = {}) {
        this.boundTopLevelEvents ||
          ((this.boundTopLevelEvents = !0),
          (this.serverCloseRef = this.socket.onClose((t) => {
            if (t && t.code === 1e3 && this.main)
              return this.reloadWithJitter(this.main);
          })),
          document.body.addEventListener("click", function () {}),
          window.addEventListener(
            "pageshow",
            (t) => {
              t.persisted &&
                (this.getSocket().disconnect(),
                this.withPageLoading({
                  to: window.location.href,
                  kind: "redirect",
                }),
                window.location.reload());
            },
            !0,
          ),
          e || this.bindNav(),
          this.bindClicks(),
          e || this.bindForms(),
          this.bind(
            { keyup: "keyup", keydown: "keydown" },
            (t, i, n, r, o, a) => {
              let l = r.getAttribute(this.binding(li)),
                h = t.key && t.key.toLowerCase();
              if (l && l.toLowerCase() !== h) return;
              let d = L({ key: t.key }, this.eventMeta(i, t, r));
              S.exec(t, i, o, n, r, ["push", { data: d }]);
            },
          ),
          this.bind(
            { blur: "focusout", focus: "focusin" },
            (t, i, n, r, o, a) => {
              if (!a) {
                let l = L({ key: t.key }, this.eventMeta(i, t, r));
                S.exec(t, i, o, n, r, ["push", { data: l }]);
              }
            },
          ),
          this.bind({ blur: "blur", focus: "focus" }, (t, i, n, r, o, a) => {
            if (a === "window") {
              let l = this.eventMeta(i, t, r);
              S.exec(t, i, o, n, r, ["push", { data: l }]);
            }
          }),
          this.on("dragover", (t) => t.preventDefault()),
          this.on("dragenter", (t) => {
            let i = ue(t.target, this.binding(qe));
            !i ||
              !(i instanceof HTMLElement) ||
              (Ai(t) && this.js().addClass(i, ut));
          }),
          this.on("dragleave", (t) => {
            let i = ue(t.target, this.binding(qe));
            if (!i || !(i instanceof HTMLElement)) return;
            let n = i.getBoundingClientRect();
            (t.clientX <= n.left ||
              t.clientX >= n.right ||
              t.clientY <= n.top ||
              t.clientY >= n.bottom) &&
              this.js().removeClass(i, ut);
          }),
          this.on("drop", (t) => {
            t.preventDefault();
            let i = ue(t.target, this.binding(qe));
            if (!i || !(i instanceof HTMLElement)) return;
            this.js().removeClass(i, ut);
            let n = i.getAttribute(this.binding(qe)),
              r = n && document.getElementById(n),
              o = Array.from(t.dataTransfer.files || []);
            !r ||
              !(r instanceof HTMLInputElement) ||
              r.disabled ||
              o.length === 0 ||
              !(r.files instanceof FileList) ||
              (R.trackFiles(r, o, t.dataTransfer),
              r.dispatchEvent(new Event("input", { bubbles: !0 })));
          }),
          this.on(pt, (t) => {
            let i = t.target;
            if (!c.isUploadInput(i)) return;
            let n = Array.from(t.detail.files || []).filter(
              (r) => r instanceof File || r instanceof Blob,
            );
            (R.trackFiles(i, n),
              i.dispatchEvent(new Event("input", { bubbles: !0 })));
          }));
      }
      eventMeta(e, t, i) {
        let n = this.metadataCallbacks[e];
        return n ? n(t, i) : {};
      }
      setPendingLink(e) {
        return (
          this.linkRef++,
          (this.pendingLink = e),
          this.resetReloadStatus(),
          this.linkRef
        );
      }
      resetReloadStatus() {
        $.deleteCookie(Dt);
      }
      commitPendingLink(e) {
        return this.linkRef !== e
          ? !1
          : ((this.href = this.pendingLink), (this.pendingLink = null), !0);
      }
      getHref() {
        return this.href;
      }
      hasPendingLink() {
        return !!this.pendingLink;
      }
      bind(e, t) {
        for (let i in e) {
          let n = e[i];
          this.on(n, (r) => {
            let o = this.binding(i),
              a = this.binding(`window-${i}`),
              l = r.target.getAttribute && r.target.getAttribute(o);
            l
              ? this.debounce(r.target, r, n, () => {
                  this.withinOwners(r.target, (h) => {
                    t(r, i, h, r.target, l, null);
                  });
                })
              : c.all(document, `[${a}]`, (h) => {
                  let d = h.getAttribute(a);
                  this.debounce(h, r, n, () => {
                    this.withinOwners(h, (p) => {
                      t(r, i, p, h, d, "window");
                    });
                  });
                });
          });
        }
      }
      bindClicks() {
        (this.on("mousedown", (e) => (this.clickStartedAtTarget = e.target)),
          this.bindClick("click", "click"));
      }
      bindClick(e, t) {
        let i = this.binding(t);
        window.addEventListener(
          e,
          (n) => {
            let r = null;
            n.detail === 0 && (this.clickStartedAtTarget = n.target);
            let o = this.clickStartedAtTarget || n.target;
            ((r = ue(n.target, i)),
              this.dispatchClickAway(n, o),
              (this.clickStartedAtTarget = null));
            let a = r && r.getAttribute(i);
            if (!a) {
              c.isNewPageClick(n, window.location) && this.unload();
              return;
            }
            (r.getAttribute("href") === "#" && n.preventDefault(),
              !r.hasAttribute(N) &&
                this.debounce(r, n, "click", () => {
                  this.withinOwners(r, (l) => {
                    S.exec(n, "click", a, l, r, [
                      "push",
                      { data: this.eventMeta("click", n, r) },
                    ]);
                  });
                }));
          },
          !1,
        );
      }
      dispatchClickAway(e, t) {
        let i = this.binding("click-away"),
          n = t.closest(`[${te}]`),
          r = n && c.byId(n.getAttribute(te));
        c.all(document, `[${i}]`, (o) => {
          let a = t;
          (n && !n.contains(o) && (a = r),
            o.isSameNode(a) ||
              o.contains(a) ||
              !S.isVisible(t) ||
              this.withinOwners(o, (l) => {
                let h = o.getAttribute(i);
                S.isVisible(o) &&
                  S.isInViewport(o) &&
                  S.exec(e, "click", h, l, o, [
                    "push",
                    { data: this.eventMeta("click", e, e.target) },
                  ]);
              }));
        });
      }
      bindNav() {
        if (!$.canPushState()) return;
        history.scrollRestoration && (history.scrollRestoration = "manual");
        let e = null;
        (window.addEventListener("scroll", (t) => {
          (clearTimeout(e),
            (e = setTimeout(() => {
              $.updateCurrentState((i) =>
                Object.assign(i, { scroll: window.scrollY }),
              );
            }, 100)));
        }),
          window.addEventListener(
            "popstate",
            (t) => {
              if (!this.registerNewLocation(window.location)) return;
              let {
                  type: i,
                  backType: n,
                  id: r,
                  scroll: o,
                  position: a,
                } = t.state || {},
                l = window.location.href,
                h = a > this.currentHistoryPosition,
                d = h ? i : n || i;
              ((this.currentHistoryPosition = a || 0),
                this.sessionStorage.setItem(
                  tt,
                  this.currentHistoryPosition.toString(),
                ),
                c.dispatchEvent(window, "phx:navigate", {
                  detail: {
                    href: l,
                    patch: d === "patch",
                    pop: !0,
                    direction: h ? "forward" : "backward",
                  },
                }),
                this.requestDOMUpdate(() => {
                  let p = () => {
                    this.maybeScroll(o);
                  };
                  this.main.isConnected() && d === "patch" && r === this.main.id
                    ? this.main.pushLinkPatch(t, l, null, p)
                    : this.replaceMain(l, null, p);
                }));
            },
            !1,
          ),
          window.addEventListener(
            "click",
            (t) => {
              let i = ue(t.target, ft),
                n = i && i.getAttribute(ft);
              if (!n || !this.isConnected() || !this.main || c.wantsNewTab(t))
                return;
              let r =
                  i.href instanceof SVGAnimatedString ? i.href.baseVal : i.href,
                o = i.getAttribute(ei);
              (t.preventDefault(),
                t.stopImmediatePropagation(),
                this.pendingLink !== r &&
                  this.requestDOMUpdate(() => {
                    if (n === "patch") this.pushHistoryPatch(t, r, o, i);
                    else if (n === "redirect")
                      this.historyRedirect(t, r, o, null, i);
                    else
                      throw new Error(
                        `expected ${ft} to be "patch" or "redirect", got: ${n}`,
                      );
                    let a = i.getAttribute(this.binding("click"));
                    a &&
                      this.requestDOMUpdate(() => this.execJS(i, a, "click"));
                  }));
            },
            !1,
          ));
      }
      maybeScroll(e) {
        typeof e == "number" &&
          requestAnimationFrame(() => {
            window.scrollTo(0, e);
          });
      }
      dispatchEvent(e, t = {}) {
        c.dispatchEvent(window, `phx:${e}`, { detail: t });
      }
      dispatchEvents(e) {
        e.forEach(([t, i]) => this.dispatchEvent(t, i));
      }
      withPageLoading(e, t) {
        c.dispatchEvent(window, "phx:page-loading-start", { detail: e });
        let i = () =>
          c.dispatchEvent(window, "phx:page-loading-stop", { detail: e });
        return t ? t(i) : i;
      }
      pushHistoryPatch(e, t, i, n) {
        if (!this.isConnected() || !this.main.isMain()) return $.redirect(t);
        this.withPageLoading({ to: t, kind: "patch" }, (r) => {
          this.main.pushLinkPatch(e, t, n, (o) => {
            (this.historyPatch(t, i, o), r());
          });
        });
      }
      historyPatch(e, t, i = this.setPendingLink(e)) {
        this.commitPendingLink(i) &&
          (this.currentHistoryPosition++,
          this.sessionStorage.setItem(
            tt,
            this.currentHistoryPosition.toString(),
          ),
          $.updateCurrentState((n) => le(L({}, n), { backType: "patch" })),
          $.pushState(
            t,
            {
              type: "patch",
              id: this.main.id,
              position: this.currentHistoryPosition,
            },
            e,
          ),
          c.dispatchEvent(window, "phx:navigate", {
            detail: { patch: !0, href: e, pop: !1, direction: "forward" },
          }),
          this.registerNewLocation(window.location));
      }
      historyRedirect(e, t, i, n, r) {
        let o = r && e.isTrusted && e.type !== "popstate";
        if (
          (o && r.classList.add("phx-click-loading"),
          !this.isConnected() || !this.main.isMain())
        )
          return $.redirect(t, n);
        if (/^\/$|^\/[^\/]+.*$/.test(t)) {
          let { protocol: l, host: h } = window.location;
          t = `${l}//${h}${t}`;
        }
        let a = window.scrollY;
        this.withPageLoading({ to: t, kind: "redirect" }, (l) => {
          this.replaceMain(t, n, (h) => {
            (h === this.linkRef &&
              (this.currentHistoryPosition++,
              this.sessionStorage.setItem(
                tt,
                this.currentHistoryPosition.toString(),
              ),
              $.updateCurrentState((d) =>
                le(L({}, d), { backType: "redirect" }),
              ),
              $.pushState(
                i,
                {
                  type: "redirect",
                  id: this.main.id,
                  scroll: a,
                  position: this.currentHistoryPosition,
                },
                t,
              ),
              c.dispatchEvent(window, "phx:navigate", {
                detail: { href: t, patch: !1, pop: !1, direction: "forward" },
              }),
              this.registerNewLocation(window.location)),
              o && r.classList.remove("phx-click-loading"),
              l());
          });
        });
      }
      registerNewLocation(e) {
        let { pathname: t, search: i } = this.currentLocation;
        return t + i === e.pathname + e.search
          ? !1
          : ((this.currentLocation = We(e)), !0);
      }
      bindForms() {
        let e = 0,
          t = !1;
        (this.on("submit", (i) => {
          let n = i.target.getAttribute(this.binding("submit")),
            r = i.target.getAttribute(this.binding("change"));
          !t &&
            r &&
            !n &&
            ((t = !0),
            i.preventDefault(),
            this.withinOwners(i.target, (o) => {
              (o.disableForm(i.target),
                window.requestAnimationFrame(() => {
                  (c.isUnloadableFormSubmit(i) && this.unload(),
                    i.target.submit());
                }));
            }));
        }),
          this.on("submit", (i) => {
            let n = i.target.getAttribute(this.binding("submit"));
            if (!n) {
              c.isUnloadableFormSubmit(i) && this.unload();
              return;
            }
            (i.preventDefault(),
              (i.target.disabled = !0),
              this.withinOwners(i.target, (r) => {
                S.exec(i, "submit", n, r, i.target, [
                  "push",
                  { submitter: i.submitter },
                ]);
              }));
          }));
        for (let i of ["change", "input"])
          this.on(i, (n) => {
            if (
              n instanceof CustomEvent &&
              (n.target instanceof HTMLInputElement ||
                n.target instanceof HTMLSelectElement ||
                n.target instanceof HTMLTextAreaElement) &&
              n.target.form === void 0
            ) {
              if (n.detail && n.detail.dispatcher)
                throw new Error(
                  `dispatching a custom ${i} event is only supported on input elements inside a form`,
                );
              return;
            }
            let r = this.binding("change"),
              o = n.target;
            if (this.blockPhxChangeWhileComposing && n.isComposing) {
              let u = `composition-listener-${i}`;
              c.private(o, u) ||
                (c.putPrivate(o, u, !0),
                o.addEventListener(
                  "compositionend",
                  () => {
                    (o.dispatchEvent(new Event(i, { bubbles: !0 })),
                      c.deletePrivate(o, u));
                  },
                  { once: !0 },
                ));
              return;
            }
            let a = o.getAttribute(r),
              l = o.form && o.form.getAttribute(r),
              h = a || l;
            if (
              !h ||
              (o.type === "number" && o.validity && o.validity.badInput)
            )
              return;
            let d = a ? o : o.form,
              p = e;
            e++;
            let { at: m, type: g } = c.private(o, "prev-iteration") || {};
            (m === p - 1 && i === "change" && g === "input") ||
              (c.putPrivate(o, "prev-iteration", { at: p, type: i }),
              this.debounce(o, n, i, () => {
                this.withinOwners(d, (u) => {
                  (c.putPrivate(o, we, !0),
                    S.exec(n, "change", h, u, o, [
                      "push",
                      { _target: n.target.name, dispatcher: d },
                    ]));
                });
              }));
          });
        this.on("reset", (i) => {
          let n = i.target;
          c.resetForm(n);
          let r = Array.from(n.elements).find((o) => o.type === "reset");
          r &&
            window.requestAnimationFrame(() => {
              r.dispatchEvent(
                new Event("input", { bubbles: !0, cancelable: !1 }),
              );
            });
        });
      }
      debounce(e, t, i, n) {
        if (i === "blur" || i === "focusout") return n();
        let r = this.binding(ri),
          o = this.binding(oi),
          a = this.defaults.debounce.toString(),
          l = this.defaults.throttle.toString();
        this.withinOwners(e, (h) => {
          let d = () => !h.isDestroyed() && document.body.contains(e);
          c.debounce(e, t, r, a, o, l, d, () => {
            n();
          });
        });
      }
      silenceEvents(e) {
        ((this.silenced = !0), e(), (this.silenced = !1));
      }
      on(e, t) {
        (this.boundEventNames.add(e),
          window.addEventListener(e, (i) => {
            this.silenced || t(i);
          }));
      }
      jsQuerySelectorAll(e, t, i) {
        let n = this.domCallbacks.jsQuerySelectorAll;
        return n ? n(e, t, i) : i();
      }
    },
    Kt = class {
      constructor() {
        ((this.transitions = new Set()),
          (this.promises = new Set()),
          (this.pendingOps = []));
      }
      reset() {
        (this.transitions.forEach((e) => {
          (clearTimeout(e), this.transitions.delete(e));
        }),
          this.promises.clear(),
          this.flushPendingOps());
      }
      after(e) {
        this.size() === 0 ? e() : this.pushPendingOp(e);
      }
      addTransition(e, t, i) {
        t();
        let n = setTimeout(() => {
          (this.transitions.delete(n), i(), this.flushPendingOps());
        }, e);
        this.transitions.add(n);
      }
      addAsyncTransition(e) {
        (this.promises.add(e),
          e.then(() => {
            (this.promises.delete(e), this.flushPendingOps());
          }));
      }
      pushPendingOp(e) {
        this.pendingOps.push(e);
      }
      size() {
        return this.transitions.size + this.promises.size;
      }
      flushPendingOps() {
        if (this.size() > 0) return;
        let e = this.pendingOps.shift();
        e && (e(), this.flushPendingOps());
      }
    };
  var yn = ot;
  function An(s, e) {
    let t = c.getCustomElHook(s);
    if (t) return t;
    s.hasAttribute("id") ||
      w("Elements passed to createHook need to have a unique id attribute", s);
    let i = new Q(Re.closestView(s), s, e);
    return (c.putCustomElHook(s, i), i);
  }
  return Ji(_n);
})();

// Sigra passkeys:start
(function () {
  var CEREMONY_ABORTED = "ERROR_CEREMONY_ABORTED";
  var ERROR_PASSKEY_UNSUPPORTED = "ERROR_PASSKEY_UNSUPPORTED";
  function WebAuthnError(message, code) {
    this.name = "WebAuthnError";
    this.message = message;
    this.code = code;
  }
  WebAuthnError.prototype = Object.create(Error.prototype);
  WebAuthnError.prototype.constructor = WebAuthnError;
  var WebAuthnAbortService = {
    cancelCeremony: function () {},
  };
  function base64UrlEncode(bytes) {
    var binary = "";
    for (var i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/g, "");
  }
  function base64UrlDecode(value) {
    var normalized = value.replace(/-/g, "+").replace(/_/g, "/");
    var padding =
      normalized.length % 4 === 0
        ? ""
        : "=".repeat(4 - (normalized.length % 4));
    var binary = atob(normalized + padding);
    return Uint8Array.from(binary, function (char) {
      return char.charCodeAt(0);
    });
  }
  function toUint8Array(value) {
    if (value instanceof Uint8Array) {
      return value;
    }
    if (value instanceof ArrayBuffer) {
      return new Uint8Array(value);
    }
    if (Array.isArray(value)) {
      return Uint8Array.from(value);
    }
    if (typeof value === "string") {
      return base64UrlDecode(value);
    }
    throw new Error("unsupported WebAuthn binary payload");
  }
  function serializeCredential(credential) {
    var response = credential.response;
    return {
      id: credential.id,
      rawId: base64UrlEncode(new Uint8Array(credential.rawId)),
      type: credential.type,
      authenticatorAttachment: credential.authenticatorAttachment || null,
      response: {
        clientDataJSON: base64UrlEncode(
          new Uint8Array(response.clientDataJSON),
        ),
        attestationObject: response.attestationObject
          ? base64UrlEncode(new Uint8Array(response.attestationObject))
          : null,
        authenticatorData: response.authenticatorData
          ? base64UrlEncode(new Uint8Array(response.authenticatorData))
          : null,
        signature: response.signature
          ? base64UrlEncode(new Uint8Array(response.signature))
          : null,
        userHandle: response.userHandle
          ? base64UrlEncode(new Uint8Array(response.userHandle))
          : null,
      },
      clientExtensionResults: credential.getClientExtensionResults(),
    };
  }
  function normalizeAbort(error) {
    if (
      error &&
      (error.name === "AbortError" || error.code === CEREMONY_ABORTED)
    ) {
      return new WebAuthnError("aborted", CEREMONY_ABORTED);
    }
    return error;
  }
  function csrfToken() {
    var csrfMeta = document.querySelector("meta[name='csrf-token']");
    return csrfMeta ? csrfMeta.getAttribute("content") || "" : "";
  }
  function safeLoginStatus(error) {
    if (error === "email_required") {
      return {
        status: "email_required",
        message: "Enter your email to continue with a passkey.",
      };
    }
    if (
      error &&
      (error.code === ERROR_PASSKEY_UNSUPPORTED ||
        error.name === "NotSupportedError")
    ) {
      return {
        status: "unsupported",
        message: "Passkeys aren't available in this browser.",
      };
    }
    if (
      error &&
      (error.code === CEREMONY_ABORTED ||
        error.name === "AbortError" ||
        error.name === "NotAllowedError")
    ) {
      return {
        status: "canceled",
        message: "Passkey sign-in was canceled.",
      };
    }
    if (
      error &&
      (error.name === "TimeoutError" || error.code === "ERROR_CEREMONY_TIMEOUT")
    ) {
      return {
        status: "timeout",
        message: "That passkey request timed out.",
      };
    }
    return {
      status: "error",
      message:
        "We couldn't finish passkey sign-in. Try again or use another way to continue.",
    };
  }
  function updateLoginStatus(form, errorOrStatus) {
    var statusElement = form.querySelector("[data-passkey-login-status]");
    if (!statusElement) {
      return;
    }
    var status =
      typeof errorOrStatus === "string"
        ? safeLoginStatus(errorOrStatus)
        : safeLoginStatus(errorOrStatus);
    statusElement.dataset.passkeyStatus = status.status;
    statusElement.textContent = status.message;
  }
  function clearLoginStatus(form) {
    var statusElement = form.querySelector("[data-passkey-login-status]");
    if (!statusElement) {
      return;
    }
    statusElement.dataset.passkeyStatus = "";
    statusElement.textContent = "";
  }
  function findEmailInput(form, options) {
    if (options.emailInput) {
      return options.emailInput;
    }
    return (
      (form.dataset.emailInput
        ? document.querySelector(form.dataset.emailInput)
        : null) ||
      form.querySelector(
        "input[name='user[email]']:not([data-passkey-email-shadow])",
      )
    );
  }
  function fetchJsonOptions(optionsUrl, body) {
    return fetch(optionsUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        accept: "application/json",
        "x-csrf-token": csrfToken(),
      },
      body: JSON.stringify(body || {}),
    })
      .then(function (response) {
        if (!response.ok) {
          throw new Error("passkey_options_failed");
        }
        return response.json();
      })
      .then(function (json) {
        return json.options;
      });
  }
  function appendHiddenInput(form, name, value) {
    var input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    input.value = value;
    form.appendChild(input);
  }
  function submitCompletion(completeUrl, response, extra) {
    var form = document.createElement("form");
    form.method = "post";
    form.action = completeUrl;
    form.hidden = true;
    appendHiddenInput(form, "_csrf_token", csrfToken());
    appendHiddenInput(form, "passkey[response]", JSON.stringify(response));
    Object.entries(extra || {}).forEach(function (entry) {
      appendHiddenInput(form, entry[0], entry[1]);
    });
    document.body.appendChild(form);
    HTMLFormElement.prototype.submit.call(form);
  }
  function toPlainObject(payload) {
    return JSON.parse(JSON.stringify(payload));
  }
  function normalizeError(error) {
    return {
      name: (error && error.name) || "Error",
      message: (error && error.message) || "Passkey ceremony failed",
      code: (error && error.code) || null,
    };
  }
  function isCeremonyAbort(error) {
    return error instanceof WebAuthnError && error.code === CEREMONY_ABORTED;
  }
  function conditionalMediationAvailable() {
    var publicKeyCredential = window.PublicKeyCredential;
    if (!publicKeyCredential) {
      return Promise.resolve(false);
    }
    if (
      typeof publicKeyCredential.isConditionalMediationAvailable !== "function"
    ) {
      return Promise.resolve(false);
    }
    return publicKeyCredential.isConditionalMediationAvailable();
  }
  function startRegistration(params) {
    return navigator.credentials
      .create({
        publicKey: {
          challenge: toUint8Array(params.optionsJSON.challenge),
          user: {
            displayName: params.optionsJSON.user.displayName,
            id: toUint8Array(params.optionsJSON.user.id),
            name: params.optionsJSON.user.name,
          },
          rp: params.optionsJSON.rp,
          pubKeyCredParams: params.optionsJSON.pubKeyCredParams,
          timeout: params.optionsJSON.timeout,
          excludeCredentials: (params.optionsJSON.excludeCredentials || []).map(
            function (credential) {
              return {
                id: toUint8Array(credential.id),
                type: credential.type,
                transports: credential.transports,
              };
            },
          ),
          authenticatorSelection: params.optionsJSON.authenticatorSelection,
          attestation: params.optionsJSON.attestation,
          extensions: params.optionsJSON.extensions,
        },
        signal: params.signal,
      })
      .then(function (credential) {
        return serializeCredential(credential);
      })
      .catch(function (error) {
        throw normalizeAbort(error);
      });
  }
  function startAuthentication(params) {
    var request = {
      publicKey: {
        challenge: toUint8Array(params.optionsJSON.challenge),
        timeout: params.optionsJSON.timeout,
        rpId: params.optionsJSON.rpId,
        userVerification: params.optionsJSON.userVerification,
        allowCredentials: (params.optionsJSON.allowCredentials || []).map(
          function (credential) {
            return {
              id: toUint8Array(credential.id),
              type: credential.type,
              transports: credential.transports,
            };
          },
        ),
        extensions: params.optionsJSON.extensions,
      },
      signal: params.signal,
    };
    var mediation =
      params.useBrowserAutofill === true
        ? conditionalMediationAvailable().then(function (available) {
            if (!available) {
              throw new WebAuthnError("unsupported", ERROR_PASSKEY_UNSUPPORTED);
            }
            request.mediation = "conditional";
          })
        : Promise.resolve();
    return mediation
      .then(function () {
        return navigator.credentials.get(request);
      })
      .then(function (credential) {
        if (!credential) {
          throw new WebAuthnError("canceled", CEREMONY_ABORTED);
        }
        return serializeCredential(credential);
      })
      .catch(function (error) {
        throw normalizeAbort(error);
      });
  }
  function buildHook(config) {
    return {
      mounted: function () {
        var _this = this;
        this.__sigraPasskeyAbortController = null;
        this.__sigraPasskeyOperationId = 0;
        this.__sigraPasskeyActive = false;
        this.__sigraPasskeyAbortNotified = false;
        this.handleEvent(config.startEvent, function (payload) {
          payload = payload || {};
          _this.cancelPasskeyCeremony("superseded", false);
          var operationId = _this.__sigraPasskeyOperationId + 1;
          var abortController = new AbortController();
          _this.__sigraPasskeyOperationId = operationId;
          _this.__sigraPasskeyAbortController = abortController;
          _this.__sigraPasskeyActive = true;
          _this.__sigraPasskeyAbortNotified = false;
          var optionsPromise = payload.options
            ? Promise.resolve(payload.options)
            : payload.optionsUrl
              ? fetchJsonOptions(payload.optionsUrl, payload.optionsBody || {})
              : Promise.resolve(null);
          optionsPromise
            .then(function (optionsJSON) {
              return config.startCeremony(
                payload,
                optionsJSON,
                abortController.signal,
              );
            })
            .then(function (response) {
              if (
                !_this.isLatestPasskeyOperation(operationId) ||
                abortController.signal.aborted
              ) {
                return;
              }
              _this.pushEvent(config.successEvent, {
                response: toPlainObject(response),
              });
              if (payload.completeUrl) {
                var extra = Object.assign({}, payload.extra || {});
                var emailInput = document.querySelector(
                  "input[name='user[email]']",
                );
                if (emailInput && emailInput.value && !extra["user[email]"]) {
                  extra["user[email]"] = emailInput.value;
                }
                submitCompletion(payload.completeUrl, response, extra);
              }
            })
            .catch(function (error) {
              if (!_this.isLatestPasskeyOperation(operationId)) {
                return;
              }
              if (abortController.signal.aborted || isCeremonyAbort(error)) {
                if (!_this.__sigraPasskeyAbortNotified) {
                  _this.pushEvent(config.abortedEvent, { reason: "aborted" });
                }
              } else {
                _this.pushEvent(config.errorEvent, normalizeError(error));
              }
            })
            .finally(function () {
              if (_this.isLatestPasskeyOperation(operationId)) {
                _this.__sigraPasskeyAbortController = null;
                _this.__sigraPasskeyActive = false;
                _this.__sigraPasskeyAbortNotified = false;
              }
            });
        });
      },
      destroyed: function () {
        this.cancelPasskeyCeremony("destroyed");
      },
      disconnected: function () {
        this.cancelPasskeyCeremony("disconnected");
      },
      cancelPasskeyCeremony: function (reason, notify) {
        if (notify === void 0) notify = true;
        if (!this.__sigraPasskeyAbortController) {
          return;
        }
        this.__sigraPasskeyAbortController.abort();
        WebAuthnAbortService.cancelCeremony();
        if (notify && this.__sigraPasskeyActive) {
          this.__sigraPasskeyAbortNotified = true;
          this.pushEvent(config.abortedEvent, { reason: reason });
        }
        this.__sigraPasskeyAbortController = null;
        this.__sigraPasskeyActive = false;
      },
      isLatestPasskeyOperation: function (operationId) {
        return this.__sigraPasskeyOperationId === operationId;
      },
    };
  }
  var PasskeyRegister = buildHook({
    startEvent: "sigra:passkey-register:start",
    successEvent: "sigra:passkey-register:success",
    errorEvent: "sigra:passkey-register:error",
    abortedEvent: "sigra:passkey-register:aborted",
    startCeremony: function (_payload, optionsJSON, signal) {
      return startRegistration({ optionsJSON: optionsJSON, signal: signal });
    },
  });
  var PasskeyAuthenticate = buildHook({
    startEvent: "sigra:passkey-authenticate:start",
    successEvent: "sigra:passkey-authenticate:success",
    errorEvent: "sigra:passkey-authenticate:error",
    abortedEvent: "sigra:passkey-authenticate:aborted",
    startCeremony: function (payload, optionsJSON, signal) {
      return startAuthentication({
        optionsJSON: optionsJSON,
        signal: signal,
        useBrowserAutofill: payload.useBrowserAutofill === true,
      });
    },
  });
  function submitPasskeyLogin(form, completeUrl, responseInput, response) {
    responseInput.value = JSON.stringify(response);
    form.action = completeUrl;
    HTMLFormElement.prototype.submit.call(form);
  }
  function attachPasskeyLogin(options) {
    options = options || {};
    var form = options.form || document.querySelector("#passkey_login_form");
    var button =
      options.button || document.querySelector("#passkey_login_button");
    if (!form || !button) {
      return { attached: false };
    }
    var emailInput = findEmailInput(form, options);
    var emailShadowInput = form.querySelector("[data-passkey-email-shadow]");
    var responseInput = form.querySelector("input[name='passkey[response]']");
    if (!responseInput) {
      return { attached: false };
    }
    if (form.dataset.passkeyLoginBound === "true") {
      return { attached: true, ready: Promise.resolve() };
    }
    form.dataset.passkeyLoginBound = "true";
    var optionsUrl =
      options.optionsUrl ||
      form.dataset.optionsUrl ||
      form.dataset.optionsPath ||
      "/users/log_in/passkey/options";
    var completeUrl =
      options.completeUrl || form.action || "/users/log_in/passkey";
    function authenticateExplicit(event) {
      event.preventDefault();
      var email = emailInput && emailInput.value ? emailInput.value.trim() : "";
      if (!email) {
        updateLoginStatus(form, "email_required");
        return Promise.resolve();
      }
      clearLoginStatus(form);
      return fetchJsonOptions(optionsUrl, { user: { email: email } })
        .then(function (optionsJSON) {
          return startAuthentication({
            optionsJSON: optionsJSON,
            useBrowserAutofill: false,
          });
        })
        .then(function (response) {
          if (emailShadowInput) {
            emailShadowInput.value = email;
          }
          submitPasskeyLogin(form, completeUrl, responseInput, response);
        })
        .catch(function (error) {
          updateLoginStatus(form, error);
        });
    }
    button.addEventListener("click", authenticateExplicit);
    form.addEventListener("submit", authenticateExplicit);
    var ready =
      options.enableConditionalUI === true
        ? conditionalMediationAvailable()
            .then(function (available) {
              if (!available) {
                throw new WebAuthnError(
                  "unsupported",
                  ERROR_PASSKEY_UNSUPPORTED,
                );
              }
              return fetchJsonOptions(optionsUrl, { conditional: "true" })
                .then(function (optionsJSON) {
                  return startAuthentication({
                    optionsJSON: optionsJSON,
                    useBrowserAutofill: true,
                  });
                })
                .then(function (response) {
                  submitPasskeyLogin(
                    form,
                    completeUrl,
                    responseInput,
                    response,
                  );
                });
            })
            .catch(function (error) {
              if (options.silentConditionalErrors === false) {
                updateLoginStatus(form, error);
              } else {
                clearLoginStatus(form);
              }
            })
        : Promise.resolve();
    return { attached: true, ready: ready };
  }
  window.SigraPasskeyRuntime = {
    PasskeyRegister: PasskeyRegister,
    PasskeyAuthenticate: PasskeyAuthenticate,
    attachPasskeyLogin: attachPasskeyLogin,
  };
  document.addEventListener("DOMContentLoaded", function () {
    attachPasskeyLogin({
      enableConditionalUI: true,
      silentConditionalErrors: true,
    });
  });
})();
// Sigra passkeys:end

// Sigra demo branding:start
(() => {
  const COOKIE_NAME = "sigra_demo_brand";
  const THEME_COOKIE_NAME = "sigra_demo_theme";
  const STORAGE_KEY = "sigra.demo.brand";
  const THEME_STORAGE_KEY = "sigra.demo.theme";
  const THEMES = ["system", "light", "dark"];
  const textKeys = ["product_name", "email_from_name", "email_from_address"];
  const sigraStyleTokens = [
    ["--sigra-auth-accent", "accent_color"],
    ["--sigra-auth-on-accent", "accent_foreground"],
    ["--sigra-auth-bg", "background_color"],
    ["--sigra-auth-surface", "surface_color"],
    ["--sigra-auth-text", "text_color"],
    ["--sigra-auth-muted", "muted_color"],
    ["--sigra-auth-border", "border_color"],
  ];
  const vaultrStyleTokens = [
    ["--vt-color-primary", "accent_color"],
    ["--vt-color-primary-strong", "accent_color"],
    ["--vt-color-accent", "accent_color"],
    ["--vt-color-on-primary", "accent_foreground"],
    ["--vt-color-page", "background_color"],
    ["--vt-color-panel", "surface_color"],
    ["--vt-color-panel-alt", "background_color"],
    ["--vt-color-ink", "text_color"],
    ["--vt-color-muted", "muted_color"],
    ["--vt-color-line", "border_color"],
    ["--vt-color-line-strong", "border_color"],
  ];

  function normalizeTheme(value) {
    const normalized = String(value || "")
      .trim()
      .toLowerCase();
    return THEMES.includes(normalized) ? normalized : null;
  }

  function readBrandState() {
    const host = document.querySelector("[data-demo-brand-presets]");
    if (!host) {
      return null;
    }

    try {
      const presets = JSON.parse(host.dataset.demoBrandPresets || "[]");
      const defaultId =
        host.dataset.demoBrandDefault || (presets[0] && presets[0].id);
      const defaultTheme = normalizeTheme(host.dataset.demoBrandThemeDefault);
      return {
        presets,
        defaultId,
        defaultTheme,
        currentBrandId: defaultId,
        currentTheme: defaultTheme,
        themeLocked: false,
      };
    } catch (_error) {
      return null;
    }
  }

  function readCookie(name) {
    const cookie = document.cookie
      .split(";")
      .map((cookie) => cookie.trim())
      .find((cookie) => cookie.startsWith(`${name}=`));
    if (!cookie) {
      return null;
    }

    return decodeURIComponent(cookie.split("=").slice(1).join("="));
  }

  function storedBrandId() {
    const cookieBrandId = readCookie(COOKIE_NAME);
    if (cookieBrandId) {
      return cookieBrandId;
    }

    try {
      return window.localStorage && window.localStorage.getItem(STORAGE_KEY);
    } catch (_error) {
      return null;
    }
  }

  function storedTheme() {
    const cookieTheme = normalizeTheme(readCookie(THEME_COOKIE_NAME));
    if (cookieTheme) {
      return cookieTheme;
    }

    try {
      return normalizeTheme(
        window.localStorage && window.localStorage.getItem(THEME_STORAGE_KEY),
      );
    } catch (_error) {
      return null;
    }
  }

  function storeBrandId(id) {
    document.cookie = `${COOKIE_NAME}=${encodeURIComponent(id)}; Max-Age=31536000; Path=/; SameSite=Lax`;
    try {
      if (window.localStorage) {
        window.localStorage.setItem(STORAGE_KEY, id);
      }
    } catch (_error) {
      return;
    }
  }

  function storeTheme(theme) {
    document.cookie = `${THEME_COOKIE_NAME}=${encodeURIComponent(theme)}; Max-Age=31536000; Path=/; SameSite=Lax`;
    try {
      if (window.localStorage) {
        window.localStorage.setItem(THEME_STORAGE_KEY, theme);
      }
    } catch (_error) {
      return;
    }
  }

  function findPreset(state, id) {
    return (
      state.presets.find((preset) => preset.id === id) ||
      state.presets.find((preset) => preset.id === state.defaultId) ||
      state.presets[0]
    );
  }

  function defaultThemeForPreset(state, preset) {
    return (
      normalizeTheme(preset && preset.default_theme) ||
      normalizeTheme(preset && preset.profile && preset.profile.theme) ||
      state.defaultTheme ||
      "system"
    );
  }

  function resolveTheme(state, preset, value) {
    return normalizeTheme(value) || defaultThemeForPreset(state, preset);
  }

  function activeVariant(theme) {
    if (theme === "dark") {
      return "dark";
    }

    if (
      theme === "system" &&
      window.matchMedia &&
      window.matchMedia("(prefers-color-scheme: dark)").matches
    ) {
      return "dark";
    }

    return "light";
  }

  function profileForTheme(preset, theme) {
    const profiles = preset.profiles || {};
    const variant = activeVariant(theme);
    return (
      profiles[variant] ||
      preset.profile ||
      profiles.light ||
      profiles.dark ||
      {}
    );
  }

  function variantProperty(property, variant) {
    if (property.startsWith("--sigra-auth-")) {
      return `--sigra-auth-${variant}-${property.slice("--sigra-auth-".length)}`;
    }

    if (property.startsWith("--vt-color-")) {
      return `--vt-${variant}-color-${property.slice("--vt-color-".length)}`;
    }

    return property;
  }

  function setText(root, key, value) {
    root
      .querySelectorAll(`[data-demo-brand-text="${key}"]`)
      .forEach((element) => {
        element.textContent = value || "";
      });
  }

  function applyVariantStyles(root, preset, theme, tokens) {
    const profiles = preset.profiles || {};
    for (const [property] of tokens) {
      root.style.removeProperty(property);
    }

    for (const variant of ["light", "dark"]) {
      const profile = profiles[variant] || preset.profile || {};
      for (const [property, key] of tokens) {
        if (profile[key]) {
          root.style.setProperty(
            variantProperty(property, variant),
            profile[key],
          );
        }
      }
    }

    if (tokens === vaultrStyleTokens) {
      root.style.setProperty(
        "--vt-light-color-accent-soft",
        "color-mix(in oklab, var(--vt-light-color-accent) 18%, var(--vt-light-color-panel))",
      );
      root.style.setProperty(
        "--vt-dark-color-accent-soft",
        "color-mix(in oklab, var(--vt-dark-color-accent) 26%, transparent)",
      );
    }

    root.dataset.theme = theme;
  }

  function applyBrandAssets(profile) {
    const productName = profile.product_name || "";
    const logoUrl = profile.logo_url || "";
    const logoAlt =
      profile.logo_alt || (productName ? `${productName} logo` : "Brand logo");
    document.querySelectorAll("[data-demo-brand-logo]").forEach((element) => {
      if (logoUrl) {
        element.setAttribute("src", logoUrl);
        element.setAttribute("alt", logoAlt);
        element.hidden = false;
      } else {
        element.removeAttribute("src");
        element.setAttribute("alt", "");
        element.hidden = true;
      }
    });
    document
      .querySelectorAll("[data-demo-brand-fallback-mark]")
      .forEach((element) => {
        element.hidden = Boolean(logoUrl);
      });
    document
      .querySelectorAll("[data-demo-brand-initial]")
      .forEach((element) => {
        element.textContent =
          productName.trim().slice(0, 1).toUpperCase() || "?";
        element.hidden = Boolean(logoUrl);
      });
  }

  function applyPreset(state, id, options = {}) {
    const preset = findPreset(state, id);
    if (!preset) {
      return;
    }

    const theme = resolveTheme(state, preset, options.theme);
    const profile = profileForTheme(preset, theme);
    if (options.persistBrand) {
      storeBrandId(preset.id);
    }

    if (options.persistTheme) {
      storeTheme(theme);
    }

    state.currentBrandId = preset.id;
    state.currentTheme = theme;
    state.themeLocked = state.themeLocked || Boolean(options.persistTheme);
    document.documentElement.dataset.sigraDemoBrand = preset.id;
    document.documentElement.dataset.sigraDemoTheme = theme;
    textKeys.forEach((key) => {
      setText(document, key, profile[key]);
    });
    document
      .querySelectorAll("[data-demo-brand-description]")
      .forEach((element) => {
        element.textContent = preset.description || "";
      });
    document
      .querySelectorAll("[data-demo-brand-subject]")
      .forEach((element) => {
        element.textContent = preset.email_subject || "";
      });
    applyBrandAssets(profile);
    document
      .querySelectorAll("[data-demo-auth-preview], [data-demo-email-preview]")
      .forEach((element) => {
        applyVariantStyles(element, preset, theme, sigraStyleTokens);
      });
    document
      .querySelectorAll("[data-demo-brand-surface]")
      .forEach((element) => {
        applyVariantStyles(element, preset, theme, vaultrStyleTokens);
      });
    document.querySelectorAll("[data-demo-brand-select]").forEach((select) => {
      select.value = preset.id;
    });
    document.querySelectorAll("[data-demo-brand-theme]").forEach((input) => {
      input.checked = input.value === theme;
    });
  }

  function initDemoBranding() {
    const state = readBrandState();
    if (!state || state.presets.length === 0) {
      return;
    }

    const storedId = storedBrandId();
    const theme = storedTheme();
    state.themeLocked = Boolean(theme);
    applyPreset(state, storedId || state.defaultId, {
      theme,
      persistBrand: Boolean(storedId),
    });
    document.addEventListener("change", (event) => {
      const select =
        event.target &&
        event.target.closest &&
        event.target.closest("[data-demo-brand-select]");
      if (select) {
        applyPreset(state, select.value, {
          theme: state.themeLocked ? state.currentTheme : null,
          persistBrand: true,
        });
        return;
      }

      const themeInput =
        event.target &&
        event.target.closest &&
        event.target.closest("[data-demo-brand-theme]");
      if (themeInput) {
        state.themeLocked = true;
        applyPreset(state, state.currentBrandId, {
          theme: themeInput.value,
          persistTheme: true,
        });
      }
    });
    if (window.matchMedia) {
      const media = window.matchMedia("(prefers-color-scheme: dark)");
      const refreshSystemAssets = () => {
        if (state.currentTheme === "system") {
          applyPreset(state, state.currentBrandId, { theme: "system" });
        }
      };
      if (media.addEventListener) {
        media.addEventListener("change", refreshSystemAssets);
      } else if (media.addListener) {
        media.addListener(refreshSystemAssets);
      }
    }
  }

  document.addEventListener("DOMContentLoaded", initDemoBranding);
})();
// Sigra demo branding:end

// Sigra admin hooks:start
// Plain JS (NO import/export) mirror of test/example/assets/js/admin_hooks.js.
// Defines window.SigraAdminHooks = { CmdK, CopyToClipboard, ThemeSwitch,
// AuthBrandingPreview } and installs delegated admin affordances.
(function () {
  "use strict";

  var THEME_STORAGE_KEY = "sigra.admin.theme";
  var THEMES = ["light", "dark", "system"];
  var PAGE_LOADING_DELAY_MS = 180;
  var PAGE_LOADING_MIN_VISIBLE_MS = 220;
  var PAGE_LOADING_FADE_MS = 160;
  var PAGE_LOADING_MAX_ACTIVE_MS = 10000;
  var PAGE_LOADING_KINDS = {
    initial: true,
    patch: true,
    redirect: true,
  };
  var AUTH_BRANDING_HEX = /^#[0-9a-fA-F]{6}$/;
  var AUTH_BRANDING_COLOR_TOKENS = {
    accent_color: "--sigra-auth-light-accent",
    accent_foreground: "--sigra-auth-light-on-accent",
    background_color: "--sigra-auth-light-bg",
    surface_color: "--sigra-auth-light-surface",
    text_color: "--sigra-auth-light-text",
    muted_color: "--sigra-auth-light-muted",
    border_color: "--sigra-auth-light-border",
    dark_accent_color: "--sigra-auth-dark-accent",
    dark_accent_foreground: "--sigra-auth-dark-on-accent",
    dark_background_color: "--sigra-auth-dark-bg",
    dark_surface_color: "--sigra-auth-dark-surface",
    dark_text_color: "--sigra-auth-dark-text",
    dark_muted_color: "--sigra-auth-dark-muted",
    dark_border_color: "--sigra-auth-dark-border",
  };

  function storedTheme() {
    try {
      var value =
        window.localStorage && window.localStorage.getItem(THEME_STORAGE_KEY);
      return THEMES.indexOf(value) === -1 ? "system" : value;
    } catch (err) {
      return "system";
    }
  }

  function applyTheme(value) {
    var theme = THEMES.indexOf(value) === -1 ? "system" : value;
    if (theme === "system") {
      document.documentElement.removeAttribute("data-sg-admin-theme");
    } else {
      document.documentElement.setAttribute("data-sg-admin-theme", theme);
    }
    document.documentElement.dataset.sgAdminThemePreference = theme;
    document.querySelectorAll(".sg-admin-shell").forEach(function (shell) {
      shell.dataset.themePreference = theme;
      if (theme === "system") {
        shell.removeAttribute("data-theme");
      } else {
        shell.setAttribute("data-theme", theme);
      }
    });
    return theme;
  }

  applyTheme(storedTheme());

  function ensureToastRegion() {
    var region = document.querySelector(".sg-toast-region");
    if (!region) {
      region = document.createElement("div");
      region.className = "sg-toast-region";
      region.setAttribute("aria-live", "polite");
      document.body.appendChild(region);
    }
    return region;
  }

  function showToast(message) {
    var region = ensureToastRegion();
    var toast = document.createElement("div");
    toast.className = "sg-toast sg-toast--enter";
    toast.setAttribute("role", "status");
    toast.textContent = message;
    region.appendChild(toast);
    window.setTimeout(function () {
      toast.classList.remove("sg-toast--enter");
      toast.classList.add("sg-toast--leave");
      window.setTimeout(function () {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast);
        }
      }, 240);
    }, 2000);
  }

  var FOCUSABLE =
    'a[href], button:not([disabled]), input, [tabindex]:not([tabindex="-1"])';

  var CmdK = {
    mounted: function () {
      var self = this;

      var ds = this.el.dataset;
      this.commands = [
        { label: "Find users", href: ds.usersHref || "/admin/users" },
        { label: "Investigate audit", href: ds.auditHref || "/admin/audit" },
        {
          label: "Review " + (ds.overviewLabel || "Global") + " overview",
          href: ds.overviewHref || "/admin",
        },
      ];
      this.usersHref = ds.usersHref || "/admin/users";

      this.overlay = null;
      this.activeIndex = 0;
      this.filtered = this.commands.slice();

      this._onKeydown = function (event) {
        var key = event.key ? event.key.toLowerCase() : "";
        if ((event.metaKey || event.ctrlKey) && key === "k") {
          event.preventDefault();
          self.toggle();
        }
      };
      document.addEventListener("keydown", this._onKeydown);

      this._onTriggerClick = function () {
        self.open();
      };
      this.el.addEventListener("click", this._onTriggerClick);
    },

    toggle: function () {
      if (this.overlay) {
        this.close();
      } else {
        this.open();
      }
    },

    open: function () {
      if (this.overlay) return;
      var self = this;

      var overlay = document.createElement("div");
      overlay.className = "sg-cmdk sg-cmdk--enter";

      var dialog = document.createElement("div");
      dialog.className = "sg-cmdk__dialog";
      dialog.setAttribute("role", "dialog");
      dialog.setAttribute("aria-modal", "true");
      dialog.setAttribute("aria-label", "Command palette");

      var input = document.createElement("input");
      input.type = "text";
      input.className = "sg-cmdk__input";
      input.setAttribute("aria-label", "Find a user or jump to a page");
      input.setAttribute("placeholder", "Find a user or jump to a page…");

      var list = document.createElement("ul");
      list.className = "sg-cmdk__list";
      list.setAttribute("role", "listbox");

      dialog.appendChild(input);
      dialog.appendChild(list);
      overlay.appendChild(dialog);
      document.body.appendChild(overlay);

      this.overlay = overlay;
      this.dialog = dialog;
      this.input = input;
      this.list = list;
      this.activeIndex = 0;
      this.renderItems("");

      this._onOverlayClick = function (event) {
        if (event.target === overlay) {
          self.close();
        }
      };
      overlay.addEventListener("click", this._onOverlayClick);

      this._onInput = function () {
        self.activeIndex = 0;
        self.renderItems(input.value);
      };
      input.addEventListener("input", this._onInput);

      this._onDialogKeydown = function (event) {
        self.handleKeydown(event);
      };
      dialog.addEventListener("keydown", this._onDialogKeydown);

      input.focus();
    },

    renderItems: function (query) {
      var self = this;
      var q = (query || "").trim().toLowerCase();
      this.filtered = q
        ? this.commands.filter(function (cmd) {
            return cmd.label.toLowerCase().indexOf(q) !== -1;
          })
        : this.commands.slice();

      this.list.innerHTML = "";

      if (this.filtered.length === 0) {
        var empty = document.createElement("li");
        empty.className = "sg-cmdk__empty";
        empty.textContent = q
          ? 'Press Enter to find users matching "' + query.trim() + '"'
          : "No matches";
        this.list.appendChild(empty);
        return;
      }

      if (this.activeIndex >= this.filtered.length) {
        this.activeIndex = this.filtered.length - 1;
      }

      this.filtered.forEach(function (cmd, index) {
        var item = document.createElement("li");
        item.className = "sg-cmdk__item";
        item.setAttribute("role", "option");
        item.textContent = cmd.label;
        var active = index === self.activeIndex;
        item.classList.toggle("is-active", active);
        item.setAttribute("aria-selected", active ? "true" : "false");
        item.addEventListener("click", function () {
          self.navigate(cmd.href);
        });
        self.list.appendChild(item);
      });
    },

    handleKeydown: function (event) {
      var key = event.key;

      if (key === "Escape") {
        event.preventDefault();
        this.close();
        return;
      }

      if (key === "ArrowDown") {
        event.preventDefault();
        if (this.filtered.length) {
          this.activeIndex = (this.activeIndex + 1) % this.filtered.length;
          this.refreshActive();
        }
        return;
      }

      if (key === "ArrowUp") {
        event.preventDefault();
        if (this.filtered.length) {
          this.activeIndex =
            (this.activeIndex - 1 + this.filtered.length) %
            this.filtered.length;
          this.refreshActive();
        }
        return;
      }

      if (key === "Enter") {
        event.preventDefault();
        var text = this.input.value.trim();
        if (this.filtered.length) {
          this.navigate(this.filtered[this.activeIndex].href);
        } else if (text) {
          var sep = this.usersHref.indexOf("?") !== -1 ? "&" : "?";
          this.navigate(this.usersHref + sep + "q=" + encodeURIComponent(text));
        }
        return;
      }

      if (key === "Tab") {
        this.trapFocus(event);
      }
    },

    refreshActive: function () {
      var self = this;
      var items = this.list.querySelectorAll(".sg-cmdk__item");
      items.forEach(function (item, index) {
        var active = index === self.activeIndex;
        item.classList.toggle("is-active", active);
        item.setAttribute("aria-selected", active ? "true" : "false");
      });
    },

    trapFocus: function (event) {
      var focusables = this.dialog.querySelectorAll(FOCUSABLE);
      if (!focusables.length) return;
      var first = focusables[0];
      var last = focusables[focusables.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    },

    navigate: function (href) {
      this.close();
      window.location.assign(href);
    },

    close: function () {
      if (!this.overlay) return;
      this.overlay.removeEventListener("click", this._onOverlayClick);
      if (this.dialog) {
        this.dialog.removeEventListener("keydown", this._onDialogKeydown);
      }
      if (this.input) {
        this.input.removeEventListener("input", this._onInput);
      }
      if (this.overlay.parentNode) {
        this.overlay.parentNode.removeChild(this.overlay);
      }
      this.overlay = null;
      this.dialog = null;
      this.input = null;
      this.list = null;
      if (this.el) {
        this.el.focus();
      }
    },

    destroyed: function () {
      document.removeEventListener("keydown", this._onKeydown);
      if (this.el && this._onTriggerClick) {
        this.el.removeEventListener("click", this._onTriggerClick);
      }
      this.close();
    },

    disconnected: function () {
      this.close();
    },
  };

  // ---- ConfirmDialog hook (refreshed from assets/js/admin_hooks.js) --------
  // WAI-ARIA APG Dialog (Modal): focus trap, initial focus on Cancel, Escape +
  // scrim cancel, focus return to trigger on destroy. WR-01/02/03 hardening.
  var ConfirmDialog = {
    mounted: function () {
      var self = this;
      this._trigger = document.activeElement;
      document.body.classList.add("sg-body-scroll-locked");
      var dialog = this.el.querySelector(".sg-confirm-dialog");
      if (dialog) {
        var cancelEl = dialog.querySelector("[data-sg-confirm-cancel]");
        if (cancelEl) {
          cancelEl.focus();
        } else {
          var focusables = dialog.querySelectorAll(FOCUSABLE);
          if (focusables.length) {
            focusables[0].focus();
          }
        }
      }
      this._onKeydown = function (event) {
        var key = event.key;
        try {
          if (key === "Escape") {
            event.preventDefault();
            event.stopImmediatePropagation();
            self._cancel();
            return;
          }
          if (key === "Tab") {
            self._trapFocus(event);
          }
        } catch (err) {
          // never throw from a keydown handler
        }
      };
      document.addEventListener("keydown", this._onKeydown);
      this._onOverlayClick = function (event) {
        try {
          if (event.target === self.el) {
            self._cancel();
          }
        } catch (err) {
          // never throw from a click handler
        }
      };
      this.el.addEventListener("click", this._onOverlayClick);
    },
    _cancel: function () {
      var dialog = this.el.querySelector(".sg-confirm-dialog");
      if (!dialog) return;
      var cancelEl = dialog.querySelector("[data-sg-confirm-cancel]");
      if (cancelEl) {
        cancelEl.click();
        return;
      }
      var focusables = dialog.querySelectorAll(FOCUSABLE);
      if (focusables.length) {
        focusables[0].click();
      }
    },
    _trapFocus: function (event) {
      var dialog = this.el.querySelector(".sg-confirm-dialog");
      if (!dialog) return;
      var focusables = dialog.querySelectorAll(FOCUSABLE);
      if (!focusables.length) return;
      var first = focusables[0];
      var last = focusables[focusables.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    },
    destroyed: function () {
      document.removeEventListener("keydown", this._onKeydown);
      if (this._onOverlayClick) {
        this.el.removeEventListener("click", this._onOverlayClick);
      }
      document.body.classList.remove("sg-body-scroll-locked");
      if (this._trigger && document.contains(this._trigger) && this._trigger.focus) {
        this._trigger.focus();
      } else {
        document.body.focus();
      }
    },
  };

  function installCopyDelegate() {
    if (window.__sigraCopyDelegateInstalled) return;
    window.__sigraCopyDelegateInstalled = true;

    document.addEventListener("click", function (event) {
      var target = event.target;
      if (!target || typeof target.closest !== "function") return;
      var code = target.closest(".sg-admin-shell code.sg-code");
      if (!code) return;

      var text = (code.textContent || "").trim();
      if (!text) return;

      var done = function () {
        showToast("Copied");
      };

      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done, function () {});
        }
      } catch (err) {}
    });

    var label = function () {
      var chips = document.querySelectorAll(".sg-admin-shell code.sg-code");
      chips.forEach(function (chip) {
        if (!chip.getAttribute("title")) {
          chip.setAttribute("title", "Click to copy");
        }
      });
    };
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", label);
    } else {
      label();
    }
  }

  function adminShell() {
    return document.querySelector(".sg-admin-shell");
  }

  function installMetricHelp() {
    if (window.__sigraMetricHelpInstalled) return;
    window.__sigraMetricHelpInstalled = true;

    function finePointer() {
      return (
        window.matchMedia &&
        window.matchMedia("(hover: hover) and (pointer: fine)").matches
      );
    }

    // Set when Escape dismisses help; suppresses the synthetic mouseover that
    // Chromium dispatches when hiding the panel collapses layout under a
    // stationary cursor (which would otherwise re-open the help). Cleared on a
    // genuine pointer move so real hover-to-reopen still works.
    var escapeDismissedUntil = 0;
    document.addEventListener(
      "mousemove",
      function () {
        escapeDismissedUntil = 0;
      },
      true,
    );

    function rootFrom(target) {
      return target && target.closest
        ? target.closest("[data-sg-metric-help-root]")
        : null;
    }

    function helpFor(root) {
      var id = root && root.getAttribute("aria-describedby");
      return id ? document.getElementById(id) : null;
    }

    function open(root) {
      var help = helpFor(root);
      if (!root || !help) return;
      help.hidden = false;
      root.dataset.helpOpen = "true";
    }

    function close(root) {
      var help = helpFor(root);
      if (!root || !help) return;
      help.hidden = true;
      delete root.dataset.helpOpen;
      delete root.dataset.helpFocusOpenedAt;
    }

    function closeAll(except) {
      document
        .querySelectorAll('[data-sg-metric-help-root][data-help-open="true"]')
        .forEach(function (root) {
          if (root !== except) close(root);
        });
    }

    function closeRootWhenIdle(root) {
      window.setTimeout(function () {
        if (!root || root.contains(document.activeElement)) return;
        close(root);
      }, 0);
    }

    document.addEventListener("click", function (event) {
      var root = rootFrom(event.target);
      if (root) {
        var alreadyOpen = root.dataset.helpOpen === "true";
        var openedByFocusAt = Number(root.dataset.helpFocusOpenedAt || 0);
        var focusJustOpened =
          alreadyOpen &&
          document.activeElement === root &&
          Date.now() - openedByFocusAt < 350;
        delete root.dataset.helpFocusOpenedAt;
        closeAll(root);
        if (alreadyOpen && !focusJustOpened) {
          close(root);
        } else {
          open(root);
        }
        return;
      }

      closeAll(null);
    });

    document.addEventListener("focusin", function (event) {
      var root = rootFrom(event.target);
      if (!root) return;
      closeAll(root);
      open(root);
      root.dataset.helpFocusOpenedAt = String(Date.now());
    });

    document.addEventListener("focusout", function (event) {
      var root = rootFrom(event.target);
      if (root) closeRootWhenIdle(root);
    });

    document.addEventListener("mouseover", function (event) {
      if (!finePointer()) return;
      if (Date.now() < escapeDismissedUntil) return;
      var root = rootFrom(event.target);
      if (!root) return;
      closeAll(root);
      open(root);
    });

    document.addEventListener("mouseout", function (event) {
      if (!finePointer()) return;
      var root = rootFrom(event.target);
      if (!root || root.contains(event.relatedTarget)) return;
      closeRootWhenIdle(root);
    });

    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape") return;
      escapeDismissedUntil = Date.now() + 400;
      closeAll(null);
    });
  }

  function installFieldHelp() {
    if (window.__sigraFieldHelpInstalled) return;
    window.__sigraFieldHelpInstalled = true;

    function finePointer() {
      return (
        window.matchMedia &&
        window.matchMedia("(hover: hover) and (pointer: fine)").matches
      );
    }

    function rootFrom(target) {
      return target && target.closest
        ? target.closest("[data-sg-field-help-root]")
        : null;
    }

    function triggerFrom(target) {
      return target && target.closest
        ? target.closest("[data-sg-field-help-trigger]")
        : null;
    }

    function triggerFor(root) {
      return root && root.querySelector("[data-sg-field-help-trigger]");
    }

    function helpFor(root) {
      var trigger = triggerFor(root);
      var id = trigger && trigger.getAttribute("aria-controls");
      return id ? document.getElementById(id) : null;
    }

    function open(root) {
      var trigger = triggerFor(root);
      var help = helpFor(root);
      if (!root || !trigger || !help) return;
      help.hidden = false;
      trigger.setAttribute("aria-expanded", "true");
      root.dataset.helpOpen = "true";
    }

    function close(root) {
      var trigger = triggerFor(root);
      var help = helpFor(root);
      if (!root || !trigger || !help) return;
      help.hidden = true;
      trigger.setAttribute("aria-expanded", "false");
      delete root.dataset.helpOpen;
      delete root.dataset.helpFocusOpenedAt;
    }

    function closeAll(except) {
      document
        .querySelectorAll('[data-sg-field-help-root][data-help-open="true"]')
        .forEach(function (root) {
          if (root !== except) close(root);
        });
    }

    function closeRootWhenIdle(root) {
      window.setTimeout(function () {
        if (!root || root.contains(document.activeElement)) return;
        close(root);
      }, 0);
    }

    document.addEventListener("click", function (event) {
      var trigger = triggerFrom(event.target);
      if (trigger) {
        var root = rootFrom(trigger);
        var alreadyOpen = root && root.dataset.helpOpen === "true";
        var openedByFocusAt = Number(
          (root && root.dataset.helpFocusOpenedAt) || 0,
        );
        var focusJustOpened =
          alreadyOpen &&
          document.activeElement === trigger &&
          Date.now() - openedByFocusAt < 350;
        if (root) delete root.dataset.helpFocusOpenedAt;
        closeAll(root);
        if (alreadyOpen && !focusJustOpened) {
          close(root);
        } else {
          open(root);
        }
        return;
      }

      if (!rootFrom(event.target)) closeAll(null);
    });

    document.addEventListener("focusin", function (event) {
      var root = rootFrom(event.target);
      if (!root) return;
      closeAll(root);
      open(root);
      root.dataset.helpFocusOpenedAt = String(Date.now());
    });

    document.addEventListener("focusout", function (event) {
      var root = rootFrom(event.target);
      if (root) closeRootWhenIdle(root);
    });

    document.addEventListener("mouseover", function (event) {
      if (!finePointer()) return;
      var root = rootFrom(event.target);
      if (!root) return;
      closeAll(root);
      open(root);
    });

    document.addEventListener("mouseout", function (event) {
      if (!finePointer()) return;
      var root = rootFrom(event.target);
      if (!root || root.contains(event.relatedTarget)) return;
      closeRootWhenIdle(root);
    });

    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape") return;
      closeAll(null);
    });
  }

  function pageLoadingKind(event) {
    var detail = (event && event.detail) || {};
    return detail.kind || "redirect";
  }

  function routePageLoadingKind(event) {
    return PAGE_LOADING_KINDS[pageLoadingKind(event)] === true;
  }

  function installPageLoadingIndicator() {
    if (window.__sigraPageLoadingIndicatorInstalled) return;
    window.__sigraPageLoadingIndicatorInstalled = true;

    var activeCount = 0;
    var showTimer = null;
    var hideTimer = null;
    var resetTimer = null;
    var failsafeTimer = null;
    var visibleSince = 0;

    function clearShowTimer() {
      if (showTimer) {
        window.clearTimeout(showTimer);
        showTimer = null;
      }
    }

    function clearHideTimer() {
      if (hideTimer) {
        window.clearTimeout(hideTimer);
        hideTimer = null;
      }
    }

    function clearResetTimer() {
      if (resetTimer) {
        window.clearTimeout(resetTimer);
        resetTimer = null;
      }
    }

    function clearFailsafeTimer() {
      if (failsafeTimer) {
        window.clearTimeout(failsafeTimer);
        failsafeTimer = null;
      }
    }

    function setShellBusy(value) {
      document.querySelectorAll(".sg-admin-shell").forEach(function (shell) {
        if (value) {
          shell.setAttribute("aria-busy", "true");
        } else {
          shell.removeAttribute("aria-busy");
        }
      });
    }

    function clearTimers() {
      clearShowTimer();
      clearHideTimer();
      clearResetTimer();
      clearFailsafeTimer();
    }

    function removeLoadingState() {
      document.documentElement.removeAttribute("data-sg-admin-page-loading");
      setShellBusy(false);
      visibleSince = 0;
    }

    function resetLoadingState() {
      activeCount = 0;
      clearTimers();
      removeLoadingState();
    }

    function completeLoadingState() {
      clearTimers();
      activeCount = 0;
      setShellBusy(false);

      if (
        document.documentElement.getAttribute("data-sg-admin-page-loading") ===
        "true"
      ) {
        document.documentElement.dataset.sgAdminPageLoading = "complete";
        resetTimer = window.setTimeout(
          removeLoadingState,
          PAGE_LOADING_FADE_MS,
        );
      } else {
        removeLoadingState();
      }
    }

    function startFailsafeTimer() {
      clearFailsafeTimer();
      failsafeTimer = window.setTimeout(
        resetLoadingState,
        PAGE_LOADING_MAX_ACTIVE_MS,
      );
    }

    function show() {
      showTimer = null;
      if (activeCount <= 0 || !adminShell()) return;
      visibleSince = Date.now();
      document.documentElement.dataset.sgAdminPageLoading = "true";
      setShellBusy(true);
    }

    function scheduleHide() {
      if (
        !document.documentElement.hasAttribute("data-sg-admin-page-loading")
      ) {
        completeLoadingState();
        return;
      }

      var elapsed = Date.now() - visibleSince;
      var remaining = Math.max(PAGE_LOADING_MIN_VISIBLE_MS - elapsed, 0);
      if (remaining > 0) {
        hideTimer = window.setTimeout(completeLoadingState, remaining);
      } else {
        completeLoadingState();
      }
    }

    window.addEventListener("phx:page-loading-start", function (event) {
      if (pageLoadingKind(event) === "error") {
        resetLoadingState();
        return;
      }
      if (!routePageLoadingKind(event) || !adminShell()) return;

      activeCount += 1;
      clearHideTimer();
      clearResetTimer();
      setShellBusy(true);
      startFailsafeTimer();

      if (
        document.documentElement.getAttribute("data-sg-admin-page-loading") ===
        "complete"
      ) {
        document.documentElement.removeAttribute("data-sg-admin-page-loading");
      }

      if (
        !showTimer &&
        document.documentElement.getAttribute("data-sg-admin-page-loading") !==
          "true"
      ) {
        showTimer = window.setTimeout(show, PAGE_LOADING_DELAY_MS);
      }
    });

    window.addEventListener("phx:page-loading-stop", function (event) {
      if (pageLoadingKind(event) === "error") {
        resetLoadingState();
        return;
      }
      if (!routePageLoadingKind(event)) return;

      activeCount = Math.max(activeCount - 1, 0);
      if (activeCount === 0) {
        scheduleHide();
      }
    });

    window.addEventListener("pagehide", function () {
      resetLoadingState();
    });

    window.addEventListener("pageshow", function (event) {
      if (event.persisted) {
        resetLoadingState();
      }
    });
  }

  var CopyToClipboard = {
    mounted: function () {
      installCopyDelegate();
    },
  };

  function authBrandingColorInput(target) {
    return target && typeof target.closest === "function"
      ? target.closest("[data-sg-auth-branding-color]")
      : null;
  }

  function applyAuthBrandingColor(form, input) {
    var name = input && input.dataset.sgAuthBrandingColor;
    var property = AUTH_BRANDING_COLOR_TOKENS[name];
    var value = String((input && input.value) || "")
      .trim()
      .toLowerCase();
    if (!property || !AUTH_BRANDING_HEX.test(value)) return;

    form
      .querySelectorAll("[data-sg-auth-branding-preview]")
      .forEach(function (preview) {
        preview.style.setProperty(property, value);
      });

    var field = input.closest(".sg-color-field");
    var label =
      field && field.querySelector("[data-sg-auth-branding-color-value]");
    if (label) {
      label.textContent = value;
    }
  }

  function applyAuthBrandingColors(form) {
    form
      .querySelectorAll("[data-sg-auth-branding-color]")
      .forEach(function (input) {
        applyAuthBrandingColor(form, input);
      });
  }

  var AuthBrandingPreview = {
    mounted: function () {
      var self = this;

      this._onInputCapture = function (event) {
        var input = authBrandingColorInput(event.target);
        if (!input || !self.el.contains(input)) return;
        applyAuthBrandingColor(self.el, input);
        event.stopPropagation();
      };
      this._onChange = function (event) {
        var input = authBrandingColorInput(event.target);
        if (!input || !self.el.contains(input)) return;
        applyAuthBrandingColor(self.el, input);
      };

      this.el.addEventListener("input", this._onInputCapture, true);
      this.el.addEventListener("change", this._onChange);
      applyAuthBrandingColors(this.el);
    },

    updated: function () {
      applyAuthBrandingColors(this.el);
    },

    destroyed: function () {
      if (this.el && this._onInputCapture) {
        this.el.removeEventListener("input", this._onInputCapture, true);
      }
      if (this.el && this._onChange) {
        this.el.removeEventListener("change", this._onChange);
      }
    },
  };

  var ThemeSwitch = {
    mounted: function () {
      var self = this;
      this.buttons = Array.prototype.slice.call(
        this.el.querySelectorAll("[data-theme-value]"),
      );
      this._onClick = function (event) {
        var button = event.target.closest("[data-theme-value]");
        if (!button || self.buttons.indexOf(button) === -1) return;
        event.preventDefault();
        self.setTheme(button.dataset.themeValue || "system", true);
      };
      this.el.addEventListener("click", this._onClick);
      this._onKeydown = function (event) {
        self.handleKeydown(event);
      };
      this.el.addEventListener("keydown", this._onKeydown);
      this._onStorage = function (event) {
        if (event.key === THEME_STORAGE_KEY) {
          self.setTheme(storedTheme(), false);
        }
      };
      window.addEventListener("storage", this._onStorage);
      this.setTheme(storedTheme(), false);
    },

    setTheme: function (value, persist) {
      var theme = applyTheme(value);
      if (persist) {
        try {
          if (theme === "system") {
            window.localStorage.removeItem(THEME_STORAGE_KEY);
          } else {
            window.localStorage.setItem(THEME_STORAGE_KEY, theme);
          }
        } catch (err) {}
      }
      this.buttons.forEach(function (button) {
        var selected = button.dataset.themeValue === theme;
        button.setAttribute("aria-checked", selected ? "true" : "false");
        button.setAttribute("tabindex", selected ? "0" : "-1");
        button.classList.toggle("is-active", selected);
      });
    },

    handleKeydown: function (event) {
      var currentIndex = this.buttons.indexOf(document.activeElement);
      if (currentIndex === -1) return;
      var key = event.key;
      var nextIndex = currentIndex;
      if (key === "ArrowRight" || key === "ArrowDown") {
        nextIndex = (currentIndex + 1) % this.buttons.length;
      } else if (key === "ArrowLeft" || key === "ArrowUp") {
        nextIndex =
          (currentIndex - 1 + this.buttons.length) % this.buttons.length;
      } else if (key === "Home") {
        nextIndex = 0;
      } else if (key === "End") {
        nextIndex = this.buttons.length - 1;
      } else if (key === " " || key === "Enter") {
        event.preventDefault();
        this.setTheme(
          document.activeElement.dataset.themeValue || "system",
          true,
        );
        return;
      } else {
        return;
      }
      event.preventDefault();
      var next = this.buttons[nextIndex];
      next.focus();
      this.setTheme(next.dataset.themeValue || "system", true);
    },

    destroyed: function () {
      if (this.el && this._onClick) {
        this.el.removeEventListener("click", this._onClick);
      }
      if (this.el && this._onKeydown) {
        this.el.removeEventListener("keydown", this._onKeydown);
      }
      if (this._onStorage) {
        window.removeEventListener("storage", this._onStorage);
      }
    },
  };

  installCopyDelegate();
  installMetricHelp();
  installFieldHelp();
  installPageLoadingIndicator();

  window.SigraAdminHooks = {
    AuthBrandingPreview: AuthBrandingPreview,
    CmdK: CmdK,
    ConfirmDialog: ConfirmDialog,
    CopyToClipboard: CopyToClipboard,
    ThemeSwitch: ThemeSwitch,
  };
})();
// Sigra admin hooks:end

// LiveSocket initializer
(function () {
  var csrfMeta = document.querySelector("meta[name='csrf-token']");
  var csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : null;
  var passkeyRuntime = window.SigraPasskeyRuntime || {};
  var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
    longPollFallbackMs: 2500,
    hooks: {
      PasskeyRegister: passkeyRuntime.PasskeyRegister,
      PasskeyAuthenticate: passkeyRuntime.PasskeyAuthenticate,
      AuthBrandingPreview: (window.SigraAdminHooks || {}).AuthBrandingPreview,
      CmdK: (window.SigraAdminHooks || {}).CmdK,
      ConfirmDialog: (window.SigraAdminHooks || {}).ConfirmDialog,
      CopyToClipboard: (window.SigraAdminHooks || {}).CopyToClipboard,
      ThemeSwitch: (window.SigraAdminHooks || {}).ThemeSwitch,
    },
    params: { _csrf_token: csrfToken },
  });
  liveSocket.connect();
  window.liveSocket = liveSocket;
})();

// Handle flash close
document.querySelectorAll("[role=alert][data-flash]").forEach(function (el) {
  el.addEventListener("click", function () {
    el.setAttribute("hidden", "");
  });
});
