#!/usr/bin/env python3
"""Expire action labels using PROJECT.md evidence; never manufacture activity."""
import datetime as dt
import fcntl
import os
from pathlib import Path
import re
import subprocess
import tempfile

PHASES = {'继续做', '正在做', '当前可做', '条件做'}
LIMIT = 48 * 3600
STAMP = re.compile(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?\+08:00')


def table_rows(lines, heading):
    """Only rows within the named level-two section; retain exact byte spans."""
    active = False
    for index, line in enumerate(lines):
        if line.startswith('## '):
            active = line.rstrip() == '## ' + heading
        if not active or not line.lstrip().startswith('|'):
            continue
        cells = line.rstrip('\r\n').split('|')
        if len(cells) > 3 and re.fullmatch(r'(?:[0-9a-f]{16}|\d{4}-A\d+)', cells[1].strip()):
            yield index, cells


def classify(body, now=None):
    now = dt.datetime.now(dt.timezone.utc) if now is None else now
    if now.tzinfo is None:
        raise ValueError('Classification clock must be timezone-aware')
    lines = body.splitlines(keepends=True)
    evidence = {}
    gaps = {}
    for _, cells in table_rows(lines, '行动活跃依据'):
        key = cells[1].strip()
        if key in evidence:
            raise ValueError('Duplicate activity evidence: ' + key)
        if len(cells) < 6:
            raise ValueError('Malformed activity evidence: ' + key)
        evidence[key] = (cells[2].strip(), cells[3].strip())
    if not evidence:
        return body, [], {'activity': '行动活跃依据尚未建立；保留现有分类'}
    changes = []
    seen = set()
    for index, cells in table_rows(lines, '事项安排'):
        key = cells[1].strip()
        if key in seen:
            raise ValueError('Duplicate action identity: ' + key)
        seen.add(key)
        if len(cells) < 5:
            raise ValueError('Malformed action row: ' + key)
        old = cells[3].strip()
        labels = [s.strip() for s in re.split('[、,，]', old) if s.strip()]
        if any(label not in PHASES | {'优先做'} for label in labels):
            gaps[key] = '未知行动标签；保留原分类'
            continue
        # Existing explicit dependency is authoritative, even with recent work.
        if '条件做' in labels:
            phase = '条件做'
        else:
            if key not in evidence:
                gaps[key] = '缺少活跃依据；保留原分类'
                continue
            stamp, running = evidence[key]
            if running not in ('执行中', '未执行'):
                gaps[key] = '执行状态未核实；保留原分类'
                continue
            age = None
            if stamp:
                try:
                    if not STAMP.fullmatch(stamp):
                        raise ValueError('Expected ISO8601 +08:00')
                    age = (now - dt.datetime.fromisoformat(stamp)).total_seconds()
                    if age < 0:
                        raise ValueError('Future activity')
                except ValueError:
                    gaps[key] = '推进时间无效或在未来；保留原分类'
                    continue
            if running == '未执行' and age is None:
                # Missing observation is not evidence that 48 hours elapsed.
                gaps[key] = '缺少实质推进时间；保留原分类，需从来源任务回执补齐'
                continue
            phase = '正在做' if running == '执行中' or (age is not None and age < LIMIT) else '当前可做'
        new = ('优先做、' if '优先做' in labels else '') + phase
        if new == old:
            continue
        changes.append({'id': key, 'before': old, 'after': new})
        # Change only the label cell, not progress, source, evidence or calendar.
        spacing = cells[3]
        cells[3] = spacing[:len(spacing)-len(spacing.lstrip())] + new + spacing[len(spacing.rstrip()):]
        ending = '\r\n' if lines[index].endswith('\r\n') else '\n' if lines[index].endswith('\n') else ''
        lines[index] = '|'.join(cells) + ending
    return ''.join(lines), changes, gaps

