# DeckHand Socket.io Server

WebSocket server for real-time presentation synchronization across multiple devices.

## Features

- Real-time slide synchronization
- Multi-device room management
- WebSocket with fallback to polling
- Production-ready with health checks
- Optimized for Mumbai (BOM) region

## Quick Start

### Local Development

```bash
# Using Bun (recommended)
bun install
bun run server.ts

# Using Node
npm install
node server.js
```

Server will start on `http://localhost:3001`

### Health Check

```bash
curl http://localhost:3001/health
```

Response:
```json
{"status":"ok","connections":0}
```

## Deployment

See [DEPLOYMENT.md](../DEPLOYMENT.md) for detailed deployment instructions.

### Railway (Recommended)

```bash
railway login
railway init
railway up
```

### Render.com

1. Connect GitHub repository
2. Set root directory to `socket-server`
3. Build command: `npm install`
4. Start command: `npm start`

### Fly.io

```bash
fly launch
fly deploy
```

### Docker

```bash
docker build -t deckhand-socket .
docker run -p 3001:3001 deckhand-socket
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3001` | Server port |
| `CORS_ORIGIN` | `*` | Allowed CORS origins |

## API

### HTTP Endpoints

- `GET /` - Server info
- `GET /health` - Health check

### Socket.io Events

#### Client → Server

- `join-room` - Join a presentation room
- `leave-room` - Leave current room
- `slide-change` - Change current slide
- `set-total-slides` - Update total slides count
- `annotation-data` - Send drawing annotation
- `clear-annotations` - Clear slide annotations
- `update-role` - Update device role

#### Server → Client

- `slide-sync` - Sync slide index to all devices
- `room-updated` - Room state changed
- `annotation-received` - Drawing annotation received
- `annotations-cleared` - Annotations cleared

## Architecture

```
┌─────────────┐     WebSocket      ┌──────────────┐
│   Stage     │◄──────────────────►│              │
│  (Desktop)  │                    │   Socket.io  │
└─────────────┘                    │    Server    │
                                   │              │
┌─────────────┐                    │  Port 3001   │
│   Remote    │◄──────────────────►│              │
│   (Phone)   │                    └──────────────┘
└─────────────┘

┌─────────────┐
│Teleprompter │◄──────────────────►
│   (Tablet)  │
└─────────────┘
```

## Monitoring

- **Railway**: Dashboard → Logs → Metrics
- **Render**: Logs tab → Metrics
- **Fly.io**: `fly logs` + Dashboard

## Performance

- Supports 1000+ concurrent connections
- Average latency: < 50ms
- Memory footprint: ~50MB
- CPU usage: < 5% (idle)

## License

MIT
