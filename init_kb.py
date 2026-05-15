import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from backend.config import KNOWLEDGE_DIR, USER_DATA_DIR
from backend.knowledge import parse_document, SUPPORTED_EXTENSIONS
from backend.knowledge.kb_manager import get_knowledge_base

def init_builtin_knowledge(force=False):
    kb = get_knowledge_base()
    if kb.get_stats()['total_chunks'] > 0 and not force:
        print(f'KB has {kb.get_stats()["total_chunks"]} chunks, skip')
        return
    if force: kb.delete_collection(); kb = get_knowledge_base()
    os.makedirs(USER_DATA_DIR, exist_ok=True)
    os.makedirs(os.path.join(USER_DATA_DIR, 'uploads'), exist_ok=True)
    os.makedirs(os.path.join(USER_DATA_DIR, 'query_logs'), exist_ok=True)
    if not os.path.exists(KNOWLEDGE_DIR):
        os.makedirs(KNOWLEDGE_DIR)
        print(f'Created: {KNOWLEDGE_DIR}')
    files = []
    for root, dirs, fnames in os.walk(KNOWLEDGE_DIR):
        for f in fnames:
            files.append(os.path.join(root, f))
    if not files: print('No files in knowledge_docs'); return
    total, skipped, failed = 0, 0, 0
    for fp in sorted(files):
        rel = os.path.relpath(fp, KNOWLEDGE_DIR)
        ext = os.path.splitext(fp)[1].lower()
        if ext not in SUPPORTED_EXTENSIONS: skipped += 1; continue
        try:
            text = parse_document(fp)
            if not text: print(f'  [FAIL] {rel}: cannot parse'); failed += 1; continue
            n = kb.add_document(content=text, metadata={'source': rel, 'type': ext, 'is_builtin': True})
            print(f'  [OK] {rel}: +{n} chunks')
            total += n
        except Exception as e: print(f'  [FAIL] {rel}: {e}'); failed += 1
    print(f'Done: {total} chunks, {skipped} skipped, {failed} failed')
    print(f'KB total: {kb.get_stats()["total_chunks"]} chunks')

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()
    init_builtin_knowledge(force=args.force)