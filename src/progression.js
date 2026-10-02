import { CONFIG } from './config.js';

export function xpForLevel(level) {
  return CONFIG.xpBase + CONFIG.xpGrowth * level;
}
