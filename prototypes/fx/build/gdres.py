"""Godot text resource (.tres/.tscn) parser -> python values."""
import re
import os
ROOT=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../speed'))
class Ref:
    def __init__(s,kind,id): s.kind=kind; s.id=id
    def __repr__(s): return f'{s.kind}({s.id!r})'
class Tok:
    def __init__(s,t): s.t=t; s.i=0
    def ws(s):
        while s.i<len(s.t) and s.t[s.i] in ' \t\r\n': s.i+=1
    def peek(s): s.ws(); return s.t[s.i] if s.i<len(s.t) else ''
def parse_value(tk):
    c=tk.peek(); t=tk.t
    if c=='{':
        tk.i+=1; d={}
        while True:
            if tk.peek()=='}': tk.i+=1; return d
            k=parse_value(tk); tk.ws(); assert t[tk.i]==':',t[tk.i-20:tk.i+20]; tk.i+=1
            v=parse_value(tk); d[str(k)]=v
            if tk.peek()==',': tk.i+=1
    if c=='[':
        tk.i+=1; a=[]
        while True:
            if tk.peek()==']': tk.i+=1; return a
            a.append(parse_value(tk))
            if tk.peek()==',': tk.i+=1
    if c=='"' or (c=='&' and t[tk.i+1]=='"') or (c=='^' and t[tk.i+1]=='"'):
        if c!='"': tk.i+=1
        tk.i+=1; out=[]
        while t[tk.i]!='"':
            if t[tk.i]=='\\': out.append({'n':'\n','t':'\t','"':'"','\\':'\\'}.get(t[tk.i+1],t[tk.i+1])); tk.i+=2
            else: out.append(t[tk.i]); tk.i+=1
        tk.i+=1; return ''.join(out)
    m=re.compile(r'-?(?:\d+\.?\d*(?:e[-+]?\d+)?|inf|nan)',re.I).match(t,tk.i)
    if m and m.group(0) and (c.isdigit() or c=='-'):
        tk.i=m.end(); s=m.group(0)
        return float(s) if any(x in s.lower() for x in '.ein') else int(s)
    m=re.compile(r'[A-Za-z_][A-Za-z0-9_]*').match(t,tk.i)
    if m:
        name=m.group(0); tk.i=m.end()
        if name=='true': return True
        if name=='false': return False
        if name=='null': return None
        if name in('inf','INF'): return float('inf')
        if tk.peek()=='(':
            tk.i+=1; args=[]
            while True:
                if tk.peek()==')': tk.i+=1; break
                args.append(parse_value(tk))
                if tk.peek()==',': tk.i+=1
            if name in('ExtResource','SubResource'): return Ref(name,args[0])
            if name in('Vector2','Vector2i'): return {'x':args[0],'y':args[1]}
            if name=='Color': return {'r':args[0],'g':args[1],'b':args[2],'a':args[3] if len(args)>3 else 1}
            if name in('Rect2','Rect2i'): return {'x':args[0],'y':args[1],'w':args[2],'h':args[3]}
            if name=='PackedVector2Array': return [{'x':args[k],'y':args[k+1]} for k in range(0,len(args),2)]
            if name=='PackedColorArray': return [{'r':args[k],'g':args[k+1],'b':args[k+2],'a':args[k+3]} for k in range(0,len(args),4)]
            if name.startswith('Packed') or name=='Array': return args[0] if (name=='Array' and len(args)==1) else args
            return {'__type':name,'args':args}
        if tk.peek()=='[':  # typed Array[...](...)
            depth=0
            while True:
                ch=t[tk.i]; tk.i+=1
                if ch=='[': depth+=1
                elif ch==']':
                    depth-=1
                    if depth==0: break
            return parse_value(tk)
        return name
    raise ValueError('bad token at %d: %r'%(tk.i,t[tk.i:tk.i+40]))
def parse(path):
    if not path.startswith('/'): path=ROOT+'/'+path.replace('res://','')
    txt=open(path,encoding='utf-8').read()
    sections=[]; tk=Tok(txt)
    hdr=re.compile(r'^\[(\w+)([^\]\n]*)\]\s*$',re.M)
    heads=list(hdr.finditer(txt))
    for n,h in enumerate(heads):
        attrs={}
        for m in re.finditer(r'(\w+)=("(?:[^"\\]|\\.)*"|[^\s\]]+)',h.group(2)):
            v=m.group(2); attrs[m.group(1)]=v[1:-1] if v.startswith('"') else v
        end=heads[n+1].start() if n+1<len(heads) else len(txt)
        body=txt[h.end():end]; props={}
        tk=Tok(body)
        while True:
            tk.ws()
            if tk.i>=len(body): break
            m=re.compile(r'([\w/:\.]+)\s*=').match(body,tk.i)
            if not m: break
            tk.i=m.end(); props[m.group(1)]=parse_value(tk)
        sections.append({'tag':h.group(1),'attrs':attrs,'props':props})
    return sections
def resource(path):
    secs=parse(path)
    ext={s['attrs']['id']:s['attrs'].get('path') for s in secs if s['tag']=='ext_resource'}
    sub={s['attrs']['id']:s for s in secs if s['tag']=='sub_resource'}
    main=[s for s in secs if s['tag']=='resource']
    return {'ext':ext,'sub':sub,'res':main[0]['props'] if main else None,'sections':secs}
