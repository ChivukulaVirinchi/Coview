// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/coview"
import topbar from "../vendor/topbar"
import morphdom from "morphdom"

// CoView Hooks
let Hooks = {}

// Hook to handle iframe content updates using morphdom for incremental patching
Hooks.ViewFrame = {
  mounted() {
    this.iframeReady = false
    this.pendingUpdate = null
    
    // Track iframe load state
    this.el.addEventListener('load', () => {
      console.debug("CoView: Iframe loaded, ready for morphdom updates")
      this.iframeReady = true
      
      // Apply any pending update that arrived before iframe was ready
      if (this.pendingUpdate) {
        console.debug("CoView: Applying pending update")
        this.applyMorphdom(this.pendingUpdate)
        this.pendingUpdate = null
      }
    })
    
    // Handle scroll sync from server
    this.handleEvent("scroll_to", ({x, y}) => {
      const iframe = this.el
      if (iframe.contentWindow) {
        try {
          iframe.contentWindow.scrollTo(x, y)
        } catch (e) {
          console.debug("Could not scroll iframe:", e)
        }
      }
    })

    // Handle DOM updates - either full replacement or morphdom patching
    this.handleEvent("dom_update", ({html, is_full_page}) => {
      const iframe = this.el
      
      // Full page navigation - replace entire iframe content
      if (is_full_page) {
        console.debug("CoView: Full page update - replacing iframe content")
        this.iframeReady = false  // Will be ready again after load event
        this.pendingUpdate = null
        iframe.srcdoc = html
        return
      }
      
      // Incremental update - use morphdom if iframe is ready
      if (!this.iframeReady) {
        // Queue update for when iframe finishes loading
        console.debug("CoView: Iframe not ready, queuing update for later")
        this.pendingUpdate = html
        return
      }
      
      this.applyMorphdom(html)
    })
  },
  
  applyMorphdom(html) {
    const iframe = this.el
    
    // Double-check iframe is accessible
    if (!iframe.contentDocument || !iframe.contentDocument.body) {
      console.warn("CoView: Iframe contentDocument not accessible, cannot apply morphdom")
      return
    }

    try {
      // Parse the incoming HTML
      const parser = new DOMParser()
      const newDoc = parser.parseFromString(html, "text/html")
      
      // Morph the head (for stylesheets, etc.)
      if (iframe.contentDocument.head && newDoc.head) {
        morphdom(iframe.contentDocument.head, newDoc.head, {
          onBeforeElUpdated: (fromEl, toEl) => {
            // Preserve script tags to avoid re-execution issues
            if (fromEl.tagName === 'SCRIPT') return false
            return true
          }
        })
      }
      
      // Morph the body (main content)
      if (iframe.contentDocument.body && newDoc.body) {
        morphdom(iframe.contentDocument.body, newDoc.body, {
          onBeforeElUpdated: (fromEl, toEl) => {
            // Preserve focused elements to maintain user context
            if (fromEl === iframe.contentDocument.activeElement) {
              return false
            }
            return true
          },
          childrenOnly: false
        })
      }
      
      console.debug("CoView: Morphdom update applied successfully")
    } catch (e) {
      console.error("CoView: Morphdom update failed:", e)
      // Don't fallback to srcdoc here - that would cause a reload loop
      // Just log the error and continue
    }
  }
}

// Hook to show click ripples when leader clicks
Hooks.ClickRipple = {
  mounted() {
    this.handleEvent("click", ({x, y}) => {
      const ripple = document.createElement("div")
      ripple.className = "click-ripple"
      ripple.style.left = x + "px"
      ripple.style.top = y + "px"
      this.el.appendChild(ripple)
      
      // Remove ripple after animation completes
      setTimeout(() => ripple.remove(), 600)
    })
  }
}

// Hook to copy room link to clipboard
Hooks.CopyLink = {
  mounted() {
    this.el.addEventListener("click", () => {
      const url = this.el.dataset.url
      navigator.clipboard.writeText(url).then(() => {
        // Show feedback
        const originalHTML = this.el.innerHTML
        this.el.innerHTML = `<span class="hero-check w-4 h-4"></span><span>Copied!</span>`
        setTimeout(() => {
          this.el.innerHTML = originalHTML
        }, 2000)
      }).catch(err => {
        console.error("Failed to copy:", err)
      })
    })
  }
}

// Hook to scale the leader's viewport to fit the viewer's container
// This preserves exact pixel positions for cursor alignment
Hooks.ScaledView = {
  mounted() {
    this.updateScale()
    this.resizeObserver = new ResizeObserver(() => this.updateScale())
    this.resizeObserver.observe(this.el)
  },

  updated() {
    this.updateScale()
  },

  destroyed() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  },

  updateScale() {
    const wrapper = document.getElementById("scaled-wrapper")
    if (!wrapper) return

    const viewportWidth = parseInt(this.el.dataset.viewportWidth, 10)
    const viewportHeight = parseInt(this.el.dataset.viewportHeight, 10)
    
    if (!viewportWidth || !viewportHeight) return

    // Get container dimensions (accounting for padding/borders)
    const containerWidth = this.el.clientWidth
    const containerHeight = this.el.clientHeight

    // Calculate scale to fit container while maintaining aspect ratio
    const scaleX = containerWidth / viewportWidth
    const scaleY = containerHeight / viewportHeight
    const scale = Math.min(scaleX, scaleY)

    // Apply transform - origin is top-left so content scales from there
    wrapper.style.transform = `scale(${scale})`
    
    // Center the scaled content if there's extra space
    const scaledWidth = viewportWidth * scale
    const scaledHeight = viewportHeight * scale
    const offsetX = (containerWidth - scaledWidth) / 2
    const offsetY = (containerHeight - scaledHeight) / 2
    wrapper.style.left = `${offsetX}px`
    wrapper.style.top = `${offsetY}px`
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

