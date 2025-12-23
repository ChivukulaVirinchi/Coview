/**
 * CoView Extension Background Service Worker
 * Manages WebSocket connection to Phoenix server
 */

import { Socket } from './phoenix.js';

// State
let socket = null;
let channel = null;
let isSharing = false;
let currentRoomCode = null;
let currentServerUrl = null;
let activeTabId = null;

// Listen for messages from popup and content scripts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log('Background received message:', message.type);

  switch (message.type) {
    case 'START_SHARING':
      startSharing(message.roomCode, message.serverUrl)
        .then(() => sendResponse({ success: true }))
        .catch((error) => {
          console.error('Start sharing error:', error);
          sendResponse({ success: false, error: error.message });
        });
      return true; // Will respond asynchronously

    case 'STOP_SHARING':
      stopSharing();
      sendResponse({ success: true });
      break;

    case 'DOM_UPDATE':
      if (channel && isSharing) {
        console.log('Sending DOM update, size:', message.html?.length || 0, 'fullPage:', message.isFullPage);
        channel.push('dom_full', { 
          html: message.html,
          viewport_width: message.viewportWidth,
          viewport_height: message.viewportHeight,
          is_full_page: message.isFullPage !== false // default to true for backwards compat
        })
          .receive('ok', () => console.log('DOM sent successfully'))
          .receive('error', (err) => console.error('DOM send error:', err))
          .receive('timeout', () => console.error('DOM send timeout'));
      } else {
        console.warn('Cannot send DOM: channel=', !!channel, 'isSharing=', isSharing);
      }
      break;

    case 'CURSOR_MOVE':
      if (channel && isSharing) {
        channel.push('cursor_move', message.position);
      }
      break;

    case 'SCROLL':
      if (channel && isSharing) {
        channel.push('scroll', message.position);
      }
      break;

    case 'CLICK':
      if (channel && isSharing) {
        channel.push('click', message.position);
      }
      break;

    case 'NAVIGATION':
      if (channel && isSharing) {
        channel.push('navigation', { url: message.url });
      }
      break;

    case 'GET_STATUS':
      sendResponse({
        isSharing,
        roomCode: currentRoomCode,
        serverUrl: currentServerUrl
      });
      break;
  }
});

// Start sharing session
async function startSharing(roomCode, serverUrl) {
  console.log('Starting sharing:', roomCode, serverUrl);
  
  currentRoomCode = roomCode;
  currentServerUrl = serverUrl;

  // Get active tab
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab) {
    throw new Error('No active tab found');
  }
  activeTabId = tab.id;

  // Connect to Phoenix socket
  await connectToServer(serverUrl, roomCode);

  isSharing = true;

  // Notify content script to start capturing
  try {
    await chrome.tabs.sendMessage(activeTabId, { type: 'START_CAPTURE' });
    console.log('CoView: Content script responded, capture started');
  } catch (error) {
    console.log('CoView: Content script not ready, injecting it now...');
    // Content script might not be injected yet, inject it manually
    try {
      await chrome.scripting.executeScript({
        target: { tabId: activeTabId },
        files: ['content.js']
      });
      console.log('CoView: Content script injected, starting capture...');
      // Wait a moment for script to initialize, then start capture
      await new Promise(resolve => setTimeout(resolve, 100));
      await chrome.tabs.sendMessage(activeTabId, { type: 'START_CAPTURE' });
      console.log('CoView: Capture started after injection');
    } catch (injectError) {
      console.error('CoView: Failed to inject content script:', injectError);
      // This might be a chrome:// page or other restricted page
      throw new Error('Cannot share this page. Try a regular website.');
    }
  }

  // Store state
  await chrome.storage.local.set({ isSharing: true, roomCode, serverUrl });

  // Notify popup of connection status
  notifyPopup('CONNECTION_STATUS', { status: 'connected' });
}

// Stop sharing session
function stopSharing() {
  console.log('Stopping sharing');
  
  isSharing = false;

  // Notify content script to stop capturing
  if (activeTabId) {
    chrome.tabs.sendMessage(activeTabId, { type: 'STOP_CAPTURE' }).catch(() => {});
  }

  // Disconnect from server
  if (channel) {
    channel.leave();
    channel = null;
  }
  if (socket) {
    socket.disconnect();
    socket = null;
  }

  currentRoomCode = null;
  currentServerUrl = null;
  activeTabId = null;

  // Update storage
  chrome.storage.local.set({ isSharing: false });

  // Notify popup
  notifyPopup('CONNECTION_STATUS', { status: 'disconnected' });
}

// Connect to Phoenix WebSocket server
function connectToServer(serverUrl, roomCode) {
  return new Promise((resolve, reject) => {
    // Convert HTTP URL to WebSocket URL
    const wsUrl = serverUrl.replace(/^http/, 'ws') + '/socket/websocket';
    console.log('CoView: Connecting to Phoenix at:', wsUrl);

    try {
      // Create Phoenix socket
      socket = new Socket(wsUrl, {
        timeout: 10000,
        heartbeatIntervalMs: 30000
      });
      console.log('CoView: Socket object created');

    // Set up socket event handlers
    socket.onOpen(() => {
      console.log('CoView: Socket connected! Joining channel...');
      joinChannel(roomCode, resolve, reject);
    });

    socket.onClose((event) => {
      console.log('CoView: Socket closed:', event.code, event.reason);
      notifyPopup('CONNECTION_STATUS', { status: 'disconnected', message: 'Connection lost' });
    });

    socket.onError((error) => {
      console.error('CoView: Socket error:', error);
      notifyPopup('CONNECTION_STATUS', { status: 'error', message: 'Connection error' });
      reject(new Error('Failed to connect to server'));
    });

    // Connect
    console.log('CoView: Calling socket.connect()...');
    socket.connect();
    console.log('CoView: socket.connect() called');
  } catch (err) {
    console.error('CoView: Exception during connection setup:', err);
    reject(err);
  }
  });
}

// Join the room channel
function joinChannel(roomCode, resolve, reject) {
  const userId = generateUserId();
  console.log('CoView: Creating channel for room:', roomCode, 'user:', userId);
  
  channel = socket.channel(`room:${roomCode}`, {
    role: 'leader',
    user_id: userId
  });

  console.log('CoView: Calling channel.join()...');
  channel.join()
    .receive('ok', (response) => {
      console.log('CoView: Joined channel successfully:', response);
      notifyPopup('CONNECTION_STATUS', { status: 'connected' });
      resolve();
    })
    .receive('error', (response) => {
      console.error('CoView: Failed to join channel:', response);
      notifyPopup('CONNECTION_STATUS', { status: 'error', message: 'Failed to join room' });
      reject(new Error('Failed to join room'));
    })
    .receive('timeout', () => {
      console.error('CoView: Join timeout');
      notifyPopup('CONNECTION_STATUS', { status: 'error', message: 'Connection timeout' });
      reject(new Error('Connection timeout'));
    });

  // Listen for presence updates
  channel.on('presence_state', (state) => {
    console.log('Presence state:', state);
    updateViewerCount(state);
  });

  channel.on('presence_diff', (diff) => {
    console.log('Presence diff:', diff);
    // Could track viewer count here if needed
  });
}

// Generate unique user ID
function generateUserId() {
  const array = new Uint8Array(8);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

// Update viewer count in popup
function updateViewerCount(presenceState) {
  const count = Object.keys(presenceState).length;
  notifyPopup('VIEWER_COUNT_UPDATE', { count });
}

// Send message to popup
function notifyPopup(type, data) {
  chrome.runtime.sendMessage({ type, ...data }).catch(() => {
    // Popup might not be open, that's okay
  });
}

// Listen for tab updates to handle navigation
chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (isSharing && tabId === activeTabId && changeInfo.status === 'complete') {
    console.log('CoView: Tab navigated, re-capturing DOM');
    try {
      await chrome.tabs.sendMessage(tabId, { type: 'START_CAPTURE' });
    } catch (error) {
      // Content script lost after navigation, re-inject
      console.log('CoView: Re-injecting content script after navigation');
      try {
        await chrome.scripting.executeScript({
          target: { tabId },
          files: ['content.js']
        });
        await new Promise(resolve => setTimeout(resolve, 100));
        await chrome.tabs.sendMessage(tabId, { type: 'START_CAPTURE' });
      } catch (injectError) {
        console.error('CoView: Failed to re-inject content script:', injectError);
      }
    }
  }
});

// Listen for tab close
chrome.tabs.onRemoved.addListener((tabId) => {
  if (isSharing && tabId === activeTabId) {
    console.log('Active tab closed, stopping sharing');
    stopSharing();
  }
});

// Restore state on service worker startup
chrome.storage.local.get(['isSharing', 'roomCode', 'serverUrl']).then((settings) => {
  if (settings.isSharing && settings.roomCode && settings.serverUrl) {
    console.log('Restoring sharing session:', settings.roomCode);
    // Note: We can't fully restore without knowing the active tab
    // For now, just clear the state
    chrome.storage.local.set({ isSharing: false });
  }
});

console.log('CoView background service worker loaded');
