import json, asyncio, os
from datetime import datetime
from typing import AsyncGenerator, List, Dict
from openai import AsyncOpenAI
from backend.config import OPENAI_API_KEY, OPENAI_BASE_URL, OPENAI_MODEL, SYSTEM_PROMPT, SYSTEM_SECURITY_PROMPT, USER_DATA_DIR
from backend.knowledge.kb_manager import get_knowledge_base
from backend.web_search import web_search, format_search_results
from backend.security import security_filter

class QARagEngine:
    def __init__(self):
        self.kb = get_knowledge_base()
        self.client = AsyncOpenAI(api_key=OPENAI_API_KEY, base_url=OPENAI_BASE_URL, timeout=120.0)
        self.base_log_dir = os.path.join(USER_DATA_DIR, 'query_logs')

    def _log_query(self, query, answer, blocked=False, reason='', uid='default'):
        try:
            log_dir = os.path.join(self.base_log_dir, uid)
            os.makedirs(log_dir, exist_ok=True)
            log_file = os.path.join(log_dir, f'queries_{datetime.now().strftime("%Y%m%d")}.jsonl')
            entry = {'time': datetime.now().isoformat(), 'query': query, 'answer_preview': answer[:200] if answer else '', 'answer_length': len(answer) if answer else 0, 'blocked': blocked, 'reason': reason, 'uid': uid}
            with open(log_file, 'a', encoding='utf-8') as f: f.write(json.dumps(entry, ensure_ascii=False) + chr(10))
        except: pass

    def _build_context(self, query):
        results = self.kb.search(query, top_k=10)
        if not results: return ''
        builtin = [r for r in results if r.get('is_builtin') and r['score'] >= 0.3]
        user = [r for r in results if not r.get('is_builtin') and r['score'] >= 0.15]
        lines = []
        if builtin:
            lines.append('[Builtin KB - function signatures only, no source code]')
            for i, r in enumerate(builtin[:3], 1):
                c = r['content']; lines.append(f'[{i}] source:{r["source"]} (relevance:{r["score"]:.2f})'); lines.append(c[:600] + '...' if len(c)>600 else c); lines.append('')
        if user:
            lines.append('[User-uploaded KB - can analyze freely]')
            for i, r in enumerate(user[:5], 1):
                c = r['content']; lines.append(f'[{i}] source:{r["source"]} (relevance:{r["score"]:.2f})'); lines.append(c[:800] + '...' if len(c)>800 else c); lines.append('')
        return chr(10).join(lines) if lines else ''

    async def answer_stream(self, query, history=None, uid='default'):
        is_safe, warning = security_filter.check_query(query)
        if not is_safe:
            self._log_query(query, '', blocked=True, reason=warning or 'Blocked', uid=uid)
            yield warning or 'Request blocked.'
            return
        web_text = ''
        try:
            sr = await web_search(query, max_results=3)
            web_text = format_search_results(sr)
        except: pass
        kb_ctx = self._build_context(query)
        ctx_parts = []
        if kb_ctx: ctx_parts.append(kb_ctx)
        if web_text: ctx_parts.append(web_text)
        ctx = chr(10).join(ctx_parts) if ctx_parts else '(no context)'
        builtin_warning = chr(10) + '[IMPORTANT] User-uploaded code can be analyzed freely. Builtin KB: only describe function purpose, NEVER output source code.' + chr(10)
        sp = SYSTEM_PROMPT.format(security_rules=SYSTEM_SECURITY_PROMPT + builtin_warning, knowledge_context=ctx)
        msgs = [{'role': 'system', 'content': sp}]
        if history: msgs.extend(history[-20:])
        msgs.append({'role': 'user', 'content': query})
        try:
            resp = await self.client.chat.completions.create(model=OPENAI_MODEL, messages=msgs, temperature=0.7, max_tokens=4096)
            content = resp.choices[0].message.content or ''
            self._log_query(query, content, uid=uid)
            for i in range(0, len(content), 30): yield content[i:i+30]; await asyncio.sleep(0.005)
        except Exception as e:
            self._log_query(query, '', blocked=True, reason=str(e), uid=uid)
            yield f'[Error] {str(e)}'

    async def answer(self, query, history=None, uid='default'):
        parts = []
        async for p in self.answer_stream(query, history, uid=uid): parts.append(p)
        return ''.join(parts)

_engine_instance = None
def get_qa_engine():
    global _engine_instance
    if _engine_instance is None: _engine_instance = QARagEngine()
    return _engine_instance