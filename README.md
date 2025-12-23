# CoView

Share your browser. Not a video of it.

https://github.com/ChivukulaVirinchi/Coview/raw/main/demo.mp4

CoView streams your page's DOM over WebSockets. Viewers see crisp text, not compressed video artifacts. ~100KB/s bandwidth. <50ms latency.

## How it works

1. Chrome extension captures your page's DOM
2. Phoenix server broadcasts changes to viewers via Channels
3. Viewers render the DOM locally with morphdom

No video encoding. No screen capture. Just HTML.

## Why Elixir

Phoenix Channels handle thousands of concurrent viewers per room without breaking a sweat. Each room is a lightweight process. The BEAM was built for this.

## Run locally

```bash
git clone https://github.com/ChivukulaVirinchi/Coview
cd Coview
mix setup
mix phx.server
```

Server runs at `localhost:4000`.

### Load the extension

1. Open `chrome://extensions`
2. Enable Developer mode
3. Click "Load unpacked" → select the `extension/` folder

### Share

1. Click the CoView extension icon
2. Enter a room name, hit Start
3. Send viewers to `localhost:4000`, enter the room code

## Stack

- Elixir + Phoenix
- Phoenix Channels (WebSockets)
- morphdom (DOM diffing)
- Chrome Extension (Manifest V3)

## License

MIT
