const OFF = 4096;

export function buildGrid(list, cell, reuse) {
  const grid = reuse || { cell, map: new Map(), buckets: [] };
  const { map, buckets } = grid;
  map.clear();
  grid.cell = cell;
  let used = 0;
  for (const it of list) {
    if (it.dead) continue;
    const key = (Math.floor(it.x / cell) + OFF) * 8192 + (Math.floor(it.y / cell) + OFF);
    let arr = map.get(key);
    if (!arr) {
      arr = buckets[used] || (buckets[used] = []);
      used++;
      arr.length = 0; arr.maxId = -Infinity;
      map.set(key, arr);
    }
    if (it.id > arr.maxId) arr.maxId = it.id;
    arr.push(it);
  }
  // Release enemies retained in buckets no longer used after a dense fight.
  for (let i = used; i < buckets.length; i++) buckets[i].length = 0;
  return grid;
}

export function queryGrid(grid, x0, y0, x1, y1, cb, afterId) {
  const c = grid.cell;
  const cx0 = Math.floor(x0 / c), cx1 = Math.floor(x1 / c);
  const cy0 = Math.floor(y0 / c), cy1 = Math.floor(y1 / c);
  for (let cx = cx0; cx <= cx1; cx++) {
    for (let cy = cy0; cy <= cy1; cy++) {
      const arr = grid.map.get((cx + OFF) * 8192 + (cy + OFF));
      if (!arr || (afterId !== undefined && arr.maxId <= afterId)) continue;
      if (afterId === undefined) {
        for (const it of arr) if (!it.dead) cb(it);
      } else {
        for (const it of arr) if (!it.dead && it.id > afterId) cb(it);
      }
    }
  }
}

// A boolean overlap query can stop at the first contact; its order has no gameplay effect.
export function gridHasContact(grid, x, y, radius, maxRadius) {
  const reach = radius + maxRadius, c = grid.cell;
  const cx0 = Math.floor((x - reach) / c), cx1 = Math.floor((x + reach) / c);
  const cy0 = Math.floor((y - reach) / c), cy1 = Math.floor((y + reach) / c);
  for (let cx = cx0; cx <= cx1; cx++) {
    for (let cy = cy0; cy <= cy1; cy++) {
      const arr = grid.map.get((cx + OFF) * 8192 + cy + OFF);
      if (!arr) continue;
      for (const e of arr) {
        if (e.dead) continue;
        const rr = radius + e.r, dx = e.x - x, dy = e.y - y;
        if (dx * dx + dy * dy < rr * rr) return true;
      }
    }
  }
  return false;
}

export function queryRadius(grid, x, y, r, cb) {
  queryGrid(grid, x - r, y - r, x + r, y + r, (it) => {
    const dx = it.x - x, dy = it.y - y, rr = r + (it.r || 0);
    if (dx * dx + dy * dy <= rr * rr) cb(it);
  });
}
