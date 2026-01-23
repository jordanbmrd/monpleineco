export type LatLng = {
  lat: number;
  lon: number;
};

const EARTH_RADIUS_METERS = 6371000;

const toRadians = (value: number) => (value * Math.PI) / 180;

export const haversineMeters = (a: LatLng, b: LatLng) => {
  const dLat = toRadians(b.lat - a.lat);
  const dLon = toRadians(b.lon - a.lon);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);

  const sinLat = Math.sin(dLat / 2);
  const sinLon = Math.sin(dLon / 2);
  const h =
    sinLat * sinLat + Math.cos(lat1) * Math.cos(lat2) * sinLon * sinLon;
  return 2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
};

const projectToMeters = (point: LatLng, refLat: number) => {
  const latRad = toRadians(point.lat);
  const lonRad = toRadians(point.lon);
  const refLatRad = toRadians(refLat);
  return {
    x: EARTH_RADIUS_METERS * lonRad * Math.cos(refLatRad),
    y: EARTH_RADIUS_METERS * latRad,
  };
};

export const distancePointToSegmentMeters = (
  point: LatLng,
  segmentStart: LatLng,
  segmentEnd: LatLng,
) => {
  const refLat = (segmentStart.lat + segmentEnd.lat) / 2;
  const p = projectToMeters(point, refLat);
  const a = projectToMeters(segmentStart, refLat);
  const b = projectToMeters(segmentEnd, refLat);

  const abx = b.x - a.x;
  const aby = b.y - a.y;
  const apx = p.x - a.x;
  const apy = p.y - a.y;
  const abLenSq = abx * abx + aby * aby;
  const t = abLenSq === 0 ? 0 : (apx * abx + apy * aby) / abLenSq;
  const clamped = Math.max(0, Math.min(1, t));

  const closestX = a.x + clamped * abx;
  const closestY = a.y + clamped * aby;
  const dx = p.x - closestX;
  const dy = p.y - closestY;
  return Math.sqrt(dx * dx + dy * dy);
};

export const distancePointToPolylineMeters = (
  point: LatLng,
  polyline: LatLng[],
) => {
  if (polyline.length < 2) {
    return Number.POSITIVE_INFINITY;
  }
  let min = Number.POSITIVE_INFINITY;
  for (let i = 0; i < polyline.length - 1; i += 1) {
    const distance = distancePointToSegmentMeters(
      point,
      polyline[i],
      polyline[i + 1],
    );
    if (distance < min) {
      min = distance;
    }
  }
  return min;
};

export const sampleRoutePoints = (
  coordinates: LatLng[],
  spacingMeters: number,
) => {
  if (coordinates.length === 0) {
    return [];
  }
  if (coordinates.length === 1) {
    return coordinates;
  }
  const sampled: LatLng[] = [coordinates[0]];
  let accumulator = 0;
  let last = coordinates[0];

  for (let i = 1; i < coordinates.length; i += 1) {
    const current = coordinates[i];
    const segmentDistance = haversineMeters(last, current);
    accumulator += segmentDistance;
    if (accumulator >= spacingMeters) {
      sampled.push(current);
      accumulator = 0;
      last = current;
    } else {
      last = current;
    }
  }

  const tail = coordinates[coordinates.length - 1];
  const lastSample = sampled[sampled.length - 1];
  if (lastSample.lat !== tail.lat || lastSample.lon !== tail.lon) {
    sampled.push(tail);
  }
  return sampled;
};
