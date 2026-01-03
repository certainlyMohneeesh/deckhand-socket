import { Server } from 'socket.io';
import { createServer } from 'http';
import os from 'os';

// Get local IP addresses for logging
function getLocalIPs(): string[] {
  const interfaces = os.networkInterfaces();
  const ips: string[] = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name] || []) {
      if (iface.family === 'IPv4' && !iface.internal) {
        ips.push(iface.address);
      }
    }
  }
  return ips;
}

const httpServer = createServer((req, res) => {
  // Handle CORS preflight and health check
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  
  // Health check endpoint
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', connections: io.engine.clientsCount }));
    return;
  }
  
  res.writeHead(200);
  res.end('DeckHand Socket.io Server');
});

const io = new Server(httpServer, {
  cors: {
    origin: '*',  // Allow all origins for local network access
    methods: ['GET', 'POST'],
    credentials: false,  // Set false for simpler CORS
    allowedHeaders: ['Content-Type'],
  },
  transports: ['websocket', 'polling'],
  pingTimeout: 60000,
  pingInterval: 25000,
  allowEIO3: true,  // Allow older clients
});

// =============================================================================
// ROOM STATE MANAGEMENT (Production-ready)
// =============================================================================

interface RoomState {
  slideIndex: number;
  totalSlides: number;
  createdAt: number;
  lastActivity: number;
}

interface DeviceInfo {
  role: 'stage' | 'remote' | 'teleprompter';
  name: string;
  roomId: string;
  joinedAt: number;
}

// Room storage
const rooms = new Map<string, Set<string>>();
const deviceInfo = new Map<string, DeviceInfo>();
const roomStates = new Map<string, RoomState>();

// Helper: Get connected devices for a room
function getConnectedDevices(roomId: string) {
  const deviceSet = rooms.get(roomId);
  if (!deviceSet) return [];
  
  return Array.from(deviceSet)
    .map(id => {
      const info = deviceInfo.get(id);
      return info ? { id, role: info.role, name: info.name } : null;
    })
    .filter((d): d is NonNullable<typeof d> => d !== null);
}

// Helper: Broadcast room update
function broadcastRoomUpdate(roomId: string) {
  const devices = getConnectedDevices(roomId);
  const state = roomStates.get(roomId);
  
  io.to(roomId).emit('room-updated', {
    roomId,
    devices,
    totalDevices: devices.length,
    totalSlides: state?.totalSlides || 0,
  });
}

// =============================================================================
// SOCKET CONNECTION HANDLING
// =============================================================================

io.on('connection', (socket) => {
  console.log(`[Socket.io] ✓ Client connected: ${socket.id.substring(0, 8)}...`);

  // -------------------------------------------------------------------------
  // JOIN ROOM
  // -------------------------------------------------------------------------
  socket.on('join-room', ({ roomId, role, deviceName }) => {
    console.log(`[Room] ${socket.id.substring(0, 8)} joining ${roomId} as ${role}`);
    
    // Leave any previous rooms first
    const existingInfo = deviceInfo.get(socket.id);
    if (existingInfo && existingInfo.roomId !== roomId) {
      socket.leave(existingInfo.roomId);
      const oldDeviceSet = rooms.get(existingInfo.roomId);
      if (oldDeviceSet) {
        oldDeviceSet.delete(socket.id);
        broadcastRoomUpdate(existingInfo.roomId);
      }
    }
    
    // Join the new room
    socket.join(roomId);
    
    // Store device info
    deviceInfo.set(socket.id, {
      role,
      name: deviceName || 'Unknown Device',
      roomId,
      joinedAt: Date.now(),
    });
    
    // Initialize room if needed
    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Set());
      roomStates.set(roomId, {
        slideIndex: 1,
        totalSlides: 0,
        createdAt: Date.now(),
        lastActivity: Date.now(),
      });
    }
    rooms.get(roomId)!.add(socket.id);
    
    // Update room activity
    const state = roomStates.get(roomId)!;
    state.lastActivity = Date.now();

    // Send current state to newly joined device
    socket.emit('slide-sync', {
      slideIndex: state.slideIndex,
      totalSlides: state.totalSlides,
      roomId,
    });

    // Notify all devices about the new connection
    broadcastRoomUpdate(roomId);

    console.log(`[Room] Room ${roomId} now has ${rooms.get(roomId)!.size} device(s)`);
  });

  // -------------------------------------------------------------------------
  // SLIDE CHANGE - The critical sync event
  // -------------------------------------------------------------------------
  socket.on('slide-change', ({ roomId, slideIndex, totalSlides }) => {
    const info = deviceInfo.get(socket.id);
    const role = info?.role || 'unknown';
    
    console.log(`[Slide] ${role}:${socket.id.substring(0, 8)} → slide ${slideIndex} in ${roomId}`);
    
    // Validate room exists
    const state = roomStates.get(roomId);
    if (!state) {
      console.warn(`[Slide] Room ${roomId} does not exist!`);
      return;
    }
    
    // Update room state
    state.slideIndex = slideIndex;
    state.lastActivity = Date.now();
    
    // Update totalSlides if provided (usually from stage)
    if (totalSlides !== undefined && totalSlides > 0) {
      state.totalSlides = totalSlides;
    }
    
    // CRITICAL: Broadcast to ALL devices in room INCLUDING sender
    // This ensures everyone is in sync
    io.to(roomId).emit('slide-sync', {
      slideIndex,
      totalSlides: state.totalSlides,
      roomId,
      sourceId: socket.id,
      timestamp: Date.now(),
    });
    
    console.log(`[Slide] ✓ Broadcasted slide ${slideIndex}/${state.totalSlides} to room ${roomId}`);
  });

  // -------------------------------------------------------------------------
  // SET TOTAL SLIDES (from stage)
  // -------------------------------------------------------------------------
  socket.on('set-total-slides', ({ roomId, totalSlides }) => {
    console.log(`[Slides] Setting total slides for ${roomId}: ${totalSlides}`);
    
    const state = roomStates.get(roomId);
    if (state) {
      state.totalSlides = totalSlides;
      state.lastActivity = Date.now();
      
      // Broadcast to all devices
      io.to(roomId).emit('slide-sync', {
        slideIndex: state.slideIndex,
        totalSlides: state.totalSlides,
        roomId,
      });
    }
  });

  // -------------------------------------------------------------------------
  // ANNOTATIONS
  // -------------------------------------------------------------------------
  socket.on('annotation-data', ({ roomId, slideId, stroke }) => {
    console.log(`[Annotation] Received from ${socket.id.substring(0, 8)} in room ${roomId}`);
    
    // Broadcast to all other devices in room
    socket.to(roomId).emit('annotation-received', {
      slideId,
      stroke,
      sourceId: socket.id,
    });
  });

  socket.on('clear-annotations', ({ roomId, slideId }) => {
    console.log(`[Annotation] Clear request for slide ${slideId} in room ${roomId}`);
    
    io.to(roomId).emit('annotations-cleared', { slideId, roomId });
  });

  // -------------------------------------------------------------------------
  // ROLE UPDATES
  // -------------------------------------------------------------------------
  socket.on('update-role', ({ roomId, role, deviceName }) => {
    console.log(`[Role] ${socket.id.substring(0, 8)} updated role to ${role}`);
    
    const info = deviceInfo.get(socket.id);
    if (info) {
      info.role = role;
      info.name = deviceName || info.name;
    }
    
    broadcastRoomUpdate(roomId);
  });

  // -------------------------------------------------------------------------
  // DISCONNECT HANDLING
  // -------------------------------------------------------------------------
  socket.on('disconnect', (reason) => {
    console.log(`[Socket.io] ✗ Client disconnected: ${socket.id.substring(0, 8)} (${reason})`);
    
    const info = deviceInfo.get(socket.id);
    if (info) {
      const { roomId } = info;
      const deviceSet = rooms.get(roomId);
      
      if (deviceSet) {
        deviceSet.delete(socket.id);
        
        if (deviceSet.size === 0) {
          // Clean up empty rooms
          rooms.delete(roomId);
          roomStates.delete(roomId);
          console.log(`[Room] Room ${roomId} deleted (empty)`);
        } else {
          broadcastRoomUpdate(roomId);
        }
      }
    }
    
    deviceInfo.delete(socket.id);
  });

  // -------------------------------------------------------------------------
  // EXPLICIT LEAVE
  // -------------------------------------------------------------------------
  socket.on('leave-room', ({ roomId }) => {
    console.log(`[Room] ${socket.id.substring(0, 8)} leaving room ${roomId}`);
    
    socket.leave(roomId);
    
    const deviceSet = rooms.get(roomId);
    if (deviceSet) {
      deviceSet.delete(socket.id);
      
      if (deviceSet.size === 0) {
        rooms.delete(roomId);
        roomStates.delete(roomId);
        console.log(`[Room] Room ${roomId} deleted (empty)`);
      } else {
        broadcastRoomUpdate(roomId);
      }
    }
    
    deviceInfo.delete(socket.id);
  });
});

// =============================================================================
// SERVER STARTUP
// =============================================================================

const PORT = parseInt(process.env.SOCKET_PORT || '3001', 10);
const HOST = '0.0.0.0';  // Listen on all interfaces for mobile access

httpServer.listen(PORT, HOST, () => {
  const localIPs = getLocalIPs();
  
  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  🔌 DeckHand Socket.io Server');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  ✓ Port: ${PORT}`);
  console.log(`  ✓ Host: ${HOST} (all interfaces)`);
  console.log('');
  console.log('  📍 Access URLs:');
  console.log(`     Local:   http://localhost:${PORT}`);
  localIPs.forEach(ip => {
    console.log(`     Network: http://${ip}:${PORT}`);
  });
  console.log('');
  console.log('  📱 For mobile devices:');
  console.log('     1. Connect to same WiFi network');
  console.log('     2. Use the Network URL above');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('');
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n[Socket.io] Shutting down gracefully...');
  io.close(() => {
    console.log('[Socket.io] Server closed');
    process.exit(0);
  });
});
