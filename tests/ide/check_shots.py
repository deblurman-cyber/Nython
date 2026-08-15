import sys, os
from PIL import ImageFont
F={(0,0):'/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',(0,1):'/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
   (1,0):'/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',(1,1):'/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'}
_c={}
def _f(s,m,b):
    k=(s,m,b)
    if k not in _c: _c[k]=ImageFont.truetype(F[(m,b)],s)
    return _c[k]
def runs(shot):
    out=[]
    with open('/tmp/shot_%s.log'%shot, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if not line.startswith('T '): continue
            p=line.rstrip('\n').split(' ',9); r=p[9].split(' ',1)
            bold=int(r[0]); t=r[1] if len(r)>1 else ''
            x,y=float(p[1]),float(p[2]); size,mono=int(p[7]),int(p[8])
            out.append((x,y,t,_f(size,mono,bold).getlength(t),size*1.25))
    return out
FAILS=[]
def all_shots():
    return sorted(set(f[5:-4] for f in os.listdir('/tmp') if f.startswith('shot_') and f.endswith('.log')))
def check(shot, must=(), mustnot=(), region=None):
    try: rs=runs(shot)
    except FileNotFoundError: FAILS.append("%s: shot missing"%shot); return
    if region:
        x0,y0,x1,y1=region
        rs=[r for r in rs if x0<=r[0]<=x1 and y0<=r[1]<=y1]
    s=[r[2] for r in rs]
    bad=[m for m in must if not any(m in v for v in s)]
    bad+=["unexpected %r"%m for m in mustnot if any(m in v for v in s)]
    if bad: FAILS.append("%s: %s"%(shot,'; '.join(str(b) for b in bad)))
    else: print("  ok   %-22s (%d runs)"%(shot,len(rs)))
def has_selection_highlight(shot):
    # The selection is drawn as a rect in the selection colour; assert it is
    # actually painted rather than trusting the status message alone.
    found = False
    with open('/tmp/shot_%s.log'%shot, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('R '):
                p = line.split()
                if (int(p[5]),int(p[6]),int(p[7]),int(p[8])) == (90,110,200,90) and float(p[3]) > 5:
                    found = True
    if not found: FAILS.append("%s: no selection highlight painted"%shot)
    else: print("  ok   %-22s selection highlight painted"%shot)

def background_is(shot, rgb):
    # The theme is asserted from the painted background, not from the status
    # message: a toggle that updates the label but not the palette would
    # otherwise pass.
    got = None
    with open('/tmp/shot_%s.log'%shot, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('R 0.0 0.0'):
                p = line.split()
                got = (int(p[5]), int(p[6]), int(p[7]))
                break
    if got != tuple(rgb): FAILS.append("%s: background %s, expected %s"%(shot, got, tuple(rgb)))
    else: print("  ok   %-22s background %s"%(shot, got))

def token_color_is(shot, word, rgb):
    # Syntax colours must follow the theme. Asserting the drawn colour of a
    # keyword catches a light theme that only repaints the chrome and leaves
    # code text in the dark palette, which is unreadable on white.
    got = None
    with open('/tmp/shot_%s.log'%shot, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('T '):
                p = line.rstrip('\n').split(' ', 9)
                r = p[9].split(' ', 1)
                if len(r) > 1 and r[1] == word:
                    got = (int(p[3]), int(p[4]), int(p[5]))
                    break
    if got != tuple(rgb): FAILS.append("%s: %r drawn %s, expected %s"%(shot, word, got, tuple(rgb)))
    else: print("  ok   %-22s %r drawn %s"%(shot, word, got))

def mono_font_size_is(shot, size):
    # Zoom must change the size text is drawn at, not just the status label.
    sizes = set()
    with open('/tmp/shot_%s.log'%shot, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('T '):
                p = line.rstrip('\n').split(' ', 9)
                if int(p[8]) == 1:
                    sizes.add(int(p[7]))
    if size not in sizes: FAILS.append("%s: mono sizes %s, expected %d"%(shot, sorted(sizes), size))
    else: print("  ok   %-22s mono font size %d"%(shot, size))

def tree_first_row_is(shot, text):
    # Scrolling is asserted from the first row actually drawn in the sidebar,
    # not from a status message, so a no-op scroll cannot pass.
    rows = [r for r in runs(shot) if 60 < r[0] < 300 and 100 < r[1] < 520]
    got = rows[0][2] if rows else None
    if got != text: FAILS.append("%s: first tree row %r, expected %r"%(shot, got, text))
    else: print("  ok   %-22s first tree row %r"%(shot, got))

def code_row_at(shot, y, text=None, first_x=None):
    # Reads one rendered code line: the joined token text and the x of its first
    # non-blank glyph. Leading whitespace is drawn as its own segment starting at
    # the left margin, so indentation can only be measured from the first glyph.
    segs = [(r[0], r[2]) for r in runs(shot) if r[0] > 370 and abs(r[1] - y) < 3]
    segs.sort()
    joined = ''.join(t for _, t in segs).strip()
    fx = next((x for x, t in segs if t.strip() != ''), None)
    ok = True
    if text is not None and joined != text: ok = False
    if first_x is not None and fx != first_x: ok = False
    if not ok: FAILS.append("%s: row y=%s is (%s, %r), expected (%s, %r)"%(shot, y, fx, joined, first_x, text))
    else: print("  ok   %-22s row y=%s x=%s %r"%(shot, y, fx, joined))

def no_overlapping_text(shot):
    rs=runs(shot)
    def ov(a,b): return not (a[0]+a[3]<=b[0]+.5 or b[0]+b[3]<=a[0]+.5 or a[1]+a[4]<=b[1]+.5 or b[1]+b[4]<=a[1]+.5)
    n=sum(1 for i,a in enumerate(rs) for b in rs[i+1:] if ov(a,b))
    if n: FAILS.append("%s: %d overlapping text pairs"%(shot,n))
def no_text_outside_window(shot, W=1600, H=960):
    rs=runs(shot)
    n=sum(1 for r in rs if r[0]<0 or r[1]<0)
    if n: FAILS.append("%s: %d text runs at negative coords"%(shot,n))
exec(open(sys.argv[1]).read())
print()
if FAILS:
    print("FAILURES (%d):"%len(FAILS))
    for f in FAILS: print("  -",f)
    sys.exit(1)
print("ALL IDE UI CHECKS PASSED")
