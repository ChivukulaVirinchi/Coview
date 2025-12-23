/**
 * CoView Extension Content Script
 * Injected into web pages to capture DOM and track user interactions
 */

// State
let isCapturing = false;
let lastDomSnapshot = null;

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log('Content script received:', message.type);

  switch (message.type) {
    case 'START_CAPTURE':
      startCapturing();
      sendResponse({ success: true });
      break;

    case 'STOP_CAPTURE':
      stopCapturing();
      sendResponse({ success: true });
      break;

    case 'GET_DOM':
      const dom = captureDOM();
      sendResponse({ html: dom });
      break;
  }
});

// Start capturing DOM and events
function startCapturing() {
  if (isCapturing) return;
  
  console.log('CoView: Starting capture');
  isCapturing = true;

  // Capture initial DOM
  sendDOMUpdate();

  // Set up event listeners
  setupEventListeners();

  // Set up mutation observer
  setupMutationObserver();
}

// Stop capturing
function stopCapturing() {
  if (!isCapturing) return;
  
  console.log('CoView: Stopping capture');
  isCapturing = false;

  // Remove event listeners
  removeEventListeners();

  // Disconnect mutation observer
  if (mutationObserver) {
    mutationObserver.disconnect();
    mutationObserver = null;
  }
}

// Capture and sanitize DOM
function captureDOM() {
  // Clone the entire document
  const clone = document.documentElement.cloneNode(true);

  // Strip sensitive data
  stripSensitiveData(clone);

  // Remove scripts (they shouldn't execute on follower side)
  clone.querySelectorAll('script').forEach(el => el.remove());

  // Remove noscript tags
  clone.querySelectorAll('noscript').forEach(el => el.remove());

  // Convert relative URLs to absolute
  convertToAbsoluteUrls(clone);

  // Add base tag for proper resource loading
  const baseTag = document.createElement('base');
  baseTag.href = window.location.origin;
  const head = clone.querySelector('head');
  if (head) {
    head.insertBefore(baseTag, head.firstChild);
  }

  return '<!DOCTYPE html>' + clone.outerHTML;
}

// Strip sensitive data from cloned DOM
function stripSensitiveData(root) {
  // Clear password fields
  root.querySelectorAll('input[type="password"]').forEach(el => {
    el.value = '';
    el.setAttribute('value', '');
  });

  // Clear common sensitive fields
  root.querySelectorAll('input[type="email"], input[autocomplete="cc-number"], input[autocomplete="cc-csc"], input[autocomplete="cc-exp"]').forEach(el => {
    el.value = '';
    el.setAttribute('value', '');
  });

  // Remove elements marked as sensitive
  root.querySelectorAll('[data-sensitive], [data-coview-hide]').forEach(el => {
    el.remove();
  });

  // Clear form field values (optional - can be toggled)
  // root.querySelectorAll('input[type="text"], textarea').forEach(el => {
  //   el.value = '';
  //   el.setAttribute('value', '');
  // });
}

// Convert relative URLs to absolute
function convertToAbsoluteUrls(root) {
  const baseUrl = window.location.href;

  // Convert href attributes
  root.querySelectorAll('[href]').forEach(el => {
    const href = el.getAttribute('href');
    if (href && !href.startsWith('data:') && !href.startsWith('javascript:') && !href.startsWith('#')) {
      try {
        el.setAttribute('href', new URL(href, baseUrl).href);
      } catch (e) {
        // Invalid URL, leave as-is
      }
    }
  });

  // Convert src attributes
  root.querySelectorAll('[src]').forEach(el => {
    const src = el.getAttribute('src');
    if (src && !src.startsWith('data:')) {
      try {
        el.setAttribute('src', new URL(src, baseUrl).href);
      } catch (e) {
        // Invalid URL, leave as-is
      }
    }
  });

  // Convert srcset attributes
  root.querySelectorAll('[srcset]').forEach(el => {
    const srcset = el.getAttribute('srcset');
    if (srcset) {
      const newSrcset = srcset.split(',').map(part => {
        const [url, descriptor] = part.trim().split(/\s+/);
        try {
          const absoluteUrl = new URL(url, baseUrl).href;
          return descriptor ? `${absoluteUrl} ${descriptor}` : absoluteUrl;
        } catch (e) {
          return part;
        }
      }).join(', ');
      el.setAttribute('srcset', newSrcset);
    }
  });

  // Convert CSS url() references in style attributes
  root.querySelectorAll('[style]').forEach(el => {
    const style = el.getAttribute('style');
    if (style && style.includes('url(')) {
      const newStyle = style.replace(/url\(['"]?([^'")\s]+)['"]?\)/g, (match, url) => {
        if (url.startsWith('data:')) return match;
        try {
          return `url('${new URL(url, baseUrl).href}')`;
        } catch (e) {
          return match;
        }
      });
      el.setAttribute('style', newStyle);
    }
  });
}

// Send DOM update to background script
// isFullPage: true for navigation/initial load, false for incremental updates
function sendDOMUpdate(isFullPage = true) {
  if (!isCapturing) return;

  const html = captureDOM();
  
  // Only send if DOM has changed
  if (html !== lastDomSnapshot) {
    lastDomSnapshot = html;
    console.log('CoView: Sending DOM update, size:', html.length, 'fullPage:', isFullPage);
    chrome.runtime.sendMessage({ 
      type: 'DOM_UPDATE', 
      html,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight,
      isFullPage
    })
      .then(() => console.log('CoView: DOM update sent'))
      .catch((err) => console.error('CoView: Failed to send DOM:', err));
  }
}

// Throttle function
function throttle(func, limit) {
  let inThrottle;
  return function(...args) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}

// Debounce function
function debounce(func, wait) {
  let timeout;
  return function(...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
}

// Event handlers
const handleMouseMove = throttle((e) => {
  if (!isCapturing) return;
  
  chrome.runtime.sendMessage({
    type: 'CURSOR_MOVE',
    position: {
      x: e.clientX,
      y: e.clientY,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight
    }
  });
}, 33); // ~30fps

const handleScroll = throttle(() => {
  if (!isCapturing) return;
  
  chrome.runtime.sendMessage({
    type: 'SCROLL',
    position: {
      x: window.scrollX,
      y: window.scrollY
    }
  });
}, 100);

const handleClick = (e) => {
  if (!isCapturing) return;
  
  chrome.runtime.sendMessage({
    type: 'CLICK',
    position: {
      x: e.clientX,
      y: e.clientY
    }
  });
};

// Set up event listeners
function setupEventListeners() {
  document.addEventListener('mousemove', handleMouseMove, { passive: true });
  window.addEventListener('scroll', handleScroll, { passive: true });
  document.addEventListener('click', handleClick, { passive: true });
}

// Remove event listeners
function removeEventListeners() {
  document.removeEventListener('mousemove', handleMouseMove);
  window.removeEventListener('scroll', handleScroll);
  document.removeEventListener('click', handleClick);
}

// Mutation observer
let mutationObserver = null;

// Debounced DOM update for small changes (class/style)
const debouncedDOMUpdate = debounce(() => {
  sendDOMUpdate(false); // incremental update
}, 100);

// Debounced DOM update for larger structural changes
const debouncedStructuralUpdate = debounce(() => {
  sendDOMUpdate(false); // incremental update
}, 250);

function setupMutationObserver() {
  mutationObserver = new MutationObserver((mutations) => {
    if (!isCapturing) return;
    
    let hasStructuralChanges = false;
    let hasVisibilityChanges = false;
    
    for (const mutation of mutations) {
      if (mutation.type === 'childList') {
        // New nodes added/removed - structural change
        if (mutation.addedNodes.length > 0 || mutation.removedNodes.length > 0) {
          hasStructuralChanges = true;
        }
      } else if (mutation.type === 'attributes') {
        const attr = mutation.attributeName;
        // Check for visibility-related attribute changes (popovers, modals, dropdowns)
        if (attr === 'class' || attr === 'style' || attr === 'hidden' || 
            attr === 'aria-hidden' || attr === 'aria-expanded' || attr === 'open' ||
            attr === 'data-state' || attr === 'data-open' || attr === 'data-visible') {
          hasVisibilityChanges = true;
        }
      } else if (mutation.type === 'characterData') {
        hasStructuralChanges = true;
      }
    }

    // Prioritize: structural changes use longer debounce, visibility changes use shorter
    if (hasStructuralChanges) {
      debouncedStructuralUpdate();
    } else if (hasVisibilityChanges) {
      debouncedDOMUpdate();
    }
  });

  mutationObserver.observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['class', 'style', 'hidden', 'aria-hidden', 'aria-expanded', 'open', 'data-state', 'data-open', 'data-visible'],
    characterData: true
  });
}

// Handle navigation within SPA
const originalPushState = history.pushState;
history.pushState = function(...args) {
  originalPushState.apply(this, args);
  if (isCapturing) {
    // Reset snapshot to force full update
    lastDomSnapshot = null;
    chrome.runtime.sendMessage({ type: 'NAVIGATION', url: window.location.href });
    setTimeout(() => sendDOMUpdate(true), 100); // Full page update
  }
};

const originalReplaceState = history.replaceState;
history.replaceState = function(...args) {
  originalReplaceState.apply(this, args);
  if (isCapturing) {
    lastDomSnapshot = null;
    chrome.runtime.sendMessage({ type: 'NAVIGATION', url: window.location.href });
    setTimeout(() => sendDOMUpdate(true), 100); // Full page update
  }
};

window.addEventListener('popstate', () => {
  if (isCapturing) {
    lastDomSnapshot = null;
    chrome.runtime.sendMessage({ type: 'NAVIGATION', url: window.location.href });
    setTimeout(() => sendDOMUpdate(true), 100); // Full page update
  }
});

console.log('CoView content script loaded');
