import os
from typing import Optional
from pypdf import PdfReader

def parse_pdf(fp):
    reader = PdfReader(fp)
    return chr(10).join([p.extract_text() or '' for p in reader.pages])

def parse_txt(fp):
    for enc in ['utf-8','gbk']:
        try:
            with open(fp,'r',encoding=enc) as f: return f.read()
        except: pass
    return ''

def parse_m_file(fp):
    with open(fp,'r',encoding='utf-8',errors='ignore') as f: content = f.read()
    lines = content.split(chr(10))
    comments = [l.strip()[1:].strip() for l in lines if l.strip().startswith('%')]
    sigs = [l.strip() for l in lines if l.strip().startswith('function')]
    result = 'MATLAB file: ' + os.path.basename(fp) + chr(10)
    if sigs: result += 'Functions:' + chr(10) + chr(10).join(sigs) + chr(10)*2
    if comments: result += 'Comments:' + chr(10) + chr(10).join(comments[:50])
    return result

SUPPORTED_EXTENSIONS = {'.pdf':parse_pdf,'.txt':parse_txt,'.md':parse_txt,'.m':parse_m_file,'.py':parse_txt}

def parse_document(fp, full_code=False):
    ext = os.path.splitext(fp)[1].lower()
    if full_code and ext == '.m': return parse_txt(fp)
    parser = SUPPORTED_EXTENSIONS.get(ext)
    if parser is None: return None
    return parser(fp)