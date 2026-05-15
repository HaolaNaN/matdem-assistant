import os, json, hashlib, math, re
from typing import List, Optional, Dict

STORAGE_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'chroma_db', 'kb_storage.json')

class SimpleTextSplitter:
    def __init__(self, chunk_size=500): self.chunk_size = chunk_size
    def split_text(self, text):
        if len(text) <= self.chunk_size: return [text] if text.strip() else []
        paragraphs = text.split(chr(10)+chr(10))
        chunks, current = [], ''
        for para in paragraphs:
            if len(current + para) <= self.chunk_size: current = current + chr(10)+chr(10) + para if current else para
            else:
                if current: chunks.append(current)
                if len(para) > self.chunk_size:
                    for i in range(0, len(para), self.chunk_size): chunks.append(para[i:i+self.chunk_size])
                else: current = para
        if current: chunks.append(current)
        return [c.strip() for c in chunks if c.strip()]

class KnowledgeBase:
    def __init__(self):
        os.makedirs(os.path.dirname(STORAGE_FILE), exist_ok=True)
        self.text_splitter = SimpleTextSplitter()
        self.collection_name = 'matdem_knowledge'
        self._load_storage()

    def _load_storage(self):
        if os.path.exists(STORAGE_FILE):
            with open(STORAGE_FILE, 'r', encoding='utf-8') as f: self.documents = json.load(f).get('documents', [])
        else: self.documents = []

    def _save_storage(self):
        os.makedirs(os.path.dirname(STORAGE_FILE), exist_ok=True)
        with open(STORAGE_FILE, 'w', encoding='utf-8') as f: json.dump({'documents': self.documents}, f, ensure_ascii=False)

    def _keyword_score(self, query, text):
        ql, tl = query.lower(), text.lower()
        if ql in tl: return 0.95
        q_tokens = set(re.findall(r'[\u4e00-\u9fff]+|[a-zA-Z_][a-zA-Z0-9_]*|[0-9]+', ql))
        if not q_tokens: return 0.0
        t_tokens = set(re.findall(r'[\u4e00-\u9fff]+|[a-zA-Z_][a-zA-Z0-9_]*|[0-9]+', tl))
        hits = sum(1 for t in q_tokens if t in t_tokens)
        base = hits / len(q_tokens)
        for token in q_tokens:
            if len(token) >= 3 and token not in t_tokens and token in tl: base += 0.1 / len(q_tokens)
        return min(base, 1.0)

    def _hash_text(self, text): return hashlib.md5(text.encode('utf-8')).hexdigest()

    def _is_builtin(self, source):
        return not source.startswith('user_') and '/user_' not in source

    def add_document(self, content, metadata=None):
        chunks = self.text_splitter.split_text(content)
        if not chunks: return 0
        source = (metadata or {}).get('source', 'unknown')
        is_builtin = self._is_builtin(source)
        for i, chunk in enumerate(chunks):
            doc_entry = {'id': self._hash_text(chunk), 'content': chunk, 'metadata': {**(metadata or {}), 'chunk_index': i, 'is_builtin': is_builtin, 'source': source}}
            existing = next((idx for idx, d in enumerate(self.documents) if d['id'] == doc_entry['id']), None)
            if existing is not None: self.documents[existing] = doc_entry
            else: self.documents.append(doc_entry)
        self._save_storage()
        return len(chunks)

    def search(self, query, top_k=5):
        if not self.documents: return []
        scored = []
        for doc in self.documents:
            s = self._keyword_score(query, doc['content'])
            if s > 0: scored.append((s, doc))
        scored.sort(key=lambda x: x[0], reverse=True)
        return [{'content': doc['content'], 'score': round(score, 4), 'source': doc['metadata'].get('source', 'KB'), 'is_builtin': doc['metadata'].get('is_builtin', False)} for score, doc in scored[:top_k]]

    def search_user_uploaded(self, query, top_k=5):
        return self.search(query, top_k=top_k)

    def get_builtin_files(self):
        return sorted(list(set(d['metadata'].get('source','') for d in self.documents if d['metadata'].get('is_builtin'))))

    def clear_user_documents(self, uid):
        self.documents = [d for d in self.documents if d['metadata'].get('uid') != uid]
        self._save_storage()

    def remove_document_by_source(self, source, uid='default'):
        self.documents = [d for d in self.documents if not (d['metadata'].get('source') == source and d['metadata'].get('uid') == uid)]
        self._save_storage()

    def delete_collection(self):
        self.documents = []
        self._save_storage()

    def get_stats(self):
        builtin = sum(1 for d in self.documents if d['metadata'].get('is_builtin'))
        return {'total_chunks': len(self.documents), 'builtin_chunks': builtin, 'user_chunks': len(self.documents) - builtin, 'collection': self.collection_name, 'mode': 'keyword'}

_kb_instance = None
def get_knowledge_base():
    global _kb_instance
    if _kb_instance is None: _kb_instance = KnowledgeBase()
    return _kb_instance