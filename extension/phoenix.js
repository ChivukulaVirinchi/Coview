/**
 * Phoenix Socket Client for Browser Extension
 * Minimal implementation of Phoenix Channels protocol
 * Based on phoenix.js but simplified for extension use
 */

const VSN = "2.0.0";
const SOCKET_STATES = { connecting: 0, open: 1, closing: 2, closed: 3 };
const CHANNEL_STATES = { closed: "closed", errored: "errored", joined: "joined", joining: "joining", leaving: "leaving" };
const CHANNEL_EVENTS = { close: "phx_close", error: "phx_error", join: "phx_join", reply: "phx_reply", leave: "phx_leave" };

// Serializer
const serializer = {
  encode(msg, callback) {
    const payload = [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload];
    callback(JSON.stringify(payload));
  },
  decode(rawPayload, callback) {
    const [join_ref, ref, topic, event, payload] = JSON.parse(rawPayload);
    callback({ join_ref, ref, topic, event, payload });
  }
};

/**
 * Push - represents a message push to the server
 */
class Push {
  constructor(channel, event, payload, timeout) {
    this.channel = channel;
    this.event = event;
    this.payload = payload || {};
    this.timeout = timeout;
    this.receivedResp = null;
    this.timeoutTimer = null;
    this.recHooks = [];
    this.sent = false;
    this.ref = null;
  }

  resend(timeout) {
    this.timeout = timeout;
    this.reset();
    this.send();
  }

  send() {
    if (this.hasReceived("timeout")) return;
    this.startTimeout();
    this.sent = true;
    this.ref = this.channel.socket.makeRef();
    console.log("Push.send:", { event: this.event, ref: this.ref, topic: this.channel.topic });
    this.channel.socket.push({
      topic: this.channel.topic,
      event: this.event,
      payload: this.payload,
      ref: this.ref,
      join_ref: this.channel.joinRef()
    });
  }

  receive(status, callback) {
    if (this.hasReceived(status)) {
      callback(this.receivedResp.response);
    }
    this.recHooks.push({ status, callback });
    return this;
  }

  reset() {
    this.cancelTimeout();
    this.receivedResp = null;
    this.sent = false;
  }

  matchReceive({ status, response }) {
    this.recHooks.filter(h => h.status === status).forEach(h => h.callback(response));
  }

  cancelTimeout() {
    clearTimeout(this.timeoutTimer);
    this.timeoutTimer = null;
  }

  startTimeout() {
    if (this.timeoutTimer) return;
    this.timeoutTimer = setTimeout(() => {
      this.trigger("timeout", {});
    }, this.timeout);
  }

  hasReceived(status) {
    return this.receivedResp && this.receivedResp.status === status;
  }

  trigger(status, response) {
    this.receivedResp = { status, response };
    this.matchReceive({ status, response });
  }
}

/**
 * Channel - represents a Phoenix channel
 */
class Channel {
  constructor(topic, params, socket) {
    this.topic = topic;
    this.params = params || {};
    this.socket = socket;
    this.state = CHANNEL_STATES.closed;
    this.bindings = [];
    this.bindingRef = 0;
    this.joinedOnce = false;
    this.joinPush = new Push(this, CHANNEL_EVENTS.join, this.params, socket.timeout);
    this.pushBuffer = [];
    this.rejoinTimer = null;

    this.joinPush.receive("ok", () => {
      this.state = CHANNEL_STATES.joined;
      this.pushBuffer.forEach(push => push.send());
      this.pushBuffer = [];
    });

    this.joinPush.receive("error", () => {
      this.state = CHANNEL_STATES.errored;
    });

    this.joinPush.receive("timeout", () => {
      if (this.state === CHANNEL_STATES.joining) {
        this.state = CHANNEL_STATES.errored;
      }
    });

    this.onClose(() => {
      this.state = CHANNEL_STATES.closed;
      this.socket.remove(this);
    });

    this.onError(() => {
      this.state = CHANNEL_STATES.errored;
    });
  }

  join(timeout = this.socket.timeout) {
    if (this.joinedOnce) {
      throw new Error("tried to join multiple times");
    }
    this.joinedOnce = true;
    this.rejoin(timeout);
    return this.joinPush;
  }

  rejoin(timeout = this.socket.timeout) {
    if (this.state === CHANNEL_STATES.leaving) return;
    this.state = CHANNEL_STATES.joining;
    this.joinPush.resend(timeout);
  }

  leave(timeout = this.socket.timeout) {
    this.state = CHANNEL_STATES.leaving;
    const leavePush = new Push(this, CHANNEL_EVENTS.leave, {}, timeout);
    leavePush.receive("ok", () => this.trigger(CHANNEL_EVENTS.close, "leave"));
    leavePush.receive("timeout", () => this.trigger(CHANNEL_EVENTS.close, "leave"));
    leavePush.send();
    if (!this.canPush()) {
      leavePush.trigger("ok", {});
    }
    return leavePush;
  }

  onClose(callback) {
    this.on(CHANNEL_EVENTS.close, callback);
  }

  onError(callback) {
    this.on(CHANNEL_EVENTS.error, callback);
  }

  on(event, callback) {
    const ref = this.bindingRef++;
    this.bindings.push({ event, ref, callback });
    return ref;
  }

  off(event, ref) {
    this.bindings = this.bindings.filter(bind => {
      return !(bind.event === event && (ref === undefined || ref === bind.ref));
    });
  }

  push(event, payload, timeout = this.socket.timeout) {
    if (!this.joinedOnce) {
      throw new Error(`tried to push '${event}' to '${this.topic}' before joining`);
    }
    const push = new Push(this, event, payload, timeout);
    if (this.canPush()) {
      push.send();
    } else {
      push.startTimeout();
      this.pushBuffer.push(push);
    }
    return push;
  }

  canPush() {
    return this.socket.isConnected() && this.state === CHANNEL_STATES.joined;
  }

  joinRef() {
    return this.joinPush.ref;
  }

  trigger(event, payload, ref, joinRef) {
    console.log("Channel.trigger:", { event, ref, joinRef, myJoinRef: this.joinRef() });
    const handledPayload = this.onMessage(event, payload, ref, joinRef);
    if (payload && !handledPayload) {
      throw new Error("channel onMessage callbacks must return payload");
    }

    // For phx_reply, we need to match by ref, not just event
    if (event === "phx_reply" && ref) {
      console.log("Channel: Processing phx_reply, looking for Push with ref:", ref);
      // Check if this is the join reply
      if (ref === this.joinPush.ref) {
        console.log("Channel: This is the JOIN reply! Status:", payload?.status);
        // Cancel the timeout before triggering
        this.joinPush.cancelTimeout();
        this.joinPush.trigger(payload?.status, payload?.response || {});
        return;
      }
    }

    this.bindings.filter(bind => bind.event === event).forEach(bind => {
      bind.callback(handledPayload, ref, joinRef || this.joinRef());
    });
  }

  onMessage(_event, payload, _ref, _joinRef) {
    return payload;
  }

  isMember(topic, event, payload, joinRef) {
    if (this.topic !== topic) return false;
    if (joinRef && joinRef !== this.joinRef()) {
      return false;
    }
    return true;
  }
}

/**
 * Socket - represents a WebSocket connection to Phoenix
 */
class Socket {
  constructor(endPoint, opts = {}) {
    this.endPoint = endPoint;
    this.timeout = opts.timeout || 10000;
    this.heartbeatIntervalMs = opts.heartbeatIntervalMs || 30000;
    this.reconnectAfterMs = opts.reconnectAfterMs || function(tries) {
      return [1000, 2000, 5000, 10000][tries - 1] || 10000;
    };
    this.params = opts.params || {};

    this.channels = [];
    this.sendBuffer = [];
    this.ref = 0;
    this.conn = null;
    this.heartbeatTimer = null;
    this.pendingHeartbeatRef = null;
    this.reconnectTimer = null;
    this.reconnectTries = 0;

    this.stateChangeCallbacks = { open: [], close: [], error: [], message: [] };
  }

  endPointURL() {
    let url = this.endPoint;
    // Add vsn parameter
    const params = { ...this.params, vsn: VSN };
    const queryString = Object.entries(params)
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join("&");
    url += (url.includes("?") ? "&" : "?") + queryString;
    return url;
  }

  connect() {
    if (this.conn) {
      console.log("Phoenix Socket: Already connected");
      return;
    }

    const url = this.endPointURL();
    console.log("Phoenix Socket: Creating WebSocket to:", url);

    try {
      this.conn = new WebSocket(url);
      console.log("Phoenix Socket: WebSocket object created, readyState:", this.conn.readyState);
    } catch (err) {
      console.error("Phoenix Socket: Failed to create WebSocket:", err);
      this.stateChangeCallbacks.error.forEach(cb => cb(err));
      return;
    }

    this.conn.onopen = () => {
      console.log("Phoenix Socket: WebSocket onopen fired");
      this.reconnectTries = 0;
      this.flushSendBuffer();
      this.resetHeartbeat();
      this.stateChangeCallbacks.open.forEach(cb => cb());
    };

    this.conn.onclose = (event) => {
      console.log("Phoenix Socket: WebSocket onclose fired, code:", event.code, "reason:", event.reason);
      this.triggerChanError();
      clearInterval(this.heartbeatTimer);
      this.scheduleReconnect();
      this.stateChangeCallbacks.close.forEach(cb => cb(event));
    };

    this.conn.onerror = (error) => {
      console.log("Phoenix Socket: WebSocket onerror fired", error);
      this.triggerChanError();
      this.stateChangeCallbacks.error.forEach(cb => cb(error));
    };

    this.conn.onmessage = (event) => {
      console.log("Phoenix Socket: Raw message received:", event.data);
      serializer.decode(event.data, (msg) => {
        const { topic, event: msgEvent, payload, ref, join_ref } = msg;
        console.log("Phoenix Socket: Decoded message:", { topic, event: msgEvent, ref, join_ref, payloadKeys: Object.keys(payload || {}) });

        if (ref === this.pendingHeartbeatRef) {
          this.pendingHeartbeatRef = null;
        }

        // Check for phx_reply specifically
        if (msgEvent === "phx_reply") {
          console.log("Phoenix Socket: Got phx_reply, status:", payload?.status, "ref:", ref);
        }

        const matchingChannels = this.channels.filter(ch => ch.isMember(topic, msgEvent, payload, join_ref));
        console.log("Phoenix Socket: Matching channels:", matchingChannels.length);
        
        matchingChannels.forEach(ch => {
          ch.trigger(msgEvent, payload, ref, join_ref);
        });

        this.stateChangeCallbacks.message.forEach(cb => cb(msg));
      });
    };
  }

  disconnect(callback, code, reason) {
    if (this.conn) {
      this.conn.onclose = () => {};
      if (code) {
        this.conn.close(code, reason || "");
      } else {
        this.conn.close();
      }
      this.conn = null;
    }
    callback && callback();
  }

  onOpen(callback) {
    this.stateChangeCallbacks.open.push(callback);
  }

  onClose(callback) {
    this.stateChangeCallbacks.close.push(callback);
  }

  onError(callback) {
    this.stateChangeCallbacks.error.push(callback);
  }

  onMessage(callback) {
    this.stateChangeCallbacks.message.push(callback);
  }

  channel(topic, chanParams = {}) {
    const chan = new Channel(topic, chanParams, this);
    this.channels.push(chan);
    return chan;
  }

  remove(channel) {
    this.channels = this.channels.filter(c => c !== channel);
  }

  push(data) {
    if (this.isConnected()) {
      serializer.encode(data, (result) => {
        this.conn.send(result);
      });
    } else {
      this.sendBuffer.push(() => {
        serializer.encode(data, (result) => {
          this.conn.send(result);
        });
      });
    }
  }

  makeRef() {
    const newRef = this.ref + 1;
    this.ref = newRef === this.ref ? 0 : newRef;
    return this.ref.toString();
  }

  isConnected() {
    return this.conn && this.conn.readyState === SOCKET_STATES.open;
  }

  flushSendBuffer() {
    if (this.isConnected()) {
      this.sendBuffer.forEach(cb => cb());
      this.sendBuffer = [];
    }
  }

  triggerChanError() {
    this.channels.forEach(ch => {
      if (ch.state !== CHANNEL_STATES.closed) {
        ch.trigger(CHANNEL_EVENTS.error);
      }
    });
  }

  resetHeartbeat() {
    clearInterval(this.heartbeatTimer);
    this.heartbeatTimer = setInterval(() => this.sendHeartbeat(), this.heartbeatIntervalMs);
  }

  sendHeartbeat() {
    if (!this.isConnected()) return;
    if (this.pendingHeartbeatRef) {
      this.pendingHeartbeatRef = null;
      console.log("heartbeat timeout, closing socket");
      this.conn.close(1000, "hearbeat timeout");
      return;
    }
    this.pendingHeartbeatRef = this.makeRef();
    this.push({ topic: "phoenix", event: "heartbeat", payload: {}, ref: this.pendingHeartbeatRef });
  }

  scheduleReconnect() {
    clearTimeout(this.reconnectTimer);
    this.reconnectTries++;
    const delay = this.reconnectAfterMs(this.reconnectTries);
    console.log(`Scheduling reconnect in ${delay}ms (attempt ${this.reconnectTries})`);
    this.reconnectTimer = setTimeout(() => {
      this.conn = null;
      this.connect();
    }, delay);
  }
}

// Export for use in extension
export { Socket, Channel, Push };
