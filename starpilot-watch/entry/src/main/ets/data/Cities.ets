export interface City {
  name: string;
  country: string;
  region: string;
  lat: number;
  lon: number;
  bortle: number;
}

export const CITIES: City[] = [
  // 中国
  { name: '北京', country: '中国', region: '中国', lat: 39.9042, lon: 116.4074, bortle: 8 },
  { name: '上海', country: '中国', region: '中国', lat: 31.2304, lon: 121.4737, bortle: 9 },
  { name: '广州', country: '中国', region: '中国', lat: 23.1291, lon: 113.2644, bortle: 9 },
  { name: '深圳', country: '中国', region: '中国', lat: 22.5431, lon: 114.0579, bortle: 9 },
  { name: '天津', country: '中国', region: '中国', lat: 39.0842, lon: 117.2009, bortle: 8 },
  { name: '重庆', country: '中国', region: '中国', lat: 29.5630, lon: 106.5516, bortle: 8 },
  { name: '成都', country: '中国', region: '中国', lat: 30.5728, lon: 104.0668, bortle: 8 },
  { name: '西安', country: '中国', region: '中国', lat: 34.3416, lon: 108.9398, bortle: 8 },
  { name: '昆明', country: '中国', region: '中国', lat: 25.0389, lon: 102.7183, bortle: 7 },
  { name: '哈尔滨', country: '中国', region: '中国', lat: 45.8038, lon: 126.5349, bortle: 7 },
  { name: '沈阳', country: '中国', region: '中国', lat: 41.8057, lon: 123.4315, bortle: 7 },
  { name: '长春', country: '中国', region: '中国', lat: 43.8171, lon: 125.3235, bortle: 7 },
  { name: '大连', country: '中国', region: '中国', lat: 38.9140, lon: 121.6147, bortle: 7 },
  { name: '石家庄', country: '中国', region: '中国', lat: 38.0428, lon: 114.5149, bortle: 8 },
  { name: '太原', country: '中国', region: '中国', lat: 37.8706, lon: 112.5489, bortle: 7 },
  { name: '呼和浩特', country: '中国', region: '中国', lat: 40.8426, lon: 111.7492, bortle: 7 },
  { name: '南京', country: '中国', region: '中国', lat: 32.0603, lon: 118.7969, bortle: 8 },
  { name: '杭州', country: '中国', region: '中国', lat: 30.2741, lon: 120.1551, bortle: 8 },
  { name: '苏州', country: '中国', region: '中国', lat: 31.2989, lon: 120.5853, bortle: 8 },
  { name: '宁波', country: '中国', region: '中国', lat: 29.8683, lon: 121.5440, bortle: 8 },
  { name: '合肥', country: '中国', region: '中国', lat: 31.8206, lon: 117.2272, bortle: 7 },
  { name: '福州', country: '中国', region: '中国', lat: 26.0745, lon: 119.2965, bortle: 7 },
  { name: '厦门', country: '中国', region: '中国', lat: 24.4798, lon: 118.0894, bortle: 7 },
  { name: '南昌', country: '中国', region: '中国', lat: 28.6820, lon: 115.8579, bortle: 7 },
  { name: '济南', country: '中国', region: '中国', lat: 36.6512, lon: 117.1201, bortle: 8 },
  { name: '青岛', country: '中国', region: '中国', lat: 36.0671, lon: 120.3826, bortle: 7 },
  { name: '郑州', country: '中国', region: '中国', lat: 34.7466, lon: 113.6254, bortle: 8 },
  { name: '武汉', country: '中国', region: '中国', lat: 30.5928, lon: 114.3055, bortle: 8 },
  { name: '长沙', country: '中国', region: '中国', lat: 28.2282, lon: 112.9388, bortle: 7 },
  { name: '南宁', country: '中国', region: '中国', lat: 22.8170, lon: 108.3665, bortle: 7 },
  { name: '海口', country: '中国', region: '中国', lat: 20.0440, lon: 110.1999, bortle: 7 },
  { name: '三亚', country: '中国', region: '中国', lat: 18.2528, lon: 109.5119, bortle: 6 },
  { name: '贵阳', country: '中国', region: '中国', lat: 26.6470, lon: 106.6302, bortle: 7 },
  { name: '桂林', country: '中国', region: '中国', lat: 25.2736, lon: 110.2900, bortle: 6 },
  { name: '珠海', country: '中国', region: '中国', lat: 22.2707, lon: 113.5767, bortle: 7 },
  { name: '乌鲁木齐', country: '中国', region: '中国', lat: 43.8256, lon: 87.6168, bortle: 6 },
  { name: '喀什', country: '中国', region: '中国', lat: 39.4704, lon: 75.9898, bortle: 5 },
  { name: '伊宁', country: '中国', region: '中国', lat: 43.9169, lon: 81.3241, bortle: 5 },
  { name: '拉萨', country: '中国', region: '中国', lat: 29.6520, lon: 91.1721, bortle: 4 },
  { name: '林芝', country: '中国', region: '中国', lat: 29.6489, lon: 94.3615, bortle: 3 },
  { name: '西宁', country: '中国', region: '中国', lat: 36.6171, lon: 101.7782, bortle: 5 },
  { name: '德令哈', country: '中国', region: '中国', lat: 37.3698, lon: 97.3701, bortle: 3 },
  { name: '兰州', country: '中国', region: '中国', lat: 36.0611, lon: 103.8343, bortle: 6 },
  { name: '银川', country: '中国', region: '中国', lat: 38.4872, lon: 106.2309, bortle: 5 },
  { name: '阿里', country: '中国', region: '中国', lat: 32.5030, lon: 80.1055, bortle: 1 },
  { name: '丽江', country: '中国', region: '中国', lat: 26.8721, lon: 100.2299, bortle: 4 },
  { name: '大理', country: '中国', region: '中国', lat: 25.6065, lon: 100.2676, bortle: 4 },
  { name: '稻城', country: '中国', region: '中国', lat: 29.0379, lon: 100.2980, bortle: 2 },
  { name: '香港', country: '中国', region: '中国', lat: 22.3193, lon: 114.1694, bortle: 8 },
  { name: '台北', country: '中国', region: '中国', lat: 25.0330, lon: 121.5654, bortle: 8 },

  // 亚洲
  { name: '东京', country: '日本', region: '亚洲', lat: 35.6762, lon: 139.6503, bortle: 9 },
  { name: '大阪', country: '日本', region: '亚洲', lat: 34.6937, lon: 135.5023, bortle: 8 },
  { name: '札幌', country: '日本', region: '亚洲', lat: 43.0618, lon: 141.3545, bortle: 7 },
  { name: '名古屋', country: '日本', region: '亚洲', lat: 35.1815, lon: 136.9066, bortle: 8 },
  { name: '福冈', country: '日本', region: '亚洲', lat: 33.5904, lon: 130.4017, bortle: 7 },
  { name: '那霸', country: '日本', region: '亚洲', lat: 26.2124, lon: 127.6809, bortle: 7 },
  { name: '首尔', country: '韩国', region: '亚洲', lat: 37.5665, lon: 126.9780, bortle: 9 },
  { name: '釜山', country: '韩国', region: '亚洲', lat: 35.1796, lon: 129.0756, bortle: 8 },
  { name: '曼谷', country: '泰国', region: '亚洲', lat: 13.7563, lon: 100.5018, bortle: 9 },
  { name: '清迈', country: '泰国', region: '亚洲', lat: 18.7883, lon: 98.9853, bortle: 7 },
  { name: '河内', country: '越南', region: '亚洲', lat: 21.0278, lon: 105.8342, bortle: 8 },
  { name: '胡志明市', country: '越南', region: '亚洲', lat: 10.8231, lon: 106.6297, bortle: 9 },
  { name: '马尼拉', country: '菲律宾', region: '亚洲', lat: 14.5995, lon: 120.9842, bortle: 9 },
  { name: '雅加达', country: '印度尼西亚', region: '亚洲', lat: -6.2088, lon: 106.8456, bortle: 9 },
  { name: '登巴萨', country: '印度尼西亚', region: '亚洲', lat: -8.6705, lon: 115.2126, bortle: 7 },
  { name: '吉隆坡', country: '马来西亚', region: '亚洲', lat: 3.1390, lon: 101.6869, bortle: 8 },
  { name: '新加坡', country: '新加坡', region: '亚洲', lat: 1.3521, lon: 103.8198, bortle: 9 },
  { name: '新德里', country: '印度', region: '亚洲', lat: 28.6139, lon: 77.2090, bortle: 9 },
  { name: '孟买', country: '印度', region: '亚洲', lat: 19.0760, lon: 72.8777, bortle: 9 },
  { name: '班加罗尔', country: '印度', region: '亚洲', lat: 12.9716, lon: 77.5946, bortle: 8 },
  { name: '列城', country: '印度', region: '亚洲', lat: 34.1526, lon: 77.5771, bortle: 3 },
  { name: '迪拜', country: '阿联酋', region: '亚洲', lat: 25.2048, lon: 55.2708, bortle: 9 },
  { name: '阿布扎比', country: '阿联酋', region: '亚洲', lat: 24.4539, lon: 54.3773, bortle: 8 },
  { name: '伊斯坦布尔', country: '土耳其', region: '亚洲', lat: 41.0082, lon: 28.9784, bortle: 9 },
  { name: '安卡拉', country: '土耳其', region: '亚洲', lat: 39.9334, lon: 32.8597, bortle: 8 },

  // 欧洲
  { name: '伦敦', country: '英国', region: '欧洲', lat: 51.5074, lon: -0.1278, bortle: 9 },
  { name: '爱丁堡', country: '英国', region: '欧洲', lat: 55.9533, lon: -3.1883, bortle: 7 },
  { name: '都柏林', country: '爱尔兰', region: '欧洲', lat: 53.3498, lon: -6.2603, bortle: 8 },
  { name: '巴黎', country: '法国', region: '欧洲', lat: 48.8566, lon: 2.3522, bortle: 9 },
  { name: '尼斯', country: '法国', region: '欧洲', lat: 43.7102, lon: 7.2620, bortle: 7 },
  { name: '柏林', country: '德国', region: '欧洲', lat: 52.5200, lon: 13.4050, bortle: 8 },
  { name: '慕尼黑', country: '德国', region: '欧洲', lat: 48.1351, lon: 11.5820, bortle: 7 },
  { name: '法兰克福', country: '德国', region: '欧洲', lat: 50.1109, lon: 8.6821, bortle: 8 },
  { name: '阿姆斯特丹', country: '荷兰', region: '欧洲', lat: 52.3676, lon: 4.9041, bortle: 8 },
  { name: '布鲁塞尔', country: '比利时', region: '欧洲', lat: 50.8503, lon: 4.3517, bortle: 8 },
  { name: '苏黎世', country: '瑞士', region: '欧洲', lat: 47.3769, lon: 8.5417, bortle: 7 },
  { name: '日内瓦', country: '瑞士', region: '欧洲', lat: 46.2044, lon: 6.1432, bortle: 7 },
  { name: '维也纳', country: '奥地利', region: '欧洲', lat: 48.2082, lon: 16.3738, bortle: 7 },
  { name: '布拉格', country: '捷克', region: '欧洲', lat: 50.0755, lon: 14.4378, bortle: 7 },
  { name: '华沙', country: '波兰', region: '欧洲', lat: 52.2297, lon: 21.0122, bortle: 7 },
  { name: '布达佩斯', country: '匈牙利', region: '欧洲', lat: 47.4979, lon: 19.0402, bortle: 7 },
  { name: '罗马', country: '意大利', region: '欧洲', lat: 41.9028, lon: 12.4964, bortle: 8 },
  { name: '米兰', country: '意大利', region: '欧洲', lat: 45.4642, lon: 9.1900, bortle: 8 },
  { name: '马德里', country: '西班牙', region: '欧洲', lat: 40.4168, lon: -3.7038, bortle: 8 },
  { name: '巴塞罗那', country: '西班牙', region: '欧洲', lat: 41.3874, lon: 2.1686, bortle: 8 },
  { name: '拉帕尔马', country: '西班牙', region: '欧洲', lat: 28.6835, lon: -17.7642, bortle: 2 },
  { name: '特内里费', country: '西班牙', region: '欧洲', lat: 28.4636, lon: -16.2518, bortle: 5 },
  { name: '里斯本', country: '葡萄牙', region: '欧洲', lat: 38.7223, lon: -9.1393, bortle: 8 },
  { name: '雅典', country: '希腊', region: '欧洲', lat: 37.9838, lon: 23.7275, bortle: 8 },
  { name: '斯德哥尔摩', country: '瑞典', region: '欧洲', lat: 59.3293, lon: 18.0686, bortle: 7 },
  { name: '奥斯陆', country: '挪威', region: '欧洲', lat: 59.9139, lon: 10.7522, bortle: 7 },
  { name: '特罗姆瑟', country: '挪威', region: '欧洲', lat: 69.6492, lon: 18.9553, bortle: 6 },
  { name: '哥本哈根', country: '丹麦', region: '欧洲', lat: 55.6761, lon: 12.5683, bortle: 7 },
  { name: '赫尔辛基', country: '芬兰', region: '欧洲', lat: 60.1699, lon: 24.9384, bortle: 7 },
  { name: '雷克雅未克', country: '冰岛', region: '欧洲', lat: 64.1466, lon: -21.9426, bortle: 6 },
  { name: '莫斯科', country: '俄罗斯', region: '欧洲', lat: 55.7558, lon: 37.6173, bortle: 9 },

  // 美洲
  { name: '纽约', country: '美国', region: '美洲', lat: 40.7128, lon: -74.0060, bortle: 9 },
  { name: '洛杉矶', country: '美国', region: '美洲', lat: 34.0522, lon: -118.2437, bortle: 9 },
  { name: '旧金山', country: '美国', region: '美洲', lat: 37.7749, lon: -122.4194, bortle: 8 },
  { name: '西雅图', country: '美国', region: '美洲', lat: 47.6062, lon: -122.3321, bortle: 8 },
  { name: '芝加哥', country: '美国', region: '美洲', lat: 41.8781, lon: -87.6298, bortle: 9 },
  { name: '波士顿', country: '美国', region: '美洲', lat: 42.3601, lon: -71.0589, bortle: 8 },
  { name: '华盛顿', country: '美国', region: '美洲', lat: 38.9072, lon: -77.0369, bortle: 8 },
  { name: '迈阿密', country: '美国', region: '美洲', lat: 25.7617, lon: -80.1918, bortle: 9 },
  { name: '丹佛', country: '美国', region: '美洲', lat: 39.7392, lon: -104.9903, bortle: 8 },
  { name: '休斯敦', country: '美国', region: '美洲', lat: 29.7604, lon: -95.3698, bortle: 9 },
  { name: '凤凰城', country: '美国', region: '美洲', lat: 33.4484, lon: -112.0740, bortle: 9 },
  { name: '希洛', country: '美国', region: '美洲', lat: 19.7071, lon: -155.0885, bortle: 6 },
  { name: '弗拉格斯塔夫', country: '美国', region: '美洲', lat: 35.1983, lon: -111.6513, bortle: 4 },
  { name: '安克雷奇', country: '美国', region: '美洲', lat: 61.2181, lon: -149.9003, bortle: 6 },
  { name: '檀香山', country: '美国', region: '美洲', lat: 21.3069, lon: -157.8583, bortle: 8 },
  { name: '多伦多', country: '加拿大', region: '美洲', lat: 43.6532, lon: -79.3832, bortle: 8 },
  { name: '温哥华', country: '加拿大', region: '美洲', lat: 49.2827, lon: -123.1207, bortle: 8 },
  { name: '蒙特利尔', country: '加拿大', region: '美洲', lat: 45.5017, lon: -73.5673, bortle: 8 },
  { name: '卡尔加里', country: '加拿大', region: '美洲', lat: 51.0447, lon: -114.0719, bortle: 7 },
  { name: '黄刀镇', country: '加拿大', region: '美洲', lat: 62.4540, lon: -114.3718, bortle: 3 },
  { name: '墨西哥城', country: '墨西哥', region: '美洲', lat: 19.4326, lon: -99.1332, bortle: 9 },
  { name: '圣保罗', country: '巴西', region: '美洲', lat: -23.5505, lon: -46.6333, bortle: 9 },
  { name: '里约热内卢', country: '巴西', region: '美洲', lat: -22.9068, lon: -43.1729, bortle: 9 },
  { name: '布宜诺斯艾利斯', country: '阿根廷', region: '美洲', lat: -34.6037, lon: -58.3816, bortle: 9 },
  { name: '门多萨', country: '阿根廷', region: '美洲', lat: -32.8895, lon: -68.8458, bortle: 6 },
  { name: '乌斯怀亚', country: '阿根廷', region: '美洲', lat: -54.8019, lon: -68.3030, bortle: 3 },
  { name: '圣地亚哥', country: '智利', region: '美洲', lat: -33.4489, lon: -70.6693, bortle: 8 },
  { name: '圣佩德罗-德阿塔卡马', country: '智利', region: '美洲', lat: -22.9099, lon: -68.1997, bortle: 1 },
  { name: '拉塞雷纳', country: '智利', region: '美洲', lat: -29.9027, lon: -71.2519, bortle: 3 },
  { name: '利马', country: '秘鲁', region: '美洲', lat: -12.0464, lon: -77.0428, bortle: 9 },
  { name: '波哥大', country: '哥伦比亚', region: '美洲', lat: 4.7110, lon: -74.0721, bortle: 8 },
  { name: '基多', country: '厄瓜多尔', region: '美洲', lat: -0.1807, lon: -78.4678, bortle: 8 },

  // 大洋洲
  { name: '悉尼', country: '澳大利亚', region: '大洋洲', lat: -33.8688, lon: 151.2093, bortle: 9 },
  { name: '墨尔本', country: '澳大利亚', region: '大洋洲', lat: -37.8136, lon: 144.9631, bortle: 8 },
  { name: '布里斯班', country: '澳大利亚', region: '大洋洲', lat: -27.4698, lon: 153.0251, bortle: 8 },
  { name: '珀斯', country: '澳大利亚', region: '大洋洲', lat: -31.9505, lon: 115.8605, bortle: 8 },
  { name: '阿德莱德', country: '澳大利亚', region: '大洋洲', lat: -34.9285, lon: 138.6007, bortle: 7 },
  { name: '霍巴特', country: '澳大利亚', region: '大洋洲', lat: -42.8821, lon: 147.3272, bortle: 6 },
  { name: '爱丽丝泉', country: '澳大利亚', region: '大洋洲', lat: -23.6980, lon: 133.8807, bortle: 1 },
  { name: '库纳巴拉布兰', country: '澳大利亚', region: '大洋洲', lat: -31.2730, lon: 149.2790, bortle: 2 },
  { name: '奥克兰', country: '新西兰', region: '大洋洲', lat: -36.8485, lon: 174.7633, bortle: 8 },
  { name: '惠灵顿', country: '新西兰', region: '大洋洲', lat: -41.2865, lon: 174.7762, bortle: 7 },
  { name: '基督城', country: '新西兰', region: '大洋洲', lat: -43.5321, lon: 172.6362, bortle: 6 },
  { name: '特卡波', country: '新西兰', region: '大洋洲', lat: -44.0049, lon: 170.4780, bortle: 1 },

  // 非洲
  { name: '开普敦', country: '南非', region: '非洲', lat: -33.9249, lon: 18.4241, bortle: 8 },
  { name: '约翰内斯堡', country: '南非', region: '非洲', lat: -26.2041, lon: 28.0473, bortle: 9 },
  { name: '萨瑟兰', country: '南非', region: '非洲', lat: -32.3790, lon: 20.6560, bortle: 1 },
  { name: '温得和克', country: '纳米比亚', region: '非洲', lat: -22.5609, lon: 17.0658, bortle: 4 },
  { name: '开罗', country: '埃及', region: '非洲', lat: 30.0444, lon: 31.2357, bortle: 9 },
  { name: '内罗毕', country: '肯尼亚', region: '非洲', lat: -1.2921, lon: 36.8219, bortle: 8 },
  { name: '马拉喀什', country: '摩洛哥', region: '非洲', lat: 31.6295, lon: -7.9811, bortle: 7 }
];

export const GPS_CITY_NAME: string = '当前位置';
export const GPS_CITY_REGION: string = 'GPS';

let gpsCityIndexValue: number = -1;

/**
 * One-shot GPS fix is stored as an extra City at the end of the array, so all
 * existing pages keep using cityIndex and CITIES[index] without a second
 * location model. The entry is created once per process and updated in place.
 */
export function ensureGpsCity(lat: number, lon: number): number {
  if (gpsCityIndexValue < 0 || gpsCityIndexValue >= CITIES.length) {
    const city: City = {
      name: GPS_CITY_NAME,
      country: 'GPS',
      region: GPS_CITY_REGION,
      lat: lat,
      lon: lon,
      bortle: 9
    };
    CITIES.push(city);
    gpsCityIndexValue = CITIES.length - 1;
  } else {
    const city: City = CITIES[gpsCityIndexValue];
    city.name = GPS_CITY_NAME;
    city.country = 'GPS';
    city.region = GPS_CITY_REGION;
    city.lat = lat;
    city.lon = lon;
  }
  return gpsCityIndexValue;
}

export function currentGpsCityIndex(): number {
  return gpsCityIndexValue;
}

export function clearGpsCity(): void {
  if (gpsCityIndexValue >= 0) {
    CITIES.splice(gpsCityIndexValue, 1);
    gpsCityIndexValue = -1;
  }
}
