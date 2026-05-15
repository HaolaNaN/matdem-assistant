import re
from typing import Tuple, Optional

class SecurityFilter:
    INJECTION_PATTERNS = [
        r'ignore\s+(all\s+)?(previous|above|prior)\s+instructions?',
        r'forget\s+(all\s+)?(previous|above|prior)\s+instructions?',
        r'system\s*:\s*you\s+are\s+now',
        r'tell me your\s*(system\s*)?prompt',
        r'show\s+me\s+your\s+prompt',
        r'repeat\s+(the\s+)?(above|this)\s+text',
    ]
    BUILTIN_SOURCE_LEAK = [
        r'(show|reveal|display|give|output|dump)\s+(me\s+)?(the\s+)?(source\s+code|full\s+code|complete\s+code)',
        r'(all|every|全部|所有|完整).*(source|code|源码|源代码|代码)',
        r'list all (functions|methods) (with|and) (source|code|implementation)',
        r'what\s+is\s+the\s+(source\s+code|implementation)\s+of',
    ]

    def check_query(self, query):
        ql = query.lower()
        for pat in self.INJECTION_PATTERNS:
            if re.search(pat, ql, re.IGNORECASE): return False, 'Request blocked.'
        for pat in self.BUILTIN_SOURCE_LEAK:
            if re.search(pat, ql, re.IGNORECASE): return False, 'Cannot provide builtin source code. Please ask about function usage.'
        return True, None

    def sanitize_response(self, response):
        response = re.sub(r'sk-[a-zA-Z0-9]{20,}', '[API_KEY]', response)
        return response

security_filter = SecurityFilter()