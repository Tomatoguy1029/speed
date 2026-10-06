const OFF = 4096;

export function buildGrid(list, cell) {
  const map = new Map();
  for (const it of list) {
    if (it.dead) continue;
    const key = (Math.floor(it.x / cell) + OFF) * 8192 + (Math.floor(it.y / cell) + OFF);
    let arr = map.get(key);
    if (!arr) { arr = []; map.set(key, arr); }
    arr.push(it);
  }
  return { cell, map };
}

export function queryGrid(grid, x0, y0, x1, y1, cb) {
  const c = grid.cell;
  const cx0 = Math.floor(x0 / c), cx1 = Math.floor(x1 / c);
  const cy0 = Math.floor(y0 / c), cy1 = Math.floor(y1 / c);
  for (let cx = cx0; cx <= cx1; cx++) {
    for (let cy = cy0; cy <= cy1; cy++) {
      const arr = grid.map.get((cx + OFF) * 8192 + (cy + OFF));
      if (!arr) continue;
      for (const it of arr) if (!it.dead) cb(it);
    }
  }
}

export function queryRadius(grid, x, y, r, cb) {
  queryGrid(grid, x - r, y - r, x + r, y + r, (it) => {
    const dx = it.x - x, dy = it.y - y, rr = r + (it.r || 0);
    if (dx * dx + dy * dy <= rr * rr) cb(it);
  });
}
