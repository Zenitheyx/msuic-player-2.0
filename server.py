#!/usr/bin/env python3
"""NEXUS web backend. Standard library only.
Fetches public HTTP(S) pages and converts HTML to readable text + links.
This is intentionally a simple proxy/reader, not a JS execution engine.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, quote
from urllib.request import Request, urlopen
from html.parser import HTMLParser
import html, json, re, argparse

class Parser(HTMLParser):
    def __init__(self, base):
        super().__init__(); self.base=base; self.parts=[]; self.links=[]; self.href=None; self.link_text=[]; self.skip=0
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if tag in ('script','style','noscript','svg'): self.skip+=1
        if tag=='a' and 'href' in a: self.href=a['href']; self.link_text=[]
    def handle_endtag(self, tag):
        if tag in ('script','style','noscript','svg') and self.skip: self.skip-=1
        if tag=='a' and self.href is not None:
            text=' '.join(''.join(self.link_text).split())
            u=self.resolve(self.href)
            if u and text: self.links.append({'title':text[:120], 'url':u})
            self.href=None; self.link_text=[]
    def handle_data(self, data):
        if self.skip: return
        s=' '.join(data.split())
        if not s: return
        self.parts.append(s)
        if self.href is not None: self.link_text.append(s)
    def resolve(self, href):
        from urllib.parse import urljoin
        if href.startswith(('#','javascript:','mailto:','tel:')): return None
        return urljoin(self.base, href)


def fetch(url):
    p=urlparse(url)
    if p.scheme not in ('http','https') or not p.netloc: raise ValueError('Only public HTTP/HTTPS URLs are supported')
    req=Request(url,headers={'User-Agent':'NEXUS-OS/0.1 (+CC:Tweaked browser backend)'})
    with urlopen(req,timeout=15) as r:
        raw=r.read(2_000_000)
        final=r.geturl(); ctype=r.headers.get_content_type()
    if ctype in ('text/plain','application/json'):
        text=raw.decode('utf-8','replace')
        return {'type':'page','title':final,'text':text[:12000],'links':[],'url':final}
    if 'html' not in ctype: raise ValueError('Backend received non-HTML content: '+ctype)
    p=Parser(final); p.feed(raw.decode('utf-8','replace'))
    text='\n'.join(p.parts)
    text=re.sub(r'\n{3,}','\n\n',text)
    return {'type':'page','title':final,'text':text[:12000],'links':p.links[:60],'url':final}


def search(q):
    # Search through DuckDuckGo's lightweight HTML endpoint. If a deployment
    # blocks it, the browser still supports direct URL navigation.
    u='https://html.duckduckgo.com/html/?q='+quote(q)
    req=Request(u,headers={'User-Agent':'NEXUS-OS/0.1'})
    with urlopen(req,timeout=15) as r: raw=r.read(1_500_000).decode('utf-8','replace')
    p=Parser(u); p.feed(raw)
    results=[]
    for l in p.links:
        if l['url'].startswith('http') and l['url'] not in [x['url'] for x in results]: results.append(l)
        if len(results)>=10: break
    return {'type':'search','query':q,'results':results}

class Handler(BaseHTTPRequestHandler):
    def send_json(self, obj, code=200):
        b=json.dumps(obj,ensure_ascii=False).encode('utf-8'); self.send_response(code); self.send_header('Content-Type','application/json; charset=utf-8'); self.send_header('Access-Control-Allow-Origin','*'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        try:
            p=urlparse(self.path); q=parse_qs(p.query)
            if p.path=='/health': return self.send_json({'ok':True,'service':'nexus-web-backend','version':'0.1'})
            if p.path=='/fetch': return self.send_json(fetch(q.get('url',[''])[0]))
            if p.path=='/search': return self.send_json(search(q.get('q',[''])[0]))
            self.send_json({'error':'not found'},404)
        except Exception as e: self.send_json({'error':str(e)},400)
    def log_message(self, fmt,*args): print(fmt%args)

if __name__=='__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--host',default='127.0.0.1'); ap.add_argument('--port',type=int,default=8080); a=ap.parse_args()
    print(f'NEXUS backend listening on {a.host}:{a.port}')
    ThreadingHTTPServer((a.host,a.port),Handler).serve_forever()
