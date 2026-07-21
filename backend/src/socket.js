import { MatchingEngine } from './services/matching.js';
import { query } from './db/pool.js';

export function setupSockets(io) {
  const matching = new MatchingEngine(io);

  io.on('connection', (socket) => {
    const { role, userId } = socket.handshake.auth || {};

    if (role && userId) {
      socket.join(`${role}:${userId}`);
      if (role === 'admin') socket.join('admin:ops');
    }

    socket.on('join_trip', (tripId) => {
      socket.join(`trip:${tripId}`);
    });

    socket.on('driver_location', async (payload) => {
      // payload: { lat, lng, heading, tripId? }
      if (role !== 'driver' || !userId) return;
      const { lat, lng, heading, tripId } = payload || {};
      if (lat == null || lng == null) return;

      await query(
        `UPDATE drivers SET
           lat = $2, lng = $3,
           heading = $4,
           updated_at = NOW()
         WHERE id = $1`,
        [userId, lat, lng, heading ?? null],
      );

      if (tripId) {
        io.to(`trip:${tripId}`).emit('driver_location_update', {
          tripId,
          lat,
          lng,
          heading,
          at: Date.now(),
        });
      }
      io.to('admin:ops').emit('driver_location_update', {
        driverId: userId,
        lat,
        lng,
        heading,
      });
    });

    socket.on('disconnect', () => {});
  });

  return matching;
}
