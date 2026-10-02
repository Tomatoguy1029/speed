import { CONFIG } from './config.js';

// Speed tiers announced on screen as the ship breaks through them (values in px/s).
export const SPEED_STAGES = [
  { v: CONFIG.escapeSpeed * 0.27, name: 'STAGE Ⅰ' },
  { v: CONFIG.escapeSpeed * 0.45, name: 'STAGE Ⅱ' },
  { v: CONFIG.escapeSpeed * 0.62, name: 'STAGE Ⅲ' },
  { v: CONFIG.escapeSpeed * 0.8, name: 'STAGE Ⅳ' },
  { v: CONFIG.escapeSpeed, name: 'ESCAPE' },
];

export function speedStage(sp) {
  let s = 0;
  for (let i = 0; i < SPEED_STAGES.length; i++) if (sp >= SPEED_STAGES[i].v) s = i + 1;
  return s;
}
