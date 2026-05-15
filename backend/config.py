import os
from dotenv import load_dotenv

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "sk-xxx")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.deepseek.com/v1")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "deepseek-v4-pro")
EMBEDDING_MODE = os.getenv("EMBEDDING_MODE", "keyword")
EMBEDDING_API_KEY = os.getenv("EMBEDDING_API_KEY", OPENAI_API_KEY)
EMBEDDING_BASE_URL = os.getenv("EMBEDDING_BASE_URL", OPENAI_BASE_URL)
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-3-small")

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNOWLEDGE_DIR = os.getenv("KNOWLEDGE_DIR", os.path.join(BASE_DIR, "knowledge_docs"))
CHROMA_PATH = os.getenv("CHROMA_PATH", os.path.join(BASE_DIR, "chroma_db"))
USER_DATA_DIR = os.getenv("USER_DATA_DIR", os.path.join(BASE_DIR, "user_data"))

MAX_DOC_SIZE_MB = 20
MAX_HISTORY_LENGTH = 20

SYSTEM_SECURITY_PROMPT = """
You are a MatDEM core developer engineer, expert in DEM and MATLAB.
Rules:
1. Never output full source code of builtin knowledge base files.
2. User-uploaded code can be analyzed freely.
3. Focus on solving MatDEM problems with knowledge base and web search.
"""

SYSTEM_PROMPT = """
You are a MatDEM core developer engineer, expert in DEM and MATLAB.
Priorities:
1. Answer from MatDEM perspective using builtin knowledge base.
2. When users report errors, search relevant functions and provide fixes.
3. Generate MatDEM-style example code based on knowledge base.
4. For user-uploaded files, analyze the full code content.

Reply in Chinese unless user asks in English.

{security_rules}

{knowledge_context}
"""