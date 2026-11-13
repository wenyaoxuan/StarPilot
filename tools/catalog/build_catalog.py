#!/usr/bin/env python3
"""StarPilot D1 catalog builder.

Inputs (tools/catalog/source):
  - NGC_full.csv        OpenNGC NGC/IC, CC-BY-SA-4.0
  - addendum.csv        OpenNGC addendum (M40/M45/M102, C9/C14/C41/C99, ...)
  - caldwell_meta.json  Caldwell metadata, MIT (thebioguy/Astro-Catalogue-Viewer)
  - hyg_v35.csv.gz      HYG v3.5, CC BY-SA 4.0 (repository LICENSE)

Outputs:
  - starpilot-watch/entry/src/main/ets/data/Messier.ets  (D1 CATALOG, legacy filename)
  - tools/catalog/catalog.json
  - tools/catalog/D1_QC_REPORT.md
"""
import csv
import gzip
import json
import math
import os
import re
import shutil
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'source')
ROOT = os.path.dirname(os.path.dirname(HERE))
WATCH = os.path.join(ROOT, 'starpilot-watch')
OUT_ETS = os.path.join(WATCH, 'entry', 'src', 'main', 'ets', 'data', 'Messier.ets')
LEGACY = os.path.join(HERE, 'legacy_Messier.ets')

CATALOG_VERSION = 'D1-2026-11-07'

# ---------------------------------------------------------------- name tables

MESSIER_CN = {
    1: '蟹状星云', 2: 'M2', 3: 'M3', 4: 'M4', 5: 'M5', 6: '蝴蝶星团', 7: '托勒密星团',
    8: '礁湖星云', 9: 'M9', 10: 'M10', 11: '野鸭星团', 12: 'M12', 13: '武仙座球状星团',
    14: 'M14', 15: '飞马座球状星团', 16: '鹰状星云', 17: '欧米伽星云', 18: 'M18',
    19: 'M19', 20: '三叶星云', 21: 'M21', 22: '人马座球状星团', 23: 'M23',
    24: '人马座恒星云', 25: 'M25', 26: 'M26', 27: '哑铃星云', 28: 'M28', 29: 'M29',
    30: 'M30', 31: '仙女座星系', 32: 'M32', 33: '三角座星系', 34: 'M34', 35: 'M35',
    36: 'M36', 37: 'M37', 38: 'M38', 39: 'M39', 40: '双星（Winnecke 4）', 41: 'M41',
    42: '猎户座大星云', 43: '德梅兰星云', 44: '蜂巢星团', 45: '昴星团', 46: 'M46',
    47: 'M47', 48: 'M48', 49: 'M49', 50: 'M50', 51: '涡状星系', 52: 'M52', 53: 'M53',
    54: 'M54', 55: 'M55', 56: 'M56', 57: '环状星云', 58: 'M58', 59: 'M59', 60: 'M60',
    61: 'M61', 62: 'M62', 63: '向日葵星系', 64: '黑眼星系', 65: 'M65', 66: 'M66',
    67: 'M67', 68: 'M68', 69: 'M69', 70: 'M70', 71: 'M71', 72: 'M72', 73: 'M73',
    74: 'M74', 75: 'M75', 76: '小哑铃星云', 77: 'M77', 78: 'M78', 79: 'M79', 80: 'M80',
    81: '波德星系', 82: '雪茄星系', 83: '南风车星系', 84: 'M84', 85: 'M85', 86: 'M86',
    87: 'M87', 88: 'M88', 89: 'M89', 90: 'M90', 91: 'M91', 92: 'M92', 93: 'M93',
    94: 'M94', 95: 'M95', 96: 'M96', 97: '猫头鹰星云', 98: 'M98', 99: 'M99',
    100: 'M100', 101: '风车星系', 102: 'M102（争议：NGC 5866）', 103: 'M103',
    104: '草帽星系', 105: 'M105', 106: 'M106', 107: 'M107', 108: 'M108', 109: 'M109',
    110: 'M110',
}

CALDWELL_CN = {
    2: '领结星云', 4: '鸢尾花星云', 6: '猫眼星云', 9: '洞穴星云', 11: '气泡星云',
    14: '英仙座双星团', 20: '北美洲星云', 27: '新月星云', 33: '面纱星云（东）',
    34: '面纱星云（西）', 39: '爱斯基摩星云', 40: 'C40（NGC 3626）', 41: '毕星团',
    49: '玫瑰星云', 50: 'NGC 2244 星团', 55: '土星状星云',
    60: '触须星系（NGC 4038）', 61: '触须星系（NGC 4039）',
    63: '螺旋星云', 65: '玉夫座星系', 77: '半人马座 A', 80: '半人马座 ω',
    92: '船底座星云', 94: '珠宝盒星团', 99: '煤袋星云', 102: '南昴星团',
    103: '蜘蛛星云', 106: '杜鹃座 47',
}

NGC_CN = {
    'NGC7000': '北美洲星云', 'NGC6960': '面纱星云（西）', 'NGC6992': '面纱星云（东）',
    'NGC2237': '玫瑰星云', 'NGC869': '英仙座双星团（h）', 'NGC884': '英仙座双星团（χ）',
    'NGC5139': '半人马座 ω', 'NGC104': '杜鹃座 47', 'NGC253': '玉夫座星系',
    'NGC4565': '针状星系', 'NGC6543': '猫眼星云', 'NGC7293': '螺旋星云',
    'NGC7635': '气泡星云', 'IC1396': '象鼻星云', 'IC434': '马头星云',
    'NGC2024': '火焰星云', 'NGC2359': '雷神头盔', 'NGC3372': '船底座星云',
    'NGC6334': '猫爪星云', 'NGC6357': '龙虾星云', 'NGC6888': '新月星云',
    'NGC7023': '鸢尾花星云', 'NGC7380': '巫师星云', 'NGC281': '吃豆人星云',
    'NGC1499': '加州星云', 'NGC1977': '跑步者星云', 'NGC2174': '猴头星云',
    'NGC2264': '圣诞树星团', 'NGC3532': '许愿井星团', 'NGC4755': '珠宝盒星团',
    'NGC5128': '半人马座 A', 'IC2602': '南昴星团', 'NGC2070': '蜘蛛星云',
    'NGC3242': '木星状星云', 'NGC6826': '眨眼星云', 'NGC7009': '土星状星云',
    'NGC7662': '蓝雪球星云', 'NGC1514': '水晶球星云', 'NGC246': '骷髅星云',
    'NGC3132': '八裂星云', 'NGC6302': '蝴蝶星云', 'NGC2392': '爱斯基摩星云',
    'NGC2867': '行星状星云', 'NGC3195': '行星状星云',
}

STAR_CN = {
    'Sirius': '天狼星', 'Canopus': '老人星', 'Arcturus': '大角星', 'Vega': '织女星',
    'Capella': '五车二', 'Rigel': '参宿七', 'Procyon': '南河三', 'Betelgeuse': '参宿四',
    'Achernar': '水委一', 'Hadar': '马腹一', 'Altair': '河鼓二', 'Acrux': '十字架二',
    'Aldebaran': '毕宿五', 'Antares': '心宿二', 'Spica': '角宿一', 'Pollux': '北河三',
    'Fomalhaut': '北落师门', 'Deneb': '天津四', 'Mimosa': '十字架三', 'Regulus': '轩辕十四',
    'Adhara': '弧矢七', 'Castor': '北河二', 'Shaula': '尾宿八', 'Gacrux': '十字架一',
    'Bellatrix': '参宿五', 'Elnath': '五车五', 'Miaplacidus': '南船五', 'Alnilam': '参宿二',
    'Alnair': '鹤一', 'Alioth': '玉衡', 'Dubhe': '天枢', 'Mirfak': '天船三',
    'Wezen': '弧矢一', 'Sargas': '尾宿五', 'Kaus Australis': '箕宿三', 'Avior': '海石一',
    'Alkaid': '摇光', 'Menkalinan': '五车三', 'Atria': '三角形三', 'Alhena': '井宿三',
    'Peacock': '孔雀十一', 'Polaris': '北极星', 'Mirzam': '军市一', 'Alphard': '星宿一',
    'Algieba': '轩辕十二', 'Hamal': '娄宿三', 'Diphda': '土司空', 'Nunki': '斗宿四',
    'Menkent': '库楼三', 'Alpheratz': '壁宿二', 'Mirach': '奎宿九', 'Saiph': '参宿六',
    'Kochab': '北极二', 'Rasalhague': '侯', 'Algol': '大陵五', 'Denebola': '五帝座一',
    'Mizar': '开阳', 'Alphecca': '贯索四', 'Suhail': '天社一', 'Sadr': '天津一',
    'Eltanin': '天棓四', 'Ruchbah': '阁道三', 'Schedar': '王良四',
}

CON_CN = {
    'And': '仙女座', 'Ant': '唧筒座', 'Aps': '天燕座', 'Aqr': '宝瓶座', 'Aql': '天鹰座',
    'Ara': '天坛座', 'Ari': '白羊座', 'Aur': '御夫座', 'Boo': '牧夫座', 'Cae': '雕具座',
    'Cam': '鹿豹座', 'Cnc': '巨蟹座', 'CVn': '猎犬座', 'CMa': '大犬座', 'CMi': '小犬座',
    'Cap': '摩羯座', 'Car': '船底座', 'Cas': '仙后座', 'Cen': '半人马座', 'Cep': '仙王座',
    'Cet': '鲸鱼座', 'Cha': '蝘蜓座', 'Cir': '圆规座', 'Col': '天鸽座', 'Com': '后发座',
    'CrA': '南冕座', 'CrB': '北冕座', 'Crv': '乌鸦座', 'Crt': '巨爵座', 'Cru': '南十字座',
    'Cyg': '天鹅座', 'Del': '海豚座', 'Dor': '剑鱼座', 'Dra': '天龙座', 'Equ': '小马座',
    'Eri': '波江座', 'For': '天炉座', 'Gem': '双子座', 'Gru': '天鹤座', 'Her': '武仙座',
    'Hor': '时钟座', 'Hya': '长蛇座', 'Hyi': '水蛇座', 'Ind': '印第安座', 'Lac': '蝎虎座',
    'Leo': '狮子座', 'LMi': '小狮座', 'Lep': '天兔座', 'Lib': '天秤座', 'Lup': '豺狼座',
    'Lyn': '天猫座', 'Lyr': '天琴座', 'Men': '山案座', 'Mic': '显微镜座', 'Mon': '麒麟座',
    'Mus': '苍蝇座', 'Nor': '矩尺座', 'Oct': '南极座', 'Oph': '蛇夫座', 'Ori': '猎户座',
    'Pav': '孔雀座', 'Peg': '飞马座', 'Per': '英仙座', 'Phe': '凤凰座', 'Pic': '绘架座',
    'Psc': '双鱼座', 'PsA': '南鱼座', 'Pup': '船尾座', 'Pyx': '罗盘座', 'Ret': '网罟座',
    'Sge': '天箭座', 'Sgr': '人马座', 'Sco': '天蝎座', 'Scl': '玉夫座', 'Sct': '盾牌座',
    'Ser': '巨蛇座', 'Sex': '六分仪座', 'Tau': '金牛座', 'Tel': '望远镜座', 'Tri': '三角座',
    'TrA': '南三角座', 'Tuc': '杜鹃座', 'UMa': '大熊座', 'UMi': '小熊座', 'Vel': '船帆座',
    'Vir': '室女座', 'Vol': '飞鱼座', 'Vul': '狐狸座',
}

GREEK = {
    'Alp': 'α', 'Alpha': 'α', 'Bet': 'β', 'Beta': 'β', 'Gam': 'γ', 'Gamma': 'γ',
    'Del': 'δ', 'Delta': 'δ', 'Eps': 'ε', 'Epsilon': 'ε', 'Zet': 'ζ', 'Zeta': 'ζ',
    'Eta': 'η', 'The': 'θ', 'Theta': 'θ', 'Iot': 'ι', 'Iota': 'ι', 'Kap': 'κ',
    'Kappa': 'κ', 'Lam': 'λ', 'Lambda': 'λ', 'Mu': 'μ', 'Nu': 'ν', 'Xi': 'ξ',
    'Omi': 'ο', 'Omicron': 'ο', 'Pi': 'π', 'Rho': 'ρ', 'Sig': 'σ', 'Sigma': 'σ',
    'Tau': 'τ', 'Ups': 'υ', 'Upsilon': 'υ', 'Phi': 'φ', 'Chi': 'χ', 'Psi': 'ψ',
    'Ome': 'ω', 'Omega': 'ω',
}

TYPE_MAP = {
    'G': ('星系', 'galaxy'), 'GPair': ('星系群', 'galaxy'), 'GTrpl': ('星系群', 'galaxy'),
    'GGroup': ('星系群', 'galaxy'), 'GCl': ('球状星团', 'cluster'), 'OCl': ('疏散星团', 'cluster'),
    'Cl+N': ('星云', 'nebula'), 'PN': ('行星状星云', 'nebula'), 'SNR': ('超新星遗迹', 'nebula'),
    'HII': ('发射星云', 'nebula'), 'EmN': ('发射星云', 'nebula'), 'RfN': ('反射星云', 'nebula'),
    'DrkN': ('暗星云', 'nebula'), 'Neb': ('星云', 'nebula'), '**': ('双星', 'double'),
    '*': ('恒星', 'star'), '*Ass': ('星群', 'cluster'),
}

CALDWELL_TYPE = {
    'Open Cluster': ('疏散星团', 'cluster'), 'Globular Cluster': ('球状星团', 'cluster'),
    'Galaxy': ('星系', 'galaxy'), 'HII Region': ('发射星云', 'nebula'),
    'Nebula': ('星云', 'nebula'), 'Planetary Nebula': ('行星状星云', 'nebula'),
    'Supernova Remnant': ('超新星遗迹', 'nebula'), 'Dark Nebula': ('暗星云', 'nebula'),
    'Association of Stars': ('星群', 'cluster'), 'Double Star': ('双星', 'double'),
    'Star Cloud': ('星群', 'cluster'), 'Cluster + Nebula': ('疏散星团', 'cluster'),
}

MESSIER_MAP = {
    1: 'NGC1952', 2: 'NGC7089', 3: 'NGC5272', 4: 'NGC6121', 5: 'NGC5904', 6: 'NGC6405',
    7: 'NGC6475', 8: 'NGC6523', 9: 'NGC6333', 10: 'NGC6254', 11: 'NGC6705', 12: 'NGC6218',
    13: 'NGC6205', 14: 'NGC6402', 15: 'NGC7078', 16: 'NGC6611', 17: 'NGC6618', 18: 'NGC6613',
    19: 'NGC6273', 20: 'NGC6514', 21: 'NGC6531', 22: 'NGC6656', 23: 'NGC6494', 24: 'IC4715',
    25: 'IC4725', 26: 'NGC6694', 27: 'NGC6853', 28: 'NGC6626', 29: 'NGC6913', 30: 'NGC7099',
    31: 'NGC224', 32: 'NGC221', 33: 'NGC598', 34: 'NGC1039', 35: 'NGC2168', 36: 'NGC1960',
    37: 'NGC2099', 38: 'NGC1912', 39: 'NGC7092', 40: 'M040', 41: 'NGC2287', 42: 'NGC1976',
    43: 'NGC1982', 44: 'NGC2632', 45: 'Mel022', 46: 'NGC2437', 47: 'NGC2422', 48: 'NGC2548',
    49: 'NGC4472', 50: 'NGC2323', 51: 'NGC5194', 52: 'NGC7654', 53: 'NGC5024', 54: 'NGC6715',
    55: 'NGC6809', 56: 'NGC6779', 57: 'NGC6720', 58: 'NGC4579', 59: 'NGC4621', 60: 'NGC4649',
    61: 'NGC4303', 62: 'NGC6266', 63: 'NGC5055', 64: 'NGC4826', 65: 'NGC3623', 66: 'NGC3627',
    67: 'NGC2682', 68: 'NGC4590', 69: 'NGC6637', 70: 'NGC6681', 71: 'NGC6838', 72: 'NGC6981',
    73: 'NGC6994', 74: 'NGC628', 75: 'NGC6864', 76: 'NGC650', 77: 'NGC1068', 78: 'NGC2068',
    79: 'NGC1904', 80: 'NGC6093', 81: 'NGC3031', 82: 'NGC3034', 83: 'NGC5236', 84: 'NGC4374',
    85: 'NGC4382', 86: 'NGC4406', 87: 'NGC4486', 88: 'NGC4501', 89: 'NGC4552', 90: 'NGC4569',
    91: 'NGC4548', 92: 'NGC6341', 93: 'NGC2447', 94: 'NGC4736', 95: 'NGC3351', 96: 'NGC3368',
    97: 'NGC3587', 98: 'NGC4192', 99: 'NGC4254', 100: 'NGC4321', 101: 'NGC5457', 102: 'NGC5866',
    103: 'NGC581', 104: 'NGC4594', 105: 'NGC3379', 106: 'NGC4258', 107: 'NGC6171',
    108: 'NGC3556', 109: 'NGC3992', 110: 'NGC205',
}

CALDWELL_CANON = {
    4: 'NGC7023', 6: 'NGC6543', 9: 'C009', 11: 'NGC7635', 14: 'C014', 20: 'NGC7000',
    27: 'NGC6888', 33: 'NGC6992', 34: 'NGC6960', 39: 'NGC2392', 40: 'NGC3626',
    41: 'C041', 49: 'NGC2237', 50: 'NGC2239', 55: 'NGC7009',
    60: 'NGC4038', 61: 'NGC4039',
    63: 'NGC7293', 77: 'NGC5128', 80: 'NGC5139', 92: 'NGC3372', 94: 'NGC4755',
    99: 'C099', 106: 'NGC104',
}

# Fragments/duplicates that share a popular name with a Messier/Caldwell entry.
DENY_NGC = {'IC4703', 'NGC1990', 'NGC2238', 'NGC2244', 'NGC3632', 'NGC6995'}

DOUBLE_NAMES = {'Mizar', 'Albireo', 'Castor', 'Algieba', 'Acrux'}
VARIABLE_NAMES = {'Algol', 'Betelgeuse', 'Sheliak', 'Delta Cephei', 'Eta Carinae', 'Polaris'}


# ---------------------------------------------------------------- helpers

def norm_name(name):
    m = re.match(r'^(NGC|IC)0*(\d+)$', name)
    if m:
        return f'{m.group(1)}{m.group(2)}'
    return name


def ra_hours(text):
    h, m, s = text.split(':')
    return int(h) + int(m) / 60.0 + float(s) / 3600.0


def dec_deg(text):
    sign = -1.0 if text.startswith('-') else 1.0
    d, m, s = text.lstrip('+-').split(':')
    return sign * (int(d) + int(m) / 60.0 + float(s) / 3600.0)


def fnum(text, default=0.0):
    try:
        return float(text)
    except (TypeError, ValueError):
        return default


def focal(size):
    if not size or size <= 0:
        return ''
    if size >= 60:
        return '135–300mm'
    if size >= 20:
        return '300–600mm'
    if size >= 5:
        return '600–1200mm'
    return '1200–2000mm'


def season_from_months(months):
    if not months:
        return ''
    mm = re.findall(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)', months)
    nums = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
            'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12}
    vals = sorted({nums[x] for x in mm})
    if not vals:
        return ''
    if len(vals) == 1:
        return f'{vals[0]}月'
    return f'{vals[0]}–{vals[-1]}月'


def parse_openngc_rows():
    rows = []
    for fname in ('NGC_full.csv', 'addendum.csv'):
        with open(os.path.join(SRC, fname), encoding='utf-8') as f:
            rows.extend(csv.DictReader(f, delimiter=';'))
    by_norm = {}
    by_m = {}
    for r in rows:
        name = r.get('Name', '')
        if not name:
            continue
        n = norm_name(name)
        by_norm.setdefault(n, r)
        if r.get('M'):
            by_m.setdefault(int(r['M']), r)
    return rows, by_norm, by_m


def obj_from_row(row, oid, cn_name, cn_alias, source, desc, name_en=None):
    typ, cat = TYPE_MAP.get(row['Type'], ('天体', 'other'))
    # M42/M43/M8/M16/M20 are nebulae even where OpenNGC says Cl+N/Neb.
    if oid in ('M42', 'M43', 'M8', 'M16', 'M20'):
        typ, cat = '发射星云', 'nebula'
    if oid == 'M40':
        typ, cat = '双星', 'double'
    if oid == 'M24' or oid == 'M73':
        typ, cat = '星群', 'cluster'
    if oid == 'C14':
        typ, cat = '疏散星团', 'cluster'
    ra = ra_hours(row['RA'])
    dec = dec_deg(row['Dec'])
    maj = fnum(row['MajAx'])
    mino = fnum(row['MinAx'], maj)
    vmag = fnum(row['V-Mag'], fnum(row['B-Mag'], 99))
    mag_known = vmag < 90
    mag = vmag if mag_known else 99.0
    common = [x.strip() for x in row.get('Common names', '').split(',') if x.strip()]
    aliases = []
    for x in [oid, *cn_alias, *common, norm_name(row['Name']), row['Name']]:
        if x and x not in aliases:
            aliases.append(x)
    if name_en is None:
        name_en = common[0] if common else norm_name(row['Name'])
    return {
        'id': oid,
        'name': cn_name,
        'nameEn': name_en,
        'aliases': aliases,
        'type': typ,
        'category': cat,
        'raHours': round(ra, 6),
        'decDeg': round(dec, 6),
        'epoch': 2000.0,
        'mag': round(mag, 2),
        'magKnown': mag_known,
        'sizeA': round(maj, 2),
        'sizeB': round(mino, 2),
        'sizeKnown': maj > 0,
        'surfaceBrightness': round(fnum(row['SurfBr'], 0.0), 2),
        'distanceLy': 0.0,
        'fl': focal(maj),
        'season': '',
        'desc': desc,
        'source': source,
    }


def build_messier(rows, by_norm, by_m, old_desc):
    out = []
    used = set()
    for m in range(1, 111):
        target = MESSIER_MAP[m]
        row = by_norm.get(target)
        if row is None:
            row = by_m.get(m)
        if row is None:
            print(f'WARN: no OpenNGC row for M{m} -> {target}')
            continue
        cn = MESSIER_CN.get(m, f'M{m}')
        oid = f'M{m}'
        o = obj_from_row(row, oid, cn, [f'Messier {m}', f'M {m}'], 'OpenNGC CC-BY-SA-4.0',
                         old_desc.get(oid, ''))
        # Ensure the Messier designations are searchable even if row aliases lack them.
        for a in [f'Messier {m}', f'M {m}', f'M{m}']:
            if a not in o['aliases']:
                o['aliases'].append(a)
        if m == 102:
            o['desc'] = 'M102 身份有争议；按 NGC 5866 收录。'
            o['aliases'].append('NGC5866')
        if m == 40:
            o['aliases'].append('Winnecke 4')
        if m == 73:
            o['desc'] = '星群/星协，并非真实星团。'
        out.append(o)
        used.add(norm_name(row['Name']))
    return out, used


def build_caldwell(by_norm, by_nn, meta):
    out = []
    used = set()
    for n in range(1, 110):
        key = f'C{n}'
        if key not in meta:
            print('WARN missing Caldwell', key)
            continue
        m = meta[key]
        canon = CALDWELL_CANON.get(n)
        if canon is None:
            url = m.get('external_link', '')
            tail = url.rsplit('/', 1)[-1]
            if tail.startswith('NGC_'):
                canon = 'NGC' + tail[4:].split('_')[0]
            elif tail.startswith('IC_'):
                canon = 'IC' + tail[3:].split('_')[0]
            else:
                canon = key
        row = by_norm.get(norm_name(canon))
        if row is None:
            # C9/C14/C41/C99 are addendum rows named C009 etc.
            row = by_nn.get(canon)
        cn = CALDWELL_CN.get(n, key)
        if row is not None:
            o = obj_from_row(row, key, cn, [f'Caldwell {n}', f'C {n}'], 
                             'Caldwell metadata (MIT) + OpenNGC', '')
            # Use metadata coordinates if OpenNGC row is a combined/ambiguous object.
            if n in (14,):
                o['raHours'] = round(m['ra_hours'], 6)
                o['decDeg'] = round(m['dec_deg'], 6)
            used.add(norm_name(row['Name']))
            if n == 14:
                used.update(['NGC869', 'NGC884'])
                for a in ['NGC869', 'NGC884', 'h Persei', 'chi Persei']:
                    o['aliases'].append(a)
        else:
            typ, cat = CALDWELL_TYPE.get(m.get('type', ''), ('天体', 'other'))
            o = {
                'id': key, 'name': cn, 'nameEn': m.get('name') or key,
                'aliases': [key, f'Caldwell {n}', f'C {n}', canon],
                'type': typ, 'category': cat,
                'raHours': round(m['ra_hours'], 6), 'decDeg': round(m['dec_deg'], 6),
                'epoch': 2000.0, 'mag': 99.0, 'magKnown': False,
                'sizeA': 0.0, 'sizeB': 0.0, 'sizeKnown': False,
                'surfaceBrightness': 0.0, 'distanceLy': 0.0, 'fl': '',
                'season': '', 'desc': '', 'source': 'Caldwell metadata (MIT)',
            }
        if m.get('name') and m['name'] not in o['aliases']:
            o['aliases'].append(m['name'])
        if m.get('distance_ly'):
            o['distanceLy'] = round(float(m['distance_ly']), 1)
        o['season'] = season_from_months(m.get('best_months', ''))
        if n == 92 or n == 49:
            o['type'], o['category'] = '发射星云', 'nebula'
        if n == 50:
            o['type'], o['category'] = '疏散星团', 'cluster'
        out.append(o)
    return out, used


def build_ngc(rows, used, limit=250):
    buckets = {'galaxy': [], 'nebula': [], 'cluster': []}
    seen = set()
    for r in rows:
        name = r.get('Name', '')
        if not re.match(r'^(NGC|IC)\d+$', name):
            continue
        n = norm_name(name)
        if n in used or n in seen or n in DENY_NGC:
            continue
        if r.get('M'):
            continue
        if r['Type'] not in TYPE_MAP:
            continue
        typ, cat = TYPE_MAP[r['Type']]
        if cat not in buckets:
            continue
        maj = fnum(r['MajAx'])
        vmag = fnum(r['V-Mag'], fnum(r['B-Mag'], 99))
        common = r.get('Common names', '').strip()
        if not common and not (vmag <= 11 and maj >= 3):
            continue
        seen.add(n)
        score = (0 if common else 1, vmag, -maj)
        buckets[cat].append((score, r))
    for cat in buckets:
        buckets[cat].sort(key=lambda x: x[0])
    # Balanced selection: galaxies get the largest share, then nebulae, then clusters.
    quotas = {'galaxy': 90, 'nebula': 85, 'cluster': 75}
    picked = []
    for cat, q in quotas.items():
        picked.extend(buckets[cat][:q])
    if len(picked) < limit:
        rest = []
        for cat, q in quotas.items():
            rest.extend(buckets[cat][q:])
        rest.sort(key=lambda x: x[0])
        picked.extend(rest[:limit - len(picked)])
    out = []
    for score, r in picked[:limit]:
        n = norm_name(r['Name'])
        cn = NGC_CN.get(n, n.replace('NGC', 'NGC ').replace('IC', 'IC '))
        o = obj_from_row(r, n, cn, [], 'OpenNGC CC-BY-SA-4.0', '')
        out.append(o)
    return out


def build_stars(limit=200):
    rows = []
    with gzip.open(os.path.join(SRC, 'hyg_v35.csv.gz'), 'rt', encoding='utf-8') as f:
        for r in csv.DictReader(f):
            try:
                mag = float(r['mag'])
            except (TypeError, ValueError):
                continue
            if r.get('proper') == 'Sol' or mag > 6:
                continue
            rows.append(r)
    rows.sort(key=lambda r: float(r['mag']))
    out = []
    seen = set()
    seen_pos = set()
    for r in rows:
        if len(out) >= limit:
            break
        hip = r.get('hip') or ''
        hr = r.get('hr') or ''
        oid = f'HIP{hip}' if hip else (f'HR{hr}' if hr else f'HYG{r["id"]}')
        if oid in seen:
            continue
        proper = (r.get('proper') or '').strip()
        if proper and proper in {x for x in seen}:
            continue
        pos = (round(float(r['ra']), 3), round(float(r['dec']), 2))
        if pos in seen_pos:
            continue
        seen.add(oid)
        seen_pos.add(pos)
        if proper:
            seen.add(proper)
        con = (r.get('con') or '').strip()
        bayer = (r.get('bayer') or '').strip()
        flam = (r.get('flam') or '').strip()
        if proper in STAR_CN:
            cn = STAR_CN[proper]
        elif bayer and con in CON_CN and bayer in GREEK:
            cn = f'{CON_CN[con]}{GREEK[bayer]}'
        elif flam and con in CON_CN:
            cn = f'{CON_CN[con]}{flam}星'
        else:
            cn = oid
        name_en = proper or (r.get('bf') or '').strip() or oid
        if proper in DOUBLE_NAMES:
            typ, cat = '双星', 'double'
        elif proper in VARIABLE_NAMES or (r.get('var') or '').strip():
            typ, cat = '变星', 'variable'
        else:
            typ, cat = '恒星', 'star'
        aliases = [oid]
        for a in [proper, (r.get('bf') or '').strip(), f'HR {hr}' if hr else '',
                  f'HIP {hip}' if hip else '', cn]:
            if a and a not in aliases:
                aliases.append(a)
        dist_pc = fnum(r.get('dist'), 0.0)
        out.append({
            'id': oid, 'name': cn, 'nameEn': name_en, 'aliases': aliases,
            'type': typ, 'category': cat,
            'raHours': round(float(r['ra']), 6), 'decDeg': round(float(r['dec']), 6),
            'epoch': 2000.0, 'mag': round(float(r['mag']), 2), 'magKnown': True,
            'sizeA': 0.0, 'sizeB': 0.0, 'sizeKnown': False,
            'surfaceBrightness': 0.0,
            'distanceLy': round(dist_pc * 3.26156, 1) if dist_pc > 0 else 0.0,
            'fl': '', 'season': '', 'desc': '',
            'source': 'HYG v3.5 (CC BY-SA 4.0)',
        })
    return out


def main():
    if not os.path.exists(LEGACY) and os.path.exists(OUT_ETS):
        shutil.copy(OUT_ETS, LEGACY)
    old_desc = {}
    if os.path.exists(LEGACY):
        txt = open(LEGACY, encoding='utf-8').read()
        for m in re.finditer(r"\{ id: '(M\d+)'.*?desc: '([^']*)' \}", txt):
            old_desc[m.group(1)] = m.group(2)
    rows, by_norm, by_m = parse_openngc_rows()
    by_nn = {r['Name']: r for r in rows}
    meta = json.load(open(os.path.join(SRC, 'caldwell_meta.json'), encoding='utf-8'))['Caldwell']
    messier, used_m = build_messier(rows, by_norm, by_m, old_desc)
    caldwell, used_c = build_caldwell(by_norm, by_nn, meta)
    used = used_m | used_c
    ngc = build_ngc(rows, used, 250)
    stars = build_stars(200)
    catalog = messier + caldwell + ngc + stars

    # validation
    ids = [o['id'] for o in catalog]
    assert len(ids) == len(set(ids)), 'duplicate ids'
    for o in catalog:
        assert 0 <= o['raHours'] < 24, o
        assert -90 <= o['decDeg'] <= 90, o
        assert o['mag'] == 99 or -2 < o['mag'] < 25, o
        assert o['sizeA'] >= 0 and o['sizeB'] >= 0, o
    canon = {}
    for o in catalog:
        key = norm_name(o['id'])
        for a in o['aliases']:
            na = norm_name(a)
            if re.match(r'^(NGC|IC)\d+$', na):
                canon.setdefault(na, set()).add(o['id'])
    dup_canon = {k: v for k, v in canon.items() if len(v) > 1}
    alias_map = {}
    for o in catalog:
        for a in o['aliases']:
            alias_map.setdefault(a.lower(), set()).add(o['id'])
    dup_alias = {k: v for k, v in alias_map.items() if len(v) > 1}

    write_ets(catalog)
    json.dump(catalog, open(os.path.join(HERE, 'catalog.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    write_qc(catalog, dup_canon, dup_alias, used)
    print('DONE', {
        'messier': len(messier), 'caldwell': len(caldwell), 'ngc': len(ngc),
        'stars': len(stars), 'total': len(catalog),
        'dup_canon': len(dup_canon), 'dup_alias': len(dup_alias),
    })


def write_ets(catalog):
    lines = []
    lines.append("// Generated by tools/catalog/build_catalog.py — do not hand-edit.")
    lines.append(f"// Catalog version: {CATALOG_VERSION}")
    lines.append("// Sources: OpenNGC (CC-BY-SA-4.0), Caldwell metadata (MIT), HYG v3.5 (CC BY-SA 4.0).")
    lines.append("")
    lines.append("export interface MessierObject {")
    for f, t in [
        ('id', 'string'), ('name', 'string'), ('nameEn', 'string'), ('aliases', 'string[]'),
        ('type', 'string'), ('category', 'string'), ('raHours', 'number'), ('decDeg', 'number'),
        ('epoch', 'number'), ('mag', 'number'), ('magKnown', 'boolean'),
        ('sizeA', 'number'), ('sizeB', 'number'), ('sizeKnown', 'boolean'),
        ('surfaceBrightness', 'number'), ('distanceLy', 'number'),
        ('fl', 'string'), ('season', 'string'), ('desc', 'string'), ('source', 'string'),
    ]:
        lines.append(f"  {f}: {t};")
    lines.append("}")
    lines.append("")
    lines.append(f"export const CATALOG_VERSION: string = '{CATALOG_VERSION}';")
    lines.append("export const CATALOG: MessierObject[] = [")
    for o in catalog:
        lines.append('  ' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + ',')
    lines.append("];")
    lines.append("")
    lines.append("// Legacy name kept so NavPage/PhotoPage/target persistence keep working.")
    lines.append("export const MESSIER: MessierObject[] = CATALOG;")
    lines.append("")
    lines.append("export function raText(o: MessierObject): string {")
    lines.append("  const h: number = Math.floor(o.raHours);")
    lines.append("  const m: number = Math.round((o.raHours - h) * 60);")
    lines.append("  return `${h}h ${m < 10 ? '0' : ''}${m}m`;")
    lines.append("}")
    lines.append("")
    lines.append("export function decText(o: MessierObject): string {")
    lines.append("  const sign: string = o.decDeg >= 0 ? '+' : '-';")
    lines.append("  const abs: number = Math.abs(o.decDeg);")
    lines.append("  const d: number = Math.floor(abs);")
    lines.append("  const m: number = Math.round((abs - d) * 60);")
    lines.append("  return `${sign}${d}° ${m < 10 ? '0' : ''}${m}′`;")
    lines.append("}")
    open(OUT_ETS, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')


def write_qc(catalog, dup_canon, dup_alias, used):
    counts = {}
    for o in catalog:
        counts[o['category']] = counts.get(o['category'], 0) + 1
    lines = ['# D1 数据质量检查报告', '', f'- 生成时间：{datetime.now().isoformat(timespec="seconds")}',
             f'- 版本：{CATALOG_VERSION}', f'- 总记录：{len(catalog)}', '',
             '## 分类统计', '', '| 分类 | 数量 |', '|---|---|']
    for k in sorted(counts):
        lines.append(f'| {k} | {counts[k]} |')
    lines += ['', '## 编号去重', '', f'- 唯一 ID：{len({o["id"] for o in catalog})}',
              f'- NGC/IC 交叉编号冲突：{len(dup_canon)}']
    for k, v in list(dup_canon.items())[:20]:
        lines.append(f'  - {k}: {sorted(v)}')
    lines += ['', '## 别名冲突', '', f'- 同名/同别名指向多个对象：{len(dup_alias)}']
    for k, v in list(dup_alias.items())[:20]:
        lines.append(f'  - {k}: {sorted(v)}')
    lines += ['', '## 坐标范围', '', '- RA 0–24h、Dec −90–90、epoch 2000 全部通过。']
    open(os.path.join(HERE, 'D1_QC_REPORT.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
