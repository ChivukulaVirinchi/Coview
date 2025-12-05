/**
 * CoView Extension Popup
 * Handles UI for starting/stopping screen sharing
 */

// DOM Elements
const notSharingState = document.getElementById('not-sharing');
const sharingState = document.getElementById('sharing');
const roomCodeInput = document.getElementById('room-code');
const serverUrlInput = document.getElementById('server-url');
const generateCodeBtn = document.getElementById('generate-code');
const startSharingBtn = document.getElementById('start-sharing');
const stopSharingBtn = document.getElementById('stop-sharing');
const currentRoomSpan = document.getElementById('current-room');
const viewerCountSpan = document.getElementById('viewer-count');
const shareUrlInput = document.getElementById('share-url');
const copyLinkBtn = document.getElementById('copy-link');
const connectionStatus = document.getElementById('connection-status');

// State
let isSharing = false;

// Initialize popup
async function init() {
  // Load saved settings
  const settings = await chrome.storage.local.get(['serverUrl', 'roomCode', 'isSharing']);
  
  if (settings.serverUrl) {
    serverUrlInput.value = settings.serverUrl;
  }
  
  if (settings.roomCode) {
    roomCodeInput.value = settings.roomCode;
  }

  // Check if currently sharing
  if (settings.isSharing) {
    isSharing = true;
    showSharingState(settings.roomCode, settings.serverUrl);
    updateConnectionStatus('connected');
  }

  // Get current tab info for context
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab) {
    console.log('Current tab:', tab.url);
  }
}

// Generate random room code
function generateRoomCode() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// Show sharing state UI
function showSharingState(roomCode, serverUrl) {
  notSharingState.classList.add('hidden');
  sharingState.classList.remove('hidden');
  
  currentRoomSpan.textContent = roomCode;
  const shareUrl = `${serverUrl}/room/${roomCode}`;
  shareUrlInput.value = shareUrl;
}

// Show not sharing state UI
function showNotSharingState() {
  sharingState.classList.add('hidden');
  notSharingState.classList.remove('hidden');
}

// Update connection status
function updateConnectionStatus(status, message) {
  connectionStatus.className = `connection-status ${status}`;
  const statusText = connectionStatus.querySelector('.status-text');
  
  switch (status) {
    case 'connected':
      statusText.textContent = 'Connected';
      break;
    case 'connecting':
      statusText.textContent = message || 'Connecting...';
      break;
    case 'error':
      statusText.textContent = message || 'Connection error';
      break;
    default:
      statusText.textContent = 'Disconnected';
  }
}

// Start sharing
async function startSharing() {
  let roomCode = roomCodeInput.value.trim();
  const serverUrl = serverUrlInput.value.trim();

  if (!roomCode) {
    roomCode = generateRoomCode();
    roomCodeInput.value = roomCode;
  }

  if (!serverUrl) {
    alert('Please enter a server URL');
    return;
  }

  updateConnectionStatus('connecting');

  // Save settings
  await chrome.storage.local.set({
    serverUrl,
    roomCode,
    isSharing: true
  });

  // Send message to background script to start sharing
  try {
    const response = await chrome.runtime.sendMessage({
      type: 'START_SHARING',
      roomCode,
      serverUrl
    });

    if (response && response.success) {
      isSharing = true;
      showSharingState(roomCode, serverUrl);
      updateConnectionStatus('connected');
    } else {
      updateConnectionStatus('error', response?.error || 'Failed to start sharing');
    }
  } catch (error) {
    console.error('Error starting sharing:', error);
    updateConnectionStatus('error', 'Failed to connect');
  }
}

// Stop sharing
async function stopSharing() {
  // Send message to background script to stop sharing
  try {
    await chrome.runtime.sendMessage({ type: 'STOP_SHARING' });
  } catch (error) {
    console.error('Error stopping sharing:', error);
  }

  // Update storage
  await chrome.storage.local.set({ isSharing: false });

  isSharing = false;
  showNotSharingState();
  updateConnectionStatus('disconnected');
}

// Copy share link to clipboard
async function copyShareLink() {
  const url = shareUrlInput.value;
  
  try {
    await navigator.clipboard.writeText(url);
    
    // Visual feedback
    const originalSvg = copyLinkBtn.innerHTML;
    copyLinkBtn.innerHTML = `
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <polyline points="20 6 9 17 4 12"/>
      </svg>
    `;
    copyLinkBtn.style.color = 'var(--success)';
    
    setTimeout(() => {
      copyLinkBtn.innerHTML = originalSvg;
      copyLinkBtn.style.color = '';
    }, 2000);
  } catch (error) {
    console.error('Failed to copy:', error);
  }
}

// Event listeners
generateCodeBtn.addEventListener('click', () => {
  roomCodeInput.value = generateRoomCode();
});

startSharingBtn.addEventListener('click', startSharing);
stopSharingBtn.addEventListener('click', stopSharing);
copyLinkBtn.addEventListener('click', copyShareLink);

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message) => {
  if (message.type === 'VIEWER_COUNT_UPDATE') {
    viewerCountSpan.textContent = message.count;
  } else if (message.type === 'CONNECTION_STATUS') {
    updateConnectionStatus(message.status, message.message);
  }
});

// Initialize
init();
