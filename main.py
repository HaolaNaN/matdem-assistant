import os, sys, json, glob, traceback, hashlib
from datetime import datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fastapi import FastAPI, File, UploadFile, HTTPException, Query, Form, Request
from fastapi.responses import StreamingResponse, HTMLResponse, JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from backend.config import KNOWLEDGE_DIR, MAX_DOC_SIZE_MB, USER_DATA_DIR
from backend.knowledge import parse_document, SUPPORTED_EXTENSIONS
from backend.knowledge.kb_manager import get_knowledge_base
from backend.qa_engine import get_qa_engine
from backend.security import security_filter

app = FastAPI(title='MatDEM Assistant', version='3.0.0')
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['*'], allow_headers=['*'])
os.makedirs(KNOWLEDGE_DIR, exist_ok=True)
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', '0192023a7bbd73250516f069df18b500')

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(USER_DATA_DIR, 'query_logs')
STATIC_DIR = os.path.join(BASE_DIR, 'backend', 'static')

@app.on_event('startup')
async def startup():
    try:
        kb = get_knowledge_base()
        if kb.get_stats()['total_chunks'] == 0:
            import subprocess
            subprocess.run([sys.executable, os.path.join(BASE_DIR, 'init_kb.py')])
    except: pass

class ChatRequest(BaseModel):
    query: str
    history: Optional[List[dict]] = None
    stream: bool = True
    uid: str = 'default'

@app.get('/api/health')
async def health(): return {'status': 'ok'}

@app.post('/api/chat')
async def chat(req: ChatRequest):
    engine = get_qa_engine()
    history = req.history or None
    if req.stream:
        async def gen():
            async for c in engine.answer_stream(req.query, history, uid=req.uid): yield c
        return StreamingResponse(gen(), media_type='text/plain; charset=utf-8')
    else:
        answer = await engine.answer(req.query, history, uid=req.uid)
        return {'answer': answer}

@app.get('/api/kb/status')
async def kb_status(uid: str = 'default'):
    s = get_knowledge_base().get_stats()
    return {**s, 'supported_formats': list(SUPPORTED_EXTENSIONS.keys()), 'uid': uid}

@app.post('/api/kb/upload')
async def kb_upload(file: UploadFile = File(...), uid: str = Form('default')):
    try:
        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in SUPPORTED_EXTENSIONS: raise HTTPException(400, detail=f'Unsupported: {ext}')
        content = await file.read()
        if len(content) > MAX_DOC_SIZE_MB * 1024 * 1024: raise HTTPException(400, detail='File too large')
        user_dir = os.path.join(USER_DATA_DIR, 'uploads', uid)
        os.makedirs(user_dir, exist_ok=True)
        fp = os.path.join(user_dir, file.filename)
        with open(fp, 'wb') as f: f.write(content)
        text = parse_document(fp, full_code=True)
        if not text: raise HTTPException(400, detail='Cannot parse')
        n = get_knowledge_base().add_document(content=text, metadata={'source': file.filename, 'type': ext, 'is_builtin': False, 'uid': uid})
        return JSONResponse({'success': True, 'filename': file.filename, 'chunks_added': n, 'message': f'Added {n} chunks'})
    except HTTPException: raise
    except Exception as e: traceback.print_exc(); raise HTTPException(500, detail=str(e))

@app.post('/api/kb/rebuild')
async def kb_rebuild(uid: str = 'default'):
    kb = get_knowledge_base(); kb.delete_collection()
    import subprocess
    subprocess.run([sys.executable, os.path.join(BASE_DIR, 'init_kb.py'), '--force'])
    return {'success': True, 'message': f'Rebuilt: {kb.get_stats()["total_chunks"]} chunks'}

@app.post('/api/kb/clear')
async def kb_clear(uid: str = 'default'):
    get_knowledge_base().clear_user_documents(uid)
    return {'success': True, 'message': f'User {uid} cleared'}

@app.get('/api/kb/search')
async def kb_search(q: str = Query(...), top_k: int = Query(default=5, ge=1, le=20)):
    return {'query': q, 'results': get_knowledge_base().search(q, top_k=top_k)}

@app.get('/api/user/files')
async def user_files(uid: str = 'default'):
    user_dir = os.path.join(USER_DATA_DIR, 'uploads', uid)
    if not os.path.exists(user_dir): return {'uid': uid, 'files': []}
    files = []
    for f in os.listdir(user_dir):
        fp = os.path.join(user_dir, f)
        if os.path.isfile(fp): files.append({'name': f, 'size': os.path.getsize(fp), 'time': datetime.fromtimestamp(os.path.getmtime(fp)).strftime('%Y-%m-%d %H:%M')})
    files.sort(key=lambda x: x['time'], reverse=True)
    return {'uid': uid, 'files': files}

@app.post('/api/user/files/delete')
async def user_file_delete(filename: str = Form(...), uid: str = Form('default')):
    fp = os.path.join(USER_DATA_DIR, 'uploads', uid, filename)
    if not os.path.exists(fp): raise HTTPException(404, detail='File not found')
    os.remove(fp)
    get_knowledge_base().remove_document_by_source(filename, uid)
    return {'success': True, 'message': f'Deleted {filename}'}

@app.get('/api/logs/queries')
async def query_logs(date: str = None, uid: str = 'default', limit: int = 100):
    if not date: date = datetime.now().strftime('%Y%m%d')
    log_file = os.path.join(LOG_DIR, uid, f'queries_{date}.jsonl')
    if not os.path.exists(log_file): return {'date': date, 'uid': uid, 'total': 0, 'queries': []}
    queries = []
    with open(log_file, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip(): queries.append(json.loads(line.strip()))
    queries.reverse()
    return {'date': date, 'uid': uid, 'total': len(queries), 'queries': queries[:limit]}

@app.get('/api/logs/stats')
async def log_stats(uid: str = 'default'):
    user_log_dir = os.path.join(LOG_DIR, uid)
    os.makedirs(user_log_dir, exist_ok=True)
    fs = glob.glob(os.path.join(user_log_dir, 'queries_*.jsonl'))
    total, blocked = 0, 0
    for fp in fs:
        with open(fp, 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip():
                    e = json.loads(line.strip()); total += 1
                    if e.get('blocked'): blocked += 1
    return {'uid': uid, 'total_queries': total, 'blocked_queries': blocked}

def check_admin(request: Request):
    return request.cookies.get('matdem_admin_token', '') == ADMIN_PASSWORD

@app.post('/api/admin/login')
async def admin_login(password: str = Form(...)):
    if hashlib.md5(password.encode()).hexdigest() == ADMIN_PASSWORD:
        resp = JSONResponse({'success': True})
        resp.set_cookie('matdem_admin_token', ADMIN_PASSWORD, max_age=86400*30, httponly=True)
        return resp
    raise HTTPException(401, detail='Wrong password')

@app.post('/api/admin/logout')
async def admin_logout():
    resp = JSONResponse({'success': True}); resp.delete_cookie('matdem_admin_token'); return resp

@app.get('/api/admin/stats')
async def admin_stats(request: Request):
    if not check_admin(request): raise HTTPException(403, detail='Login required')
    uploads_dir = os.path.join(USER_DATA_DIR, 'uploads')
    user_count, total_files = 0, 0
    if os.path.exists(uploads_dir):
        for uid in os.listdir(uploads_dir):
            p = os.path.join(uploads_dir, uid)
            if os.path.isdir(p): user_count += 1; total_files += len([f for f in os.listdir(p) if os.path.isfile(os.path.join(p, f))])
    return {'total_users': user_count, 'total_uploads': total_files}

@app.get('/api/admin/users')
async def admin_users(request: Request):
    if not check_admin(request): raise HTTPException(403, detail='Login required')
    uploads_dir = os.path.join(USER_DATA_DIR, 'uploads')
    if not os.path.exists(uploads_dir): return {'users': []}
    users = []
    for uid in os.listdir(uploads_dir):
        up = os.path.join(uploads_dir, uid)
        if os.path.isdir(up):
            files = [{'name': f, 'size': os.path.getsize(os.path.join(up, f))} for f in os.listdir(up) if os.path.isfile(os.path.join(up, f))]
            users.append({'uid': uid, 'file_count': len(files), 'files': files})
    return {'users': users}

@app.get('/api/admin/logs/{uid}')
async def admin_user_logs(uid: str, request: Request, date: str = None, limit: int = 200):
    if not check_admin(request): raise HTTPException(403, detail='Login required')
    if not date: date = datetime.now().strftime('%Y%m%d')
    log_file = os.path.join(LOG_DIR, uid, f'queries_{date}.jsonl')
    if not os.path.exists(log_file): return {'uid': uid, 'date': date, 'total': 0, 'queries': []}
    queries = []
    with open(log_file, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip(): queries.append(json.loads(line.strip()))
    queries.reverse()
    return {'uid': uid, 'date': date, 'total': len(queries), 'queries': queries[:limit]}

@app.get('/api/admin/download/{uid}/{filename:path}')
async def admin_download(uid: str, filename: str, request: Request):
    if not check_admin(request): raise HTTPException(403, detail='Login required')
    fp = os.path.join(USER_DATA_DIR, 'uploads', uid, filename)
    if not os.path.exists(fp): raise HTTPException(404, detail='File not found')
    return FileResponse(fp, filename=filename)

@app.get('/', response_class=HTMLResponse)
async def index():
    fp = os.path.join(STATIC_DIR, 'index.html')
    if os.path.exists(fp):
        with open(fp, 'r', encoding='utf-8') as f: return f.read()
    return HTMLResponse('<h1>Not found</h1>')

@app.get('/admin', response_class=HTMLResponse)
async def admin_panel():
    fp = os.path.join(STATIC_DIR, 'admin.html')
    if os.path.exists(fp):
        with open(fp, 'r', encoding='utf-8') as f: return f.read()
    return HTMLResponse('<h1>Admin not found</h1>')

app.mount('/static', StaticFiles(directory=STATIC_DIR), name='static')

if __name__ == '__main__':
    import uvicorn
    uvicorn.run('main:app', host='0.0.0.0', port=int(os.getenv('PORT', 8000)), reload=False)