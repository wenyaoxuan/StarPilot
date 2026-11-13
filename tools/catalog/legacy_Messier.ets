export interface MessierObject {
  id: string;
  name: string;
  raHours: number;
  decDeg: number;
  mag: number;
  sizeA: number;
  sizeB: number;
  type: string;
  fl: string;
  desc: string;
}

/**
 * J2000, approximate positions/sizes for the S1 shell. S2 will validate every
 * coordinate against an independent ephemeris, S4 will expand to the full 110.
 */
export const MESSIER: MessierObject[] = [
  { id: 'M1', name: '蟹状星云', raHours: 5.575, decDeg: 22.017, mag: 8.4, sizeA: 6, sizeB: 4, type: '超新星遗迹', fl: '600–1200mm', desc: '1054 年超新星遗迹，城市环境下建议窄带。' },
  { id: 'M3', name: '球状星团', raHours: 13.703, decDeg: 28.383, mag: 6.2, sizeA: 18, sizeB: 18, type: '球状星团', fl: '300–800mm', desc: '猎犬座北天球状星团，亮核明显。' },
  { id: 'M5', name: '球状星团', raHours: 15.310, decDeg: 2.083, mag: 6.7, sizeA: 23, sizeB: 23, type: '球状星团', fl: '300–800mm', desc: '巨蛇座，视直径大，适合中长焦。' },
  { id: 'M8', name: '礁湖星云', raHours: 18.063, decDeg: -24.383, mag: 6.0, sizeA: 90, sizeB: 40, type: '发射星云', fl: '135–300mm', desc: '人马座，夏季南向窗口的经典目标。' },
  { id: 'M13', name: '武仙座球状星团', raHours: 16.695, decDeg: 36.467, mag: 5.8, sizeA: 20, sizeB: 20, type: '球状星团', fl: '300–800mm', desc: '北天最亮的球状星团之一。' },
  { id: 'M16', name: '鹰状星云', raHours: 18.313, decDeg: -13.783, mag: 6.0, sizeA: 35, sizeB: 28, type: '发射星云', fl: '300–600mm', desc: '包含创生之柱，窄带收益大。' },
  { id: 'M17', name: '欧米伽星云', raHours: 18.347, decDeg: -16.183, mag: 6.0, sizeA: 46, sizeB: 37, type: '发射星云', fl: '300–600mm', desc: '人马座明亮发射星云，南向低空。' },
  { id: 'M20', name: '三叶星云', raHours: 18.043, decDeg: -23.033, mag: 6.3, sizeA: 28, sizeB: 28, type: '发射星云', fl: '300–600mm', desc: '发射/反射/暗星云混合，夏季目标。' },
  { id: 'M27', name: '哑铃星云', raHours: 19.993, decDeg: 22.717, mag: 7.4, sizeA: 8, sizeB: 6, type: '行星状星云', fl: '600–1200mm', desc: '狐狸座行星状星云，小而有结构。' },
  { id: 'M31', name: '仙女座星系', raHours: 0.712, decDeg: 41.267, mag: 3.4, sizeA: 190, sizeB: 60, type: '星系', fl: '135–300mm', desc: '最大最亮的旋涡星系，需广角。' },
  { id: 'M33', name: '三角座星系', raHours: 1.565, decDeg: 30.650, mag: 5.7, sizeA: 70, sizeB: 60, type: '星系', fl: '300–600mm', desc: '低表面亮度，城市环境难度高。' },
  { id: 'M42', name: '猎户座大星云', raHours: 5.590, decDeg: -5.450, mag: 4.0, sizeA: 85, sizeB: 60, type: '发射星云', fl: '135–300mm', desc: '冬季最亮深空目标，核心易过曝。' },
  { id: 'M45', name: '昴星团', raHours: 3.783, decDeg: 24.117, mag: 1.6, sizeA: 110, sizeB: 110, type: '疏散星团', fl: '135–300mm', desc: '亮星团，广角 framed 最佳。' },
  { id: 'M51', name: '涡状星系', raHours: 13.498, decDeg: 47.200, mag: 8.4, sizeA: 11, sizeB: 7, type: '星系', fl: '600–1200mm', desc: '猎犬座相互作用星系，需要长焦。' },
  { id: 'M57', name: '环状星云', raHours: 18.893, decDeg: 33.033, mag: 8.8, sizeA: 1.4, sizeB: 1.0, type: '行星状星云', fl: '1200–2000mm', desc: '天琴座小环，极考验采样与导星。' },
  { id: 'M63', name: '向日葵星系', raHours: 13.263, decDeg: 42.033, mag: 8.6, sizeA: 12, sizeB: 8, type: '星系', fl: '600–1200mm', desc: '猎犬座旋涡星系，表面亮度中等。' },
  { id: 'M64', name: '黑眼星系', raHours: 12.945, decDeg: 21.683, mag: 8.5, sizeA: 10, sizeB: 5, type: '星系', fl: '600–1200mm', desc: '后发座，暗尘带是识别特征。' },
  { id: 'M81', name: '波德星系', raHours: 9.926, decDeg: 69.067, mag: 6.9, sizeA: 27, sizeB: 14, type: '星系', fl: '300–600mm', desc: '大熊座高纬度星系，北天常青目标。' },
  { id: 'M82', name: '雪茄星系', raHours: 9.931, decDeg: 69.683, mag: 8.4, sizeA: 11, sizeB: 5, type: '星系', fl: '300–600mm', desc: '与 M81 同框，星暴星系。' },
  { id: 'M101', name: '风车星系', raHours: 14.053, decDeg: 54.350, mag: 7.9, sizeA: 29, sizeB: 27, type: '星系', fl: '300–600mm', desc: '大熊座正面旋涡星系，低表面亮度。' },
  { id: 'M104', name: '草帽星系', raHours: 12.667, decDeg: -11.617, mag: 8.0, sizeA: 9, sizeB: 4, type: '星系', fl: '600–1200mm', desc: '室女座侧向星系，尘带明显。' }
];

export function raText(o: MessierObject): string {
  const h: number = Math.floor(o.raHours);
  const m: number = Math.round((o.raHours - h) * 60);
  return `${h}h ${m < 10 ? '0' : ''}${m}m`;
}

export function decText(o: MessierObject): string {
  const sign: string = o.decDeg >= 0 ? '+' : '-';
  const abs: number = Math.abs(o.decDeg);
  const d: number = Math.floor(abs);
  const m: number = Math.round((abs - d) * 60);
  return `${sign}${d}° ${m < 10 ? '0' : ''}${m}′`;
}
