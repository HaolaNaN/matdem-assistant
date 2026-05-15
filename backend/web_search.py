import asyncio
from typing import List, Dict
from duckduckgo_search import DDGS

async def web_search(query, max_results=5):
    loop = asyncio.get_event_loop()
    def _search():
        results = []
        try:
            ddgs = DDGS()
            for i, r in enumerate(ddgs.text(f'MATLAB {query}')):
                if i >= max_results: break
                results.append({'title': r.get('title',''), 'url': r.get('href',''), 'snippet': r.get('body','')})
        except Exception as e:
            print(f'[WebSearch] {e}')
        return results
    try:
        return await asyncio.wait_for(loop.run_in_executor(None, _search), timeout=10.0)
    except asyncio.TimeoutError:
        return []

def format_search_results(results):
    if not results: return ''
    lines = ['[Web Search Results]']
    for i, r in enumerate(results, 1):
        lines.append(f'{i}. {r["title"]}'); lines.append(f'   URL: {r["url"]}'); lines.append(f'   {r["snippet"]}'); lines.append('')
    return chr(10).join(lines)