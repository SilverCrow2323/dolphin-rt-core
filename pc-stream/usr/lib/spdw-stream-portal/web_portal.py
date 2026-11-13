#!/usr/bin/env python3
"""Local-first Dolphin Rt:Stream web companion. Binds to loopback only."""
import argparse,json,re,secrets,shutil,subprocess,sys,threading
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse
HERE=Path(__file__).resolve().parent; WEB=HERE/"web"; sys.path.insert(0,str(HERE))
import spdw_stream_core as core
TOKEN=secrets.token_urlsafe(32); LOCK=threading.RLock(); EXTS={".iso",".gcm",".rvz",".wbfs",".ciso",".gcz",".wia"}
def remote_path(v):
 v=str(v or "").strip()
 if not v.startswith("/") or any(x==".." for x in v.split("/")) or any(c in v for c in "\r\n\x00"): raise ValueError("Remote path must be an absolute safe path.")
 return v
def device(c):
 d=c.get("device") or {}; return {"host":str(d.get("host","")),"port":int(d.get("port",22)),"user":str(d.get("user","")),"rom_path":str(d.get("rom_path",""))}
def sftp(c,commands,timeout=30):
 d=device(c)
 if not re.fullmatch(r"[A-Za-z0-9_.:-]{1,253}",d["host"]): raise ValueError("Configure a valid device host or IP.")
 if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}",d["user"]): raise ValueError("Configure a valid SSH username.")
 if not 1<=d["port"]<=65535: raise ValueError("Invalid SFTP port.")
 if not shutil.which("sftp"): raise RuntimeError("OpenSSH sftp client is not installed.")
 p=subprocess.run(["sftp","-q","-P",str(d["port"]),"-oBatchMode=yes","-oConnectTimeout=8","-oStrictHostKeyChecking=yes","-b","-",d["user"]+"@"+d["host"]],input="\n".join(commands)+"\n",text=True,capture_output=True,timeout=timeout)
 if p.returncode: raise RuntimeError((p.stderr or p.stdout or "SFTP failed").strip()[-1000:])
 return p.stdout.strip()
def quote_path(s):
 s=str(s)
 if any(c in s for c in "\r\n\x00"): raise ValueError("Invalid path.")
 return '"'+s.replace("\\","\\\\").replace('"','\\"')+'"'
def snapshot():
 c=core.load_config(); g=core.load_library(c); d=device(c); lib=core.lib_dir(c); lan=core.lan_ip(); ts=core.tailscale_ip()
 try: u=shutil.disk_usage(lib if lib.exists() else lib.parent); disk={"free":u.free,"total":u.total}
 except OSError: disk={"free":0,"total":0}
 return {"version":"5.0.0","sunshine":{"installed":core.sunshine_installed(),"running":core.sunshine_running()},"network":{"lan":lan,"tailscale":ts,"sync_port":int(c.get("port",8765))},"library":{"count":len(g),"gc":sum(x.get("kind")=="gc" for x in g),"wii":sum(x.get("kind")=="wii" for x in g),"path":str(lib),"disk":disk},"device":{**d,"configured":bool(d["host"] and d["user"] and d["rom_path"])},"checks":[{"label":a,"state":b,"detail":c} for a,b,c in core.system_checks(c)]}
def action(b):
 c=core.load_config(); op=b.get("action")
 if op=="save-device":
  d={"host":str(b.get("host","")).strip(),"user":str(b.get("user","")).strip(),"port":int(b.get("port",22)),"rom_path":str(b.get("rom_path","")).strip()}
  if d["host"] and not re.fullmatch(r"[A-Za-z0-9_.:-]{1,253}",d["host"]): raise ValueError("Invalid host.")
  if d["user"] and not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}",d["user"]): raise ValueError("Invalid username.")
  if not 1<=d["port"]<=65535: raise ValueError("Invalid port.")
  if d["rom_path"]: remote_path(d["rom_path"])
  c["device"]=d; core.save_config(c); return {"saved":True}
 if op=="sftp-test": return {"message":sftp(c,["pwd"])}
 if op=="sftp-list":
  p=remote_path(b.get("path") or device(c)["rom_path"]); return {"path":p,"listing":sftp(c,["ls -la "+quote_path(p)])}
 if op=="sftp-upload":
  src=Path(str(b.get("local",""))).expanduser().resolve(strict=True)
  if not src.is_file() or src.suffix.lower() not in EXTS: raise ValueError("Choose a valid GameCube/Wii ROM.")
  roots=[Path(x).expanduser().resolve() for x in c.get("gc",[])+c.get("wii",[])]
  if not any(src==r or r in src.parents for r in roots): raise ValueError("ROM must be inside a configured library folder.")
  dst=remote_path(b.get("remote") or device(c)["rom_path"]); cmd="put "+quote_path(str(src))+" "+quote_path(dst.rstrip("/")+"/"+src.name)
  return {"message":sftp(c,[cmd],3600)}
 if op=="scan":
  with LOCK: g=core.build(c,refresh_covers=bool(b.get("refresh")))
  return {"count":len(g)}
 if op=="sunshine-start": core.sunshine_start(); return {"running":core.sunshine_running()}
 if op=="sunshine-stop": core.sunshine_stop(); return {"running":core.sunshine_running()}
 if op=="sunshine-restart": core.sunshine_stop(); core.sunshine_start(); return {"running":core.sunshine_running()}
 if op=="checks": return {"checks":[{"label":a,"state":b,"detail":c} for a,b,c in core.system_checks(c)]}
 if op=="open-sunshine": subprocess.Popen(["xdg-open","https://localhost:47990"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); return {"opened":True}
 raise ValueError("Unknown action.")
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*a): pass
 def reply(self,code,obj):
  d=json.dumps(obj,ensure_ascii=False).encode(); self.send_response(code); self.send_header("Content-Type","application/json; charset=utf-8"); self.send_header("Cache-Control","no-store"); self.send_header("Content-Length",str(len(d))); self.end_headers(); self.wfile.write(d)
 def do_GET(self):
  p=urlparse(self.path).path
  if p=="/api/state": return self.reply(200,snapshot())
  if p=="/api/library": return self.reply(200,{"games":core.load_library(core.load_config())})
  f=WEB/("index.html" if p=="/" else p.lstrip("/"))
  if p not in ("/","/app.css","/app.js") or not f.is_file(): return self.send_error(404)
  d=f.read_text(encoding="utf-8").replace("__TOKEN__",TOKEN).encode() if p=="/" else f.read_bytes()
  self.send_response(200); self.send_header("Content-Type","text/html; charset=utf-8" if p=="/" else ("text/css; charset=utf-8" if p.endswith(".css") else "text/javascript; charset=utf-8")); self.send_header("Cache-Control","no-store"); self.send_header("Content-Length",str(len(d))); self.end_headers(); self.wfile.write(d)
 def do_POST(self):
  if self.headers.get("X-RtStream-Token","")!=TOKEN: return self.reply(403,{"error":"Invalid local session."})
  origin=self.headers.get("Origin","")
  if origin and not origin.startswith(("http://127.0.0.1:","http://localhost:")): return self.reply(403,{"error":"Cross-origin request blocked."})
  try:
   n=int(self.headers.get("Content-Length","0"))
   if n<0 or n>1048576: raise ValueError("Invalid request size.")
   b=json.loads(self.rfile.read(n) or b"{}")
   if not isinstance(b,dict): raise ValueError("Invalid request.")
   return self.reply(200,{"ok":True,"result":action(b)})
  except (ValueError,RuntimeError,OSError,subprocess.TimeoutExpired) as e: return self.reply(400,{"ok":False,"error":str(e)})
def main():
 p=argparse.ArgumentParser(); p.add_argument("--port",type=int,default=8766); p.add_argument("--no-browser",action="store_true"); a=p.parse_args()
 if not 1<=a.port<=65535: p.error("invalid port")
 srv=ThreadingHTTPServer(("127.0.0.1",a.port),Handler); srv.daemon_threads=True; url="http://127.0.0.1:%d/"%a.port
 print("Dolphin Rt:Stream Portal: "+url,flush=True)
 if not a.no_browser:
  import webbrowser; webbrowser.open(url)
 try: srv.serve_forever(poll_interval=.5)
 except KeyboardInterrupt: pass
 finally: srv.server_close()
if __name__=="__main__": main()
