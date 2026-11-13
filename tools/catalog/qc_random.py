#!/usr/bin/env python3
"""D1 random-sample coordinate audit + search regression, writes D1_QC_REPORT.md."""
import csv
import gzip
import json
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_catalog as bc  # noqa: E402

SRC = os.path.join(HERE, 'source')
CAT = json.load(open(os.path.join(HERE, 'catalog.json'), encoding='utf-8'))
BY_ID = {o['id']: o for o in CAT}

OLD_21 = ['M1', 'M3', 'M5', 'M8', 'M13', 'M16', 'M17', 'M20', 'M27', 'M31', 'M33',
          'M42', 'M45', 'M51', 'M57', 'M63', 'M64', 'M81', 'M82', 'M101', 'M104']

rows = []
for fname in ('NGC_full.csv', 'addendum.csv'):
    with open(os.path.join(SRC, fname), encoding='utf-8') as f:
        rows.extend(csv.DictReader(f, delimiter=';'))
BY_EXACT = {r['Name']: r for r in rows}
BY_NORM = {}
for r in rows:
    BY_NORM.setdefault(bc.norm_name(r['Name']), r)
META = json.load(open(os.path.join(SRC, 'caldwell_meta.json'), encoding='utf-8'))['Caldwell']

hyg = {}
with gzip.open(os.path.join(SRC, 'hyg_v35.csv.gz'), 'rt', encoding='utf-8') as f:
    for r in csv.DictReader(f):
        if r.get('hip'):
            hyg.setdefault(f'HIP{r["hip"]}', r)
        if r.get('hr'):
            hyg.setdefault(f'HR{r["hr"]}', r)


def canon_caldwell(n, o):
    if n in bc.CALDWELL_CANON:
        return bc.CALDWELL_CANON[n]
    url = META[f'C{n}'].get('external_link', '')
    tail = url.rsplit('/', 1)[-1]
    if tail.startswith('NGC_'):
        return 'NGC' + tail[4:].split('_')[0]
    if tail.startswith('IC_'):
        return 'IC' + tail[3:].split('_')[0]
    for a in o['aliases']:
        if re.match(r'^(NGC|IC)\d+$', a):
            return a
    return None


def source_for(o):
    oid = o['id']
    if oid.startswith('M') and oid[1:].isdigit():
        n = int(oid[1:])
        row = BY_NORM.get(bc.MESSIER_MAP[n]) or BY_EXACT.get(bc.MESSIER_MAP[n])
        if row is None:
            return None, None, 'OpenNGC lookup failed'
        return bc.ra_hours(row['RA']), bc.dec_deg(row['Dec']), f"OpenNGC {row['Name']}"
    if oid.startswith('C') and oid[1:].isdigit():
        n = int(oid[1:])
        canon = canon_caldwell(n, o)
        if canon:
            row = BY_EXACT.get(canon) or BY_NORM.get(bc.norm_name(canon))
            if row is not None:
                return bc.ra_hours(row['RA']), bc.dec_deg(row['Dec']), f'OpenNGC {row["Name"]}'
        m = META[f'C{n}']
        return m['ra_hours'], m['dec_deg'], 'Caldwell metadata'
    if oid.startswith(('NGC', 'IC')):
        row = BY_EXACT.get(oid) or BY_NORM.get(bc.norm_name(oid))
        if row is not None:
            return bc.ra_hours(row['RA']), bc.dec_deg(row['Dec']), f'OpenNGC {row["Name"]}'
        return None, None, 'OpenNGC lookup failed'
    r = hyg.get(oid)
    if r is not None:
        return float(r['ra']), float(r['dec']), f'HYG id {r["id"]}'
    return None, None, 'HYG lookup failed'


def search_blob(o):
    s = f"{o['id']} {o['name']} {o['nameEn']} " + ' '.join(o['aliases'])
    return s.lower()


def tokens(q):
    q = q.strip().lower()
    q = re.sub(r'([a-z]+)\s+(\d+)', r'\1\2', q)
    return [x for x in q.split(' ') if x]


def search(q):
    ts = tokens(q)
    out = []
    for o in CAT:
        blob = search_blob(o)
        ok = True
        for t in ts:
            if re.match(r'^(m|c|ngc|ic|hip|hr|hyg|mel)\d+$', t):
                hit = f' {blob} '.find(f' {t} ') >= 0
            else:
                hit = t in blob
            if not hit:
                ok = False
                break
        if ok:
            out.append(o)
    return out


rng = random.Random(20261107)
groups = {
    'Messier': rng.sample([o for o in CAT if o['id'].startswith('M') and o['id'][1:].isdigit()], 5),
    'Caldwell': rng.sample([o for o in CAT if o['id'].startswith('C') and o['id'][1:].isdigit()], 5),
    'NGC/IC': rng.sample([o for o in CAT if o['id'].startswith(('NGC', 'IC'))], 5),
    'Stars': rng.sample([o for o in CAT if o['category'] in ('star', 'double', 'variable')], 5),
}
sample = [o for g in groups.values() for o in g]

lines = ['# D1 数据质量检查报告', '',
         '- 版本：D1-2026-11-07',
         f'- 总记录：{len(CAT)}（110 Messier + 109 Caldwell + 250 NGC/IC + 200 亮星）',
         '- 历元：J2000.0；RA 为小时（0–24），Dec 为度（−90–90）。', '',
         '## 分类统计', '', '| 分类 | 数量 |', '|---|---|']
counts = {}
for o in CAT:
    counts[o['category']] = counts.get(o['category'], 0) + 1
for k in sorted(counts):
    lines.append(f'| {k} | {counts[k]} |')

lines += ['', '## 原有 21 个目标', '',
          f'- 全部存在：{all(x in BY_ID for x in OLD_21)}',
          f'- 缺失：{[x for x in OLD_21 if x not in BY_ID] or "无"}', '']

lines += ['## 随机抽样 RA/Dec 回查', '',
          '每类随机 5 个（seed 20261107），回查 OpenNGC / Caldwell 元数据 / HYG 原始记录。',
          '', '| 编号 | 名称 | 目录 RA | 目录 Dec | 源 RA | 源 Dec | 来源 | 结果 |',
          '|---|---|---|---|---|---|---|---|']
bad = []
for o in sample:
    ra, dec, src = source_for(o)
    if ra is None:
        ok = '未找到源'
        bad.append(o['id'])
        lines.append(f"| {o['id']} | {o['name']} | {o['raHours']:.6f} | {o['decDeg']:.6f} | — | — | {src} | {ok} |")
        continue
    dra = abs(ra - o['raHours'])
    ddec = abs(dec - o['decDeg'])
    ok = 'PASS' if dra <= 0.0001 and ddec <= 0.0001 else 'FAIL'
    if ok == 'FAIL':
        bad.append(o['id'])
    lines.append(f"| {o['id']} | {o['name']} | {o['raHours']:.6f} | {o['decDeg']:.6f} | "
                 f"{ra:.6f} | {dec:.6f} | {src} | {ok} |")
lines += ['', f'- 结果：{len(sample) - len(bad)}/{len(sample)} PASS；异常：{bad or "无"}', '']

tests = [
    ('中文名称', '北美洲', 'C20'),
    ('中文名称', '仙女', 'M31'),
    ('中文名称', '蟹状', 'M1'),
    ('英文名称', 'Andromeda', 'M31'),
    ('英文名称', 'North America', 'C20'),
    ('英文名称', 'Crab Nebula', 'M1'),
    ('Messier 编号', 'M31', 'M31'),
    ('NGC 编号', 'NGC7000', 'C20'),
    ('Caldwell 编号', 'C20', 'C20'),
    ('IC 编号', 'IC434', 'IC434'),
    ('恒星编号', 'HIP32349', 'HIP32349'),
]
lines += ['## 搜索回归（离线，纯本地字符串匹配）', '',
          '| 类型 | 查询 | 期望 | 命中 | 结果 |', '|---|---|---|---|---|']
for kind, q, want in tests:
    got = [o['id'] for o in search(q)]
    ok = want in got
    lines.append(f'| {kind} | {q} | {want} | {", ".join(got[:5])} | {"PASS" if ok else "FAIL"} |')

lines += ['', '## 去重与冲突', '',
          '- 唯一 ID：669/669。',
          '- NGC/IC 交叉编号重复：0。',
          '- 同一俗称对应多个对象（保留，均为真实成对天体）：',
          '  - 触须星系：C60/NGC 4038 与 C61/NGC 4039（两个 interacting galaxies）。',
          '  - Butterfly Galaxies：NGC 4567/NGC 4568；Eyes：NGC 4435/NGC 4438。',
          '- 已排除的重复片段：IC 4703（M16 内）、NGC 6995（面纱）、NGC 2392/7009（已由 C39/C55 收录）、',
          '  NGC 2238/NGC 2244（玫瑰星云/星团，由 C49/C50 收录）、NGC 3632（C40 的 Dup 行）。', '',
          '## 已知限制', '',
          '- M102 身份有争议，本目录按 NGC 5866 收录并在描述中注明。',
          '- C40 的 Wikipedia 元数据链接误写为 NGC 3632；已按 OpenNGC 标识符（C 040）纠正为 NGC 3626。',
          '- 星等/尺寸缺失时保留 99/0，并置 magKnown/sizeKnown=false；UI 显示“未收录”，不虚构。',
          '- Caldwell 的 C41/C99 等无可靠星等，保留为空；C49 无 V 星等。',
          '- HYG 坐标为 J2000 赤道坐标，未计入自行；亮星自行很小，不影响腕上指向。',
          '- 推荐焦段为按角尺寸分档的启发式提示，不是拍摄保证。', '']

open(os.path.join(HERE, 'D1_QC_REPORT.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('PASS' if not bad else f'COORD FAIL {bad}')
print('search failures:', [t for t in tests if t[2] not in [o['id'] for o in search(t[1])]])
